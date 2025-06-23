import 'dart:async';

import 'package:logger/logger.dart';

import 'exceptions/exceptions.dart';
import 'models/models.dart';
import 'services/services.dart';

class TalkLynkSDK {
  final String apiKey;
  final String baseUrl;
  final String wsUrl;
  final String pusherAppKey;
  final bool enableLogs;

  late final ApiService _apiService;
  late final WebSocketService _webSocketService;
  late final Logger _logger;

  final Map<String, TalkLynkRoom> _activeRooms = {};
  final StreamController<TalkLynkEvent> _eventController =
      StreamController.broadcast();

  bool _isInitialized = false;

  TalkLynkSDK({
    required this.apiKey,
    this.baseUrl = 'https://sdk.talklynk.com/backend/api',
    this.wsUrl = 'wss://ws.sdk.talklynk.com:443',
    this.pusherAppKey = 'ed25e2b7fc96a889c7a8',
    this.enableLogs = false,
  }) {
    _logger = Logger(
      printer: enableLogs ? PrettyPrinter() : PrettyPrinter(methodCount: 0),
      level: enableLogs ? Level.debug : Level.off,
    );

    _apiService = ApiService(
      baseUrl: baseUrl,
      apiKey: apiKey,
      enableLogs: enableLogs,
    );

    _webSocketService = WebSocketService(
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      apiKey: apiKey,
      pusherAppKey: pusherAppKey,
      enableLogs: enableLogs,
    );

    _setupEventListeners();
  }

  /// Stream of all SDK events
  Stream<TalkLynkEvent> get events => _eventController.stream;

  /// Check if SDK is initialized and connected
  bool get isConnected => _isInitialized && _webSocketService.isConnected;

  /// Get all active rooms
  Map<String, TalkLynkRoom> get activeRooms => Map.unmodifiable(_activeRooms);

  /// Initialize SDK and connect to WebSocket
  Future<void> initialize() async {
    if (_isInitialized) return;

    _logger.i('Initializing TalkLynk SDK...');

    try {
      // Validate API key with backend
      await _apiService.validateApiKey();

      // Connect to WebSocket
      await _webSocketService.connect();

      _isInitialized = true;
      _logger.i('TalkLynk SDK initialized successfully');

      _emitEvent(TalkLynkEvent.sdkInitialized({}));
    } catch (e) {
      _logger.e('Failed to initialize SDK: $e');
      throw TalkLynkException('SDK initialization failed: $e');
    }
  }

  /// Join a room by username (creates user if doesn't exist)
  Future<TalkLynkRoom> joinRoom({
    required String roomId,
    required String username,
    String? displayName,
    RoomType type = RoomType.video,
  }) async {
    if (!_isInitialized) {
      throw TalkLynkException('SDK not initialized. Call initialize() first.');
    }

    _logger.i('Joining room: $roomId as $username');

    try {
      // Check if room already exists locally
      if (_activeRooms.containsKey(roomId)) {
        _logger.w('Already in room: $roomId');
        return _activeRooms[roomId]!;
      }

      // Join room via API
      final response = await _apiService.joinRoom(
        roomId: roomId,
        username: username,
        displayName: displayName ?? username,
        type: type,
      );

      // Subscribe to room events
      _webSocketService.subscribeToRoom(roomId);

      // Create room object
      final room = TalkLynkRoom(
        id: response['room']['id'],
        roomId: roomId,
        name: response['room']['name'],
        type: _parseRoomType(response['room']['type']),
        maxParticipants: response['room']['max_participants'],
        currentUser: TalkLynkUser.fromJson(response['user']),
        apiService: _apiService,
        webSocketService: _webSocketService,
        logger: _logger,
      );

      // Add to active rooms
      _activeRooms[roomId] = room;

      _logger.i('Successfully joined room: $roomId');
      _emitEvent(TalkLynkEvent.roomJoined(room.toJson()));

      return room;
    } catch (e) {
      _logger.e('Failed to join room $roomId: $e');
      throw TalkLynkException('Failed to join room: $e');
    }
  }

  /// Leave a room
  Future<void> leaveRoom(String roomId) async {
    if (!_activeRooms.containsKey(roomId)) {
      _logger.w('Not in room: $roomId');
      return;
    }

    try {
      final room = _activeRooms[roomId]!;

      // Leave room via API
      await _apiService.leaveRoom(roomId);

      // Unsubscribe from room events
      _webSocketService.unsubscribeFromRoom(roomId);

      // Dispose room resources
      room.dispose();

      // Remove from active rooms
      _activeRooms.remove(roomId);

      _logger.i('Left room: $roomId');
      _emitEvent(TalkLynkEvent.roomLeft({'room_id': roomId}));
    } catch (e) {
      _logger.e('Failed to leave room $roomId: $e');
      throw TalkLynkException('Failed to leave room: $e');
    }
  }

  /// Get room by ID
  TalkLynkRoom? getRoom(String roomId) {
    return _activeRooms[roomId];
  }

  void _setupEventListeners() {
    // Listen to WebSocket events
    _webSocketService.on<Map<String, dynamic>>('user.joined').listen((data) {
      _handleUserJoined(data);
    });

    _webSocketService.on<Map<String, dynamic>>('user.left').listen((data) {
      _handleUserLeft(data);
    });

    _webSocketService.on<Map<String, dynamic>>('chat.message').listen((data) {
      _handleChatMessage(data);
    });

    _webSocketService.on<Map<String, dynamic>>('webrtc.offer').listen((data) {
      _handleWebRTCOffer(data);
    });

    _webSocketService.on<Map<String, dynamic>>('webrtc.answer').listen((data) {
      _handleWebRTCAnswer(data);
    });

    _webSocketService
        .on<Map<String, dynamic>>('webrtc.ice-candidate')
        .listen((data) {
      _handleWebRTCIceCandidate(data);
    });

    _webSocketService
        .on<Map<String, dynamic>>('connection:connected')
        .listen((data) {
      _emitEvent(TalkLynkEvent.connected(data));
    });

    _webSocketService
        .on<Map<String, dynamic>>('connection:disconnected')
        .listen((data) {
      _emitEvent(TalkLynkEvent.disconnected(data));
    });

    _webSocketService
        .on<Map<String, dynamic>>('connection:error')
        .listen((data) {
      _emitEvent(TalkLynkEvent.error(data));
    });
  }

  void _handleUserJoined(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    if (roomId != null && _activeRooms.containsKey(roomId)) {
      _activeRooms[roomId]!.handleUserJoined(data);
    }
    _emitEvent(TalkLynkEvent.userJoined(data));
  }

  void _handleUserLeft(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    if (roomId != null && _activeRooms.containsKey(roomId)) {
      _activeRooms[roomId]!.handleUserLeft(data);
    }
    _emitEvent(TalkLynkEvent.userLeft(data));
  }

  void _handleChatMessage(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    if (roomId != null && _activeRooms.containsKey(roomId)) {
      _activeRooms[roomId]!.handleChatMessage(data);
    }
    _emitEvent(TalkLynkEvent.chatMessage(data));
  }

  void _handleWebRTCOffer(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    if (roomId != null && _activeRooms.containsKey(roomId)) {
      _activeRooms[roomId]!.handleWebRTCOffer(data);
    }
    _emitEvent(TalkLynkEvent.webrtcOffer(data));
  }

  void _handleWebRTCAnswer(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    if (roomId != null && _activeRooms.containsKey(roomId)) {
      _activeRooms[roomId]!.handleWebRTCAnswer(data);
    }
    _emitEvent(TalkLynkEvent.webrtcAnswer(data));
  }

  void _handleWebRTCIceCandidate(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    if (roomId != null && _activeRooms.containsKey(roomId)) {
      _activeRooms[roomId]!.handleWebRTCIceCandidate(data);
    }
    _emitEvent(TalkLynkEvent.webrtcIceCandidate(data));
  }

  RoomType _parseRoomType(String type) {
    switch (type.toLowerCase()) {
      case 'audio':
        return RoomType.audio;
      case 'video':
        return RoomType.video;
      case 'chat':
        return RoomType.chat;
      default:
        return RoomType.video;
    }
  }

  void _emitEvent(TalkLynkEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Dispose SDK resources
  void dispose() {
    _logger.i('Disposing TalkLynk SDK');

    // Leave all rooms
    for (final roomId in _activeRooms.keys.toList()) {
      leaveRoom(roomId);
    }

    // Dispose services
    _webSocketService.dispose();
    _apiService.dispose();

    // Close event controller
    if (!_eventController.isClosed) {
      _eventController.close();
    }

    _isInitialized = false;
  }
}
