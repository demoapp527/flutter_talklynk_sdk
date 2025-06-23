import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

class TalkLynkRoom {
  final int id;
  final String roomId;
  final String name;
  final RoomType type;
  final int maxParticipants;
  final TalkLynkUser currentUser;
  final ApiService apiService;
  final WebSocketService webSocketService;
  final Logger logger;

  final Map<String, TalkLynkUser> _participants = {};
  final List<ChatMessage> _messages = [];
  final Map<String, RTCPeerConnection> _peerConnections = {};

  final StreamController<RoomEvent> _eventController =
      StreamController.broadcast();
  final StreamController<ChatMessage> _messageController =
      StreamController.broadcast();
  final StreamController<List<TalkLynkUser>> _participantsController =
      StreamController.broadcast();

  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  MediaStream? _localStream;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;

  TalkLynkRoom({
    required this.id,
    required this.roomId,
    required this.name,
    required this.type,
    required this.maxParticipants,
    required this.currentUser,
    required this.apiService,
    required this.webSocketService,
    required this.logger,
  }) {
    _initializeRoom();
  }

  /// Stream of room events
  Stream<RoomEvent> get events => _eventController.stream;

  /// Stream of chat messages
  Stream<ChatMessage> get messages => _messageController.stream;

  /// Stream of participants updates
  Stream<List<TalkLynkUser>> get participants => _participantsController.stream;

  /// Get current participants list
  List<TalkLynkUser> get currentParticipants => _participants.values.toList();

  /// Check if current user is admin (first participant)
  bool get isAdmin => currentUser.role == UserRole.admin;

  /// Check if audio is muted
  bool get isAudioMuted => _isAudioMuted;

  /// Check if video is muted
  bool get isVideoMuted => _isVideoMuted;

  /// Get local video renderer
  RTCVideoRenderer? get localRenderer => _localRenderer;

  /// Get remote video renderer
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;

  /// Get chat message history
  List<ChatMessage> get messageHistory => List.unmodifiable(_messages);

  Future<void> _initializeRoom() async {
    try {
      // Initialize WebRTC if video/audio room
      if (type == RoomType.video || type == RoomType.audio) {
        await _initializeWebRTC();
      }

      // Load existing participants and messages
      await _loadRoomData();

      logger.d('Room $roomId initialized successfully');
    } catch (e) {
      logger.e('Failed to initialize room $roomId: $e');
    }
  }

  Future<void> _initializeWebRTC() async {
    try {
      // Initialize renderers
      _localRenderer = RTCVideoRenderer();
      _remoteRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      await _remoteRenderer!.initialize();

      // Get user media
      await _getUserMedia();

      logger.d('WebRTC initialized for room $roomId');
    } catch (e) {
      logger.e('Failed to initialize WebRTC: $e');
      throw TalkLynkException('WebRTC initialization failed: $e');
    }
  }

  Future<void> _getUserMedia() async {
    try {
      final constraints = {
        'audio': type == RoomType.video || type == RoomType.audio,
        'video': type == RoomType.video
            ? {
                'width': 640,
                'height': 480,
                'frameRate': 30,
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localRenderer?.srcObject = _localStream;

      logger.d('Got user media for room $roomId');
    } catch (e) {
      logger.e('Failed to get user media: $e');
      throw TalkLynkException('Failed to access camera/microphone: $e');
    }
  }

  Future<void> _loadRoomData() async {
    try {
      // Load participants
      final participantsResponse = await apiService.getRoomParticipants(roomId);

      // Handle participants data
      List<dynamic> participantsList;
      if (participantsResponse.containsKey('data')) {
        participantsList = participantsResponse['data'] as List;
      } else {
        // Fallback for old format
        participantsList = participantsResponse['participants'] as List? ?? [];
      }

      _participants.clear(); // Clear existing participants
      for (final participantData in participantsList) {
        try {
          final user =
              TalkLynkUser.fromJson(participantData['user'] ?? participantData);
          _participants[user.id] = user;
        } catch (e) {
          logger.w('Failed to parse participant: $participantData, error: $e');
        }
      }

      // Load recent messages
      final messagesResponse = await apiService.getRoomMessages(roomId);

      // Handle messages data
      List<dynamic> messagesList;
      if (messagesResponse.containsKey('data')) {
        messagesList = messagesResponse['data'] as List;
      } else {
        // Fallback for old format
        messagesList = messagesResponse as List? ?? [];
      }

      _messages.clear(); // Clear existing messages
      for (final messageData in messagesList) {
        try {
          final message = ChatMessage.fromJson(messageData);
          _messages.add(message);
        } catch (e) {
          logger.w('Failed to parse message: $messageData, error: $e');
        }
      }

      _notifyParticipantsUpdate();

      // Notify about loaded messages
      for (final message in _messages) {
        _messageController.add(message);
      }

      logger.d(
          'Loaded room data for $roomId: ${_participants.length} participants, ${_messages.length} messages');
    } catch (e) {
      logger.e('Failed to load room data: $e');
      // Don't throw here, just log the error so room can still function
    }
  }

  Future<void> sendMessage(String text,
      {ChatMessageType type = ChatMessageType.text}) async {
    try {
      logger.d('Sending message in room $roomId: $text');

      final response = await apiService.sendMessage(
        roomId: roomId,
        username: currentUser.username,
        message: text,
        type: type,
      );

      // Extract message data from response
      Map<String, dynamic> messageData;
      if (response.containsKey('data')) {
        messageData = response['data'] as Map<String, dynamic>;
      } else {
        // Fallback to response itself
        messageData = response;
      }

      try {
        final message = ChatMessage.fromJson(messageData);
        _messages.add(message);
        _messageController.add(message);

        logger.d('Message sent successfully in room $roomId');
      } catch (parseError) {
        logger.w('Failed to parse sent message response: $parseError');
        logger.w('Message data: $messageData');

        // Create a basic message object even if parsing fails
        final basicMessage = ChatMessage(
          id: messageData['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          roomId: roomId,
          senderId: currentUser.id,
          senderName: currentUser.displayName,
          message: text,
          type: type,
          timestamp: DateTime.now(),
          metadata: {},
        );

        _messages.add(basicMessage);
        _messageController.add(basicMessage);
      }
    } catch (e) {
      logger.e('Failed to send message: $e');
      throw TalkLynkException('Failed to send message: $e');
    }
  }

  /// Send typing indicator - FIXED VERSION
  Future<void> sendTypingIndicator(bool isTyping) async {
    try {
      await apiService.sendTypingIndicator(
          roomId: roomId,
          username: currentUser.username, // Pass current user's username
          isTyping: isTyping);
    } catch (e) {
      logger.w('Failed to send typing indicator: $e');
    }
  }

  /// Toggle audio mute
  Future<void> toggleAudio() async {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = _isAudioMuted;
      }
      _isAudioMuted = !_isAudioMuted;

      _emitEvent(RoomEvent.audioToggled({
        'muted': _isAudioMuted,
        'user_id': currentUser.id,
      }));

      logger.d('Audio ${_isAudioMuted ? 'muted' : 'unmuted'} in room $roomId');
    }
  }

  /// Toggle video mute
  Future<void> toggleVideo() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        track.enabled = _isVideoMuted;
      }
      _isVideoMuted = !_isVideoMuted;

      _emitEvent(RoomEvent.videoToggled({
        'muted': _isVideoMuted,
        'user_id': currentUser.id,
      }));

      logger.d('Video ${_isVideoMuted ? 'muted' : 'unmuted'} in room $roomId');
    }
  }

  /// Admin: Kick a participant
  Future<void> kickParticipant(String participantId) async {
    if (!isAdmin) {
      throw TalkLynkException('Only admins can kick participants');
    }

    try {
      await apiService.kickParticipant(
          roomId: roomId, participantId: participantId);
      logger.d('Kicked participant $participantId from room $roomId');
    } catch (e) {
      logger.e('Failed to kick participant: $e');
      throw TalkLynkException('Failed to kick participant: $e');
    }
  }

  /// Admin: Mute all participants
  Future<void> muteAllParticipants() async {
    if (!isAdmin) {
      throw TalkLynkException('Only admins can mute all participants');
    }

    try {
      await apiService.muteAllParticipants(roomId);
      logger.d('Muted all participants in room $roomId');
    } catch (e) {
      logger.e('Failed to mute all participants: $e');
      throw TalkLynkException('Failed to mute all participants: $e');
    }
  }

  /// Admin: Transfer admin role
  Future<void> transferAdmin(String newAdminId) async {
    if (!isAdmin) {
      throw TalkLynkException('Only admins can transfer admin role');
    }

    try {
      await apiService.transferAdmin(roomId: roomId, newAdminId: newAdminId);
      logger.d('Transferred admin role to $newAdminId in room $roomId');
    } catch (e) {
      logger.e('Failed to transfer admin role: $e');
      throw TalkLynkException('Failed to transfer admin role: $e');
    }
  }

  // WebSocket event handlers
  void handleUserJoined(Map<String, dynamic> data) {
    try {
      final user = TalkLynkUser.fromJson(data['user']);
      _participants[user.id] = user;
      _notifyParticipantsUpdate();

      _emitEvent(RoomEvent.userJoined({
        'user': user.toJson(),
        'room_id': roomId,
      }));

      logger.d('User ${user.username} joined room $roomId');
    } catch (e) {
      logger.e('Failed to handle user joined: $e');
    }
  }

  void handleUserLeft(Map<String, dynamic> data) {
    try {
      final userId = data['user_id'] as String;
      final user = _participants.remove(userId);
      _notifyParticipantsUpdate();

      if (user != null) {
        _emitEvent(RoomEvent.userLeft({
          'user': user.toJson(),
          'room_id': roomId,
        }));

        logger.d('User ${user.username} left room $roomId');
      }
    } catch (e) {
      logger.e('Failed to handle user left: $e');
    }
  }

  void handleChatMessage(Map<String, dynamic> data) {
    try {
      final message = ChatMessage.fromJson(data);
      _messages.add(message);
      _messageController.add(message);

      logger.d('Received message in room $roomId from ${message.senderName}');
    } catch (e) {
      logger.e('Failed to handle chat message: $e');
    }
  }

  void handleWebRTCOffer(Map<String, dynamic> data) {
    // Handle WebRTC offer for peer connection
    logger.d('Received WebRTC offer in room $roomId');
    _emitEvent(RoomEvent.webrtcOffer(data));
  }

  void handleWebRTCAnswer(Map<String, dynamic> data) {
    // Handle WebRTC answer for peer connection
    logger.d('Received WebRTC answer in room $roomId');
    _emitEvent(RoomEvent.webrtcAnswer(data));
  }

  void handleWebRTCIceCandidate(Map<String, dynamic> data) {
    // Handle WebRTC ICE candidate
    logger.d('Received WebRTC ICE candidate in room $roomId');
    _emitEvent(RoomEvent.webrtcIceCandidate(data));
  }

  void _notifyParticipantsUpdate() {
    if (!_participantsController.isClosed) {
      _participantsController.add(currentParticipants);
    }
  }

  void _emitEvent(RoomEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Convert room to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'name': name,
      'type': type.toString().split('.').last,
      'max_participants': maxParticipants,
      'current_user': currentUser.toJson(),
      'participants': _participants.values.map((p) => p.toJson()).toList(),
      'message_count': _messages.length,
    };
  }

  /// Dispose room resources
  void dispose() {
    logger.d('Disposing room $roomId');

    // Dispose WebRTC resources
    _localStream?.dispose();
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();

    // Dispose peer connections
    for (final connection in _peerConnections.values) {
      connection.dispose();
    }

    // Close stream controllers
    if (!_eventController.isClosed) _eventController.close();
    if (!_messageController.isClosed) _messageController.close();
    if (!_participantsController.isClosed) _participantsController.close();
  }
}
