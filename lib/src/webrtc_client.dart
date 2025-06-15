import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

class WebRTCClient {
  final TalklynkSdkConfig config;
  late final HttpClient _httpClient;
  late final WebSocketService _wsService;
  late final WebRTCService _webrtcService;

  final StreamController<WebRTCClientEvent> _eventController =
      StreamController.broadcast();
  late final StreamSubscription _wsSubscription;
  late final StreamSubscription _webrtcSubscription;

  User? _currentUser;
  final Set<String> _joinedRooms = {};
  bool _isConnected = false;

  WebRTCClient(this.config) {
    _httpClient = HttpClient(
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
      enableLogs: config.enableLogs,
    );

    _wsService = WebSocketService(
        wsUrl: config.wsUrl,
        apiKey: config.apiKey,
        enableLogs: config.enableLogs,
        pusherAppKey: config.pusherAppKey);

    _webrtcService = WebRTCService(enableLogs: config.enableLogs);

    _setupEventListeners();
  }

  Stream<WebRTCClientEvent> get events => _eventController.stream;
  bool get isConnected => _isConnected;
  User? get currentUser => _currentUser;
  Set<String> get joinedRooms => Set.unmodifiable(_joinedRooms);
  MediaStream? get localStream => _webrtcService.localStream;
  Map<int, MediaStream> get remoteStreams => _webrtcService.remoteStreams;

  void _setupEventListeners() {
    // WebSocket events
    _wsSubscription = _wsService.on<Map<String, dynamic>>('').listen((data) {
      final eventType = data['event'] as String?;
      final eventData = data['data'] as Map<String, dynamic>? ?? data;

      switch (eventType) {
        case 'user.joined':
          final participant = Participant.fromJson(eventData);
          _eventController.add(WebRTCClientEvent.userJoined(participant));
          break;
        case 'user.left':
          final participant = Participant.fromJson(eventData);
          _eventController.add(WebRTCClientEvent.userLeft(participant));
          break;
        case 'chat.message':
          final message = ChatMessage.fromJson(eventData);
          _eventController.add(WebRTCClientEvent.messageReceived(message));
          break;
        case 'webrtc.offer':
          _handleWebRTCOffer(eventData);
          break;
        case 'webrtc.answer':
          _handleWebRTCAnswer(eventData);
          break;
        case 'webrtc.ice-candidate':
          _handleWebRTCIceCandidate(eventData);
          break;
        case 'connection:connected':
          _isConnected = true;
          _eventController.add(WebRTCClientEvent.connected());
          break;
        case 'connection:disconnected':
          _isConnected = false;
          _eventController.add(WebRTCClientEvent.disconnected());
          break;
        case 'connection:error':
          _eventController.add(WebRTCClientEvent.connectionError(
              eventData['error'] ?? 'Unknown error'));
          break;
      }
    });

    // WebRTC events
    _webrtcSubscription = _webrtcService.events.listen((event) {
      switch (event.runtimeType) {
        case LocalStreamAdded:
          final e = event as LocalStreamAdded;
          _eventController.add(WebRTCClientEvent.localStreamAdded(e.stream));
          break;
        case RemoteStreamAdded:
          final e = event as RemoteStreamAdded;
          _eventController
              .add(WebRTCClientEvent.remoteStreamAdded(e.userId, e.stream));
          break;
        case RemoteStreamRemoved:
          final e = event as RemoteStreamRemoved;
          _eventController.add(WebRTCClientEvent.remoteStreamRemoved(e.userId));
          break;
        case IceCandidateGenerated:
          final e = event as IceCandidateGenerated;
          //  _sendIceCandidate(e.userId, e.candidate);
          break;
        case AnswerCreated:
          final e = event as AnswerCreated;
          //_sendAnswer(e.userId, e.answer);
          break;
      }
    });
  }

  // Connection Management
  Future<void> connect() async {
    try {
      await _wsService.connect();
    } catch (e) {
      throw WebRTCException('Failed to connect: $e');
    }
  }

  void disconnect() {
    _wsService.disconnect();
    _webrtcService.cleanup();
    _joinedRooms.clear();
    _isConnected = false;
  }

  // Permission Management
  Future<bool> requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();

    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  Future<bool> checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  // User Management
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  // Room Management
  Future<Room> createRoom(CreateRoomOptions options) async {
    try {
      final response = await _httpClient.post('/rooms', options.toJson());
      return Room.fromJson(response);
    } catch (e) {
      throw WebRTCException('Failed to create room: $e');
    }
  }

  Future<List<Room>> getRooms() async {
    try {
      final response = await _httpClient.get('/rooms');
      final roomsData = response['data'] as List? ?? response as List;
      return roomsData.map((json) => Room.fromJson(json)).toList();
    } catch (e) {
      throw WebRTCException('Failed to get rooms: $e');
    }
  }

  Future<Room> getRoom(String roomId) async {
    try {
      final response = await _httpClient.get('/rooms/$roomId');
      return Room.fromJson(response);
    } catch (e) {
      throw WebRTCException('Failed to get room: $e');
    }
  }

  Future<List<Participant>> getParticipants(String roomId) async {
    try {
      final response = await _httpClient.get('/rooms/$roomId/participants');
      final participantsData = response['data'] as List? ?? response as List;
      return participantsData
          .map((json) => Participant.fromJson(json))
          .toList();
    } catch (e) {
      throw WebRTCException('Failed to get participants: $e');
    }
  }

  // Media Management
  Future<MediaStream> getUserMedia([MediaConstraints? constraints]) async {
    constraints ??= const MediaConstraints();

    final hasPermissions = await checkPermissions();
    if (!hasPermissions) {
      final granted = await requestPermissions();
      if (!granted) {
        throw WebRTCException('Camera and microphone permissions are required');
      }
    }

    return await _webrtcService.getUserMedia(constraints);
  }

  Future<MediaStream> getDisplayMedia() async {
    return await _webrtcService.getDisplayMedia();
  }

  Future<void> switchCamera() async {
    await _webrtcService.switchCamera();
  }

  Future<void> toggleAudio(bool enabled) async {
    await _webrtcService.toggleAudio(enabled);
  }

  Future<void> toggleVideo(bool enabled) async {
    await _webrtcService.toggleVideo(enabled);
  }

  // Call Management
  Future<void> startCall(String roomId, List<int> participantIds) async {
    try {
      // Ensure we have local media
      if (_webrtcService.localStream == null) {
        await getUserMedia();
      }

      // Create offers for each participant
      for (final participantId in participantIds) {
        if (participantId != _currentUser?.id) {
          final offer = await _webrtcService.createOffer(participantId);
          await _sendOffer(participantId, offer, roomId);
        }
      }

      _eventController
          .add(WebRTCClientEvent.callStarted(roomId, participantIds));
    } catch (e) {
      throw WebRTCException('Failed to start call: $e');
    }
  }

  void endCall(String roomId) {
    _webrtcService.cleanup();
    _eventController.add(WebRTCClientEvent.callEnded(roomId));
  }

  Future<JoinRoomResult> joinRoom(String roomId, {int? userId}) async {
    try {
      if (userId == null && _currentUser?.id == null) {
        throw WebRTCException(
            'User ID must be provided or current user must be set');
      }

      final joinOptions = JoinRoomOptions(
        userId: userId ?? _currentUser!.id,
      );

      final response =
          await _httpClient.post('/rooms/$roomId/join', joinOptions.toJson());

      // Handle both response formats
      final roomData = response['room'] ?? response['data']['room'] ?? response;
      final participantsData =
          response['participants'] ?? response['data']['participants'] ?? [];

      final room = Room.fromJson(roomData);
      final participants = (participantsData as List)
          .map((json) => Participant.fromJson(json))
          .toList();

      _wsService.subscribeToRoom(roomId);
      _joinedRooms.add(roomId);

      final result = JoinRoomResult(room: room, participants: participants);
      _eventController.add(WebRTCClientEvent.roomJoined(result));

      return result;
    } catch (e) {
      throw WebRTCException('Failed to join room: $e');
    }
  }

  Future<void> leaveRoom(String roomId, {int? userId}) async {
    try {
      if (userId == null && _currentUser?.id == null) {
        throw WebRTCException(
            'User ID must be provided or current user must be set');
      }

      final leaveData = {
        'user_id': userId ?? _currentUser!.id,
      };

      await _httpClient.post('/rooms/$roomId/leave', leaveData);

      _wsService.unsubscribeFromRoom(roomId);
      _joinedRooms.remove(roomId);

      _eventController.add(WebRTCClientEvent.roomLeft(roomId));
    } catch (e) {
      throw WebRTCException('Failed to leave room: $e');
    }
  }

  Future<ChatMessage> sendMessage(
      String roomId, SendMessageOptions options) async {
    try {
      Map<String, dynamic> response;

      if (options.filePath != null) {
        // Upload file with additional fields
        final file = File(options.filePath!);
        final additionalFields = <String, String>{
          'user_id': options.userId.toString(),
          'type': options.type.name,
        };

        if (options.message != null) {
          additionalFields['message'] = options.message!;
        }

        if (options.metadata != null) {
          additionalFields['metadata'] = jsonEncode(options.metadata);
        }

        response = await _httpClient.uploadFile(
          '/rooms/$roomId/messages',
          file,
          additionalFields: additionalFields,
        );
      } else {
        // Send text message
        response =
            await _httpClient.post('/rooms/$roomId/messages', options.toJson());
      }

      // Handle wrapped response
      final messageData = response['data'] ?? response;
      return ChatMessage.fromJson(messageData);
    } catch (e) {
      throw WebRTCException('Failed to send message: $e');
    }
  }

  Future<void> sendTypingIndicator(String roomId, bool typing,
      {int? userId}) async {
    try {
      if (userId == null && _currentUser?.id == null) {
        throw WebRTCException(
            'User ID must be provided or current user must be set');
      }

      await _httpClient.post('/rooms/$roomId/typing', {
        'user_id': userId ?? _currentUser!.id,
        'is_typing': typing,
      });
    } catch (e) {
      // Don't throw for typing indicators, just log
      print('Failed to send typing indicator: $e');
    }
  }

// WebRTC Signaling
  Future<void> _sendOffer(
      int toUserId, RTCSessionDescription offer, String roomId) async {
    final data = {
      'from_user_id': _currentUser?.id,
      'to_user_id': toUserId,
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
    };

    try {
      await _httpClient.post('/rooms/$roomId/webrtc/offer', data);
    } catch (e) {
      print('Failed to send offer: $e');
    }
  }

  Future<void> _sendAnswer(
      int toUserId, RTCSessionDescription answer, String roomId) async {
    final data = {
      'from_user_id': _currentUser?.id,
      'to_user_id': toUserId,
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      },
    };

    try {
      await _httpClient.post('/rooms/$roomId/webrtc/answer', data);
    } catch (e) {
      print('Failed to send answer: $e');
    }
  }

  Future<void> _sendIceCandidate(
      int toUserId, RTCIceCandidate candidate, String roomId) async {
    final data = {
      'from_user_id': _currentUser?.id,
      'to_user_id': toUserId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'sdpMid': candidate.sdpMid,
      },
    };

    try {
      await _httpClient.post('/rooms/$roomId/webrtc/ice-candidate', data);
    } catch (e) {
      print('Failed to send ICE candidate: $e');
    }
  }

  Future<List<ChatMessage>> getMessages(String roomId,
      {int page = 1, int perPage = 50}) async {
    try {
      final response = await _httpClient
          .get('/rooms/$roomId/messages?page=$page&per_page=$perPage');
      final messagesData = response['data'] as List? ?? response as List;
      return messagesData.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      throw WebRTCException('Failed to get messages: $e');
    }
  }

  void _handleWebRTCOffer(Map<String, dynamic> data) async {
    final fromUserId = data['from_user_id'] as int;
    final toUserId = data['to_user_id'] as int;
    final offerData = data['offer'] as Map<String, dynamic>;

    if (toUserId == _currentUser?.id) {
      final offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );

      await _webrtcService.handleOffer(fromUserId, offer);
    }
  }

  void _handleWebRTCAnswer(Map<String, dynamic> data) async {
    final fromUserId = data['from_user_id'] as int;
    final toUserId = data['to_user_id'] as int;
    final answerData = data['answer'] as Map<String, dynamic>;

    if (toUserId == _currentUser?.id) {
      final answer = RTCSessionDescription(
        answerData['sdp'],
        answerData['type'],
      );

      await _webrtcService.handleAnswer(fromUserId, answer);
    }
  }

  void _handleWebRTCIceCandidate(Map<String, dynamic> data) async {
    final fromUserId = data['from_user_id'] as int;
    final toUserId = data['to_user_id'] as int;
    final candidateData = data['candidate'] as Map<String, dynamic>;

    if (toUserId == _currentUser?.id) {
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      await _webrtcService.handleIceCandidate(fromUserId, candidate);
    }
  }

  void dispose() {
    _wsSubscription.cancel();
    _webrtcSubscription.cancel();
    _eventController.close();
    _httpClient.dispose();
    _wsService.dispose();
    _webrtcService.dispose();
  }
}

// Helper Classes
class JoinRoomResult {
  final Room room;
  final List<Participant> participants;

  const JoinRoomResult({
    required this.room,
    required this.participants,
  });
}

// Client Events
abstract class WebRTCClientEvent {
  const WebRTCClientEvent();

  factory WebRTCClientEvent.connected() = ConnectedEvent;
  factory WebRTCClientEvent.disconnected() = DisconnectedEvent;
  factory WebRTCClientEvent.connectionError(String error) =
      ConnectionErrorEvent;
  factory WebRTCClientEvent.roomJoined(JoinRoomResult result) = RoomJoinedEvent;
  factory WebRTCClientEvent.roomLeft(String roomId) = RoomLeftEvent;
  factory WebRTCClientEvent.userJoined(Participant participant) =
      UserJoinedEvent;
  factory WebRTCClientEvent.userLeft(Participant participant) = UserLeftEvent;
  factory WebRTCClientEvent.messageReceived(ChatMessage message) =
      MessageReceivedEvent;
  factory WebRTCClientEvent.localStreamAdded(MediaStream stream) =
      LocalStreamAddedEvent;
  factory WebRTCClientEvent.remoteStreamAdded(int userId, MediaStream stream) =
      RemoteStreamAddedEvent;
  factory WebRTCClientEvent.remoteStreamRemoved(int userId) =
      RemoteStreamRemovedEvent;
  factory WebRTCClientEvent.callStarted(String roomId, List<int> participants) =
      CallStartedEvent;
  factory WebRTCClientEvent.callEnded(String roomId) = CallEndedEvent;
}

class ConnectedEvent extends WebRTCClientEvent {
  const ConnectedEvent();
}

class DisconnectedEvent extends WebRTCClientEvent {
  const DisconnectedEvent();
}

class ConnectionErrorEvent extends WebRTCClientEvent {
  final String error;
  const ConnectionErrorEvent(this.error);
}

class RoomJoinedEvent extends WebRTCClientEvent {
  final JoinRoomResult result;
  const RoomJoinedEvent(this.result);
}

class RoomLeftEvent extends WebRTCClientEvent {
  final String roomId;
  const RoomLeftEvent(this.roomId);
}

class UserJoinedEvent extends WebRTCClientEvent {
  final Participant participant;
  const UserJoinedEvent(this.participant);
}

class UserLeftEvent extends WebRTCClientEvent {
  final Participant participant;
  const UserLeftEvent(this.participant);
}

class MessageReceivedEvent extends WebRTCClientEvent {
  final ChatMessage message;
  const MessageReceivedEvent(this.message);
}

class LocalStreamAddedEvent extends WebRTCClientEvent {
  final MediaStream stream;
  const LocalStreamAddedEvent(this.stream);
}

class RemoteStreamAddedEvent extends WebRTCClientEvent {
  final int userId;
  final MediaStream stream;
  const RemoteStreamAddedEvent(this.userId, this.stream);
}

class RemoteStreamRemovedEvent extends WebRTCClientEvent {
  final int userId;
  const RemoteStreamRemovedEvent(this.userId);
}

class CallStartedEvent extends WebRTCClientEvent {
  final String roomId;
  final List<int> participants;
  const CallStartedEvent(this.roomId, this.participants);
}

class CallEndedEvent extends WebRTCClientEvent {
  final String roomId;
  const CallEndedEvent(this.roomId);
}
