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

      if (config.enableLogs) {
        print('WebSocket Event: $eventType, Data: $eventData');
      }

      switch (eventType) {
        case 'user.joined':
          try {
            final participant = Participant.fromJson(eventData);
            _eventController.add(WebRTCClientEvent.userJoined(participant));
          } catch (e) {
            print('Error parsing user.joined event: $e');
          }
          break;
        case 'user.left':
          try {
            final participant = Participant.fromJson(eventData);
            _eventController.add(WebRTCClientEvent.userLeft(participant));
          } catch (e) {
            print('Error parsing user.left event: $e');
          }
          break;
        case 'chat.message':
          try {
            final message = ChatMessage.fromJson(eventData);
            _eventController.add(WebRTCClientEvent.messageReceived(message));
          } catch (e) {
            print('Error parsing chat.message event: $e');
          }
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
        case 'call.started':
          try {
            final roomId = eventData['room_id'] as String?;
            final participants =
                eventData['participants'] as List<dynamic>? ?? [];
            if (roomId != null) {
              _eventController.add(WebRTCClientEvent.callStarted(
                  roomId, participants.map((p) => p as int).toList()));
            }
          } catch (e) {
            print('Error parsing call.started event: $e');
          }
          break;
        case 'call.ended':
          try {
            final roomId = eventData['room_id'] as String?;
            if (roomId != null) {
              _eventController.add(WebRTCClientEvent.callEnded(roomId));
            }
          } catch (e) {
            print('Error parsing call.ended event: $e');
          }
          break;
        case 'connection:connected':
        case 'connection:established':
          _isConnected = true;
          _eventController.add(WebRTCClientEvent.connected());
          break;
        case 'connection:disconnected':
          _isConnected = false;
          _eventController.add(WebRTCClientEvent.disconnected());
          break;
        case 'connection:error':
          _eventController.add(WebRTCClientEvent.connectionError(
              eventData['error']?.toString() ?? 'Unknown error'));
          break;
        case 'room:subscription_succeeded':
          if (config.enableLogs) {
            print('Successfully subscribed to room: ${eventData['room_id']}');
          }
          break;
        case 'subscription:error':
          print('Subscription error: ${eventData['error']}');
          break;
        default:
          if (config.enableLogs) {
            print('Unhandled WebSocket event: $eventType');
          }
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
          // Get the current room to send the ICE candidate
          final currentRoomId =
              _joinedRooms.isNotEmpty ? _joinedRooms.first : null;
          if (currentRoomId != null) {
            _sendIceCandidate(e.userId, e.candidate, currentRoomId);
          }
          break;
        case AnswerCreated:
          final e = event as AnswerCreated;
          // Get the current room to send the answer
          final currentRoomId =
              _joinedRooms.isNotEmpty ? _joinedRooms.first : null;
          if (currentRoomId != null) {
            _sendAnswer(e.userId, e.answer, currentRoomId);
          }
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

  Future<User> createUser({
    required String name,
    String? email,
    String? externalId,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userData = {
        'name': name,
        if (email != null) 'email': email,
        if (externalId != null) 'external_id': externalId,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (metadata != null) 'metadata': metadata,
      };

      final response = await _httpClient.post('/users', userData);
      final userJson = response['data'] ?? response;

      final user = User.fromJson(userJson);
      _currentUser = user; // Set as current user

      return user;
    } catch (e) {
      throw WebRTCException('Failed to create user: $e');
    }
  }

  Future<User?> getUser(String identifier) async {
    try {
      final response = await _httpClient.get('/users/$identifier');
      final userJson = response['data'] ?? response;
      return User.fromJson(userJson);
    } catch (e) {
      if (config.enableLogs) {
        print('Failed to get user: $e');
      }
      return null;
    }
  }

  Future<List<User>> getUsers({int page = 1, int perPage = 20}) async {
    try {
      final response =
          await _httpClient.get('/users?page=$page&per_page=$perPage');
      final usersData = response['data'] as List? ?? response as List;
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw WebRTCException('Failed to get users: $e');
    }
  }

  // Updated Room Management with better user handling
  Future<JoinRoomResult> joinRoom(
    String roomId, {
    String? userId,
    String? username,
    String? userEmail,
    String? userName,
  }) async {
    try {
      // Prepare join options
      final joinData = <String, dynamic>{};

      if (userId != null) {
        joinData['user_id'] = userId;
      } else if (username != null) {
        joinData['username'] = username;
      } else if (_currentUser?.id != null) {
        joinData['user_id'] = _currentUser!.id.toString();
      } else {
        throw WebRTCException(
            'Must provide userId, username, or set current user');
      }

      // Add optional user data for auto-creation
      if (userName != null) joinData['username'] = userName;
      if (userEmail != null) joinData['email'] = userEmail;

      final response = await _httpClient.post('/rooms/$roomId/join', joinData);

      // Handle the response
      final roomData = response['room'] ?? response;
      final participantData = response['participant'];
      final userData = response['user'];

      final room = Room.fromJson(roomData);
      final participant = Participant.fromJson(participantData);

      // Update current user if returned
      if (userData != null) {
        _currentUser = User.fromJson(userData);
      }

      // Get all participants
      final participants = await getParticipants(roomId);

      _wsService.subscribeToRoom(roomId);
      _joinedRooms.add(roomId);

      final result = JoinRoomResult(room: room, participants: participants);
      _eventController.add(WebRTCClientEvent.roomJoined(result));

      return result;
    } catch (e) {
      if (config.enableLogs) {
        print('Failed to join room: $e');
      }
      throw WebRTCException('Failed to join room: $e');
    }
  }

  Future<void> leaveRoom(
    String roomId, {
    String? userId,
    String? username,
  }) async {
    try {
      final leaveData = <String, dynamic>{};

      if (userId != null) {
        leaveData['user_id'] = userId;
      } else if (username != null) {
        leaveData['username'] = username;
      } else if (_currentUser?.id != null) {
        leaveData['user_id'] = _currentUser!.id.toString();
      } else {
        throw WebRTCException(
            'Must provide userId, username, or set current user');
      }

      await _httpClient.post('/rooms/$roomId/leave', leaveData);

      _wsService.unsubscribeFromRoom(roomId);
      _joinedRooms.remove(roomId);

      _eventController.add(WebRTCClientEvent.roomLeft(roomId));
    } catch (e) {
      throw WebRTCException('Failed to leave room: $e');
    }
  }

  // Quick join methods for convenience
  Future<JoinRoomResult> joinRoomWithUsername(
    String roomId,
    String username, {
    String? email,
  }) async {
    return joinRoom(
      roomId,
      username: username,
      userEmail: email,
      userName: username,
    );
  }

  Future<JoinRoomResult> joinRoomWithUserId(
    String roomId,
    String userId, {
    String? name,
    String? email,
  }) async {
    return joinRoom(
      roomId,
      userId: userId,
      userName: name,
      userEmail: email,
    );
  }

  // User Management
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  // Room Management
  Future<Room> createRoom(CreateRoomOptions options) async {
    try {
      final response = await _httpClient.post('/rooms', options.toJson());

      // Handle both wrapped and direct responses
      Map<String, dynamic> roomData;
      if (response.containsKey('data')) {
        roomData = response['data'] as Map<String, dynamic>;
      } else {
        // Direct response from Laravel
        roomData = response;
      }

      if (config.enableLogs) {
        print('Creating room from data: $roomData');
      }

      return Room.fromJson(roomData);
    } catch (e) {
      if (config.enableLogs) {
        print('Failed to create room: $e');
      }
      throw WebRTCException('Failed to create room: $e');
    }
  }

  Future<List<Room>> getRooms() async {
    try {
      final response = await _httpClient.get('/rooms');
      final roomsData = response['data'] as List? ?? response as List;
      return roomsData
          .map((json) => Room.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw WebRTCException('Failed to get rooms: $e');
    }
  }

  Future<Room> getRoom(String roomId) async {
    try {
      final response = await _httpClient.get('/rooms/$roomId');
      final roomData = response['data'] ?? response;
      return Room.fromJson(roomData);
    } catch (e) {
      throw WebRTCException('Failed to get room: $e');
    }
  }

  Future<List<Participant>> getParticipants(String roomId) async {
    try {
      final response = await _httpClient.get('/rooms/$roomId/participants');
      final participantsData = response['data'] as List? ?? response as List;
      return participantsData
          .map((json) => Participant.fromJson(json as Map<String, dynamic>))
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

      // Send start call request to server
      final response =
          await _httpClient.post('/rooms/$roomId/webrtc/call/start', {
        'user_id': _currentUser?.id,
        'participants': participantIds,
      });

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

  Future<void> endCall(String roomId) async {
    try {
      // Send end call request to server
      await _httpClient.post('/rooms/$roomId/webrtc/call/end', {
        'user_id': _currentUser?.id,
        'reason': 'manual',
      });

      _webrtcService.cleanup();
      _eventController.add(WebRTCClientEvent.callEnded(roomId));
    } catch (e) {
      // Still cleanup locally even if server request fails
      _webrtcService.cleanup();
      _eventController.add(WebRTCClientEvent.callEnded(roomId));
      if (config.enableLogs) {
        print('Failed to send end call to server: $e');
      }
    }
  }

  // Future<JoinRoomResult> joinRoom(String roomId, {int? userId}) async {
  //   try {
  //     if (userId == null && _currentUser?.id == null) {
  //       throw WebRTCException(
  //           'User ID must be provided or current user must be set');
  //     }

  //     final joinOptions = JoinRoomOptions(
  //       userId: userId ?? _currentUser!.id,
  //     );

  //     final response =
  //         await _httpClient.post('/rooms/$roomId/join', joinOptions.toJson());

  //     // Handle the response format from Laravel
  //     Map<String, dynamic> roomData;
  //     List<dynamic> participantsData = [];

  //     if (response.containsKey('data')) {
  //       final data = response['data'] as Map<String, dynamic>;
  //       roomData = data['room'] ?? data;
  //       participantsData = data['participants'] ?? [];
  //     } else {
  //       // Handle direct response
  //       roomData = response['room'] ?? response;
  //       participantsData = response['participants'] ?? [];
  //     }

  //     final room = Room.fromJson(roomData);
  //     final participants = (participantsData as List)
  //         .map((json) => Participant.fromJson(json as Map<String, dynamic>))
  //         .toList();

  //     _wsService.subscribeToRoom(roomId);
  //     _joinedRooms.add(roomId);

  //     final result = JoinRoomResult(room: room, participants: participants);
  //     _eventController.add(WebRTCClientEvent.roomJoined(result));

  //     return result;
  //   } catch (e) {
  //     if (config.enableLogs) {
  //       print('Failed to join room: $e');
  //     }
  //     throw WebRTCException('Failed to join room: $e');
  //   }
  // }

  // Future<void> leaveRoom(String roomId, {int? userId}) async {
  //   try {
  //     if (userId == null && _currentUser?.id == null) {
  //       throw WebRTCException(
  //           'User ID must be provided or current user must be set');
  //     }

  //     final leaveData = {
  //       'user_id': userId ?? _currentUser!.id,
  //     };

  //     await _httpClient.post('/rooms/$roomId/leave', leaveData);

  //     _wsService.unsubscribeFromRoom(roomId);
  //     _joinedRooms.remove(roomId);

  //     _eventController.add(WebRTCClientEvent.roomLeft(roomId));
  //   } catch (e) {
  //     throw WebRTCException('Failed to leave room: $e');
  //   }
  // }

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

  Future<List<ChatMessage>> getMessages(String roomId,
      {int page = 1, int perPage = 50}) async {
    try {
      final response = await _httpClient
          .get('/rooms/$roomId/messages?page=$page&per_page=$perPage');
      final messagesData = response['data'] as List? ?? response as List;
      return messagesData
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw WebRTCException('Failed to get messages: $e');
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
      if (config.enableLogs) {
        print('Failed to send typing indicator: $e');
      }
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
      if (config.enableLogs) {
        print('Failed to send offer: $e');
      }
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
      if (config.enableLogs) {
        print('Failed to send answer: $e');
      }
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
      if (config.enableLogs) {
        print('Failed to send ICE candidate: $e');
      }
    }
  }

  void _handleWebRTCOffer(Map<String, dynamic> data) async {
    try {
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
    } catch (e) {
      if (config.enableLogs) {
        print('Error handling WebRTC offer: $e');
      }
    }
  }

  void _handleWebRTCAnswer(Map<String, dynamic> data) async {
    try {
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
    } catch (e) {
      if (config.enableLogs) {
        print('Error handling WebRTC answer: $e');
      }
    }
  }

  void _handleWebRTCIceCandidate(Map<String, dynamic> data) async {
    try {
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
    } catch (e) {
      if (config.enableLogs) {
        print('Error handling WebRTC ICE candidate: $e');
      }
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
