import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:talklynk_sdk/src/models/chat_message.dart' as Message;
import 'package:talklynk_sdk/talklynk_sdk.dart';

class WebRTCProvider extends ChangeNotifier {
  final WebRTCClient _client;

  // Connection state
  bool _isConnected = false;
  String? _connectionError;

  // User state
  User? _currentUser;

  // Room state
  Room? _currentRoom;
  List<Participant> _participants = [];

  // Media state
  MediaStream? _localStream;
  Map<int, MediaStream> _remoteStreams = {};
  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;
  bool _isInCall = false;

  // Chat state
  List<ChatMessage> _messages = [];

  WebRTCProvider(TalklynkSdkConfig config) : _client = WebRTCClient(config) {
    _setupEventListeners();
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get connectionError => _connectionError;
  User? get currentUser => _currentUser;
  Room? get currentRoom => _currentRoom;
  List<Participant> get participants => List.unmodifiable(_participants);
  MediaStream? get localStream => _localStream;
  Map<int, MediaStream> get remoteStreams => Map.unmodifiable(_remoteStreams);
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isInCall => _isInCall;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  WebRTCClient get client => _client;

  void _setupEventListeners() {
    _client.events.listen((event) {
      switch (event.runtimeType) {
        case ConnectedEvent:
          _isConnected = true;
          _connectionError = null;
          notifyListeners();
          break;

        case DisconnectedEvent:
          _isConnected = false;
          notifyListeners();
          break;

        case ConnectionErrorEvent:
          final e = event as ConnectionErrorEvent;
          _connectionError = e.error;
          _isConnected = false;
          notifyListeners();
          break;

        case RoomJoinedEvent:
          final e = event as RoomJoinedEvent;
          _currentRoom = e.result.room;
          _participants = e.result.participants;
          _messages.clear(); // Clear previous messages
          notifyListeners();
          break;

        case RoomLeftEvent:
          _currentRoom = null;
          _participants.clear();
          _messages.clear();
          _endCall();
          notifyListeners();
          break;

        case UserJoinedEvent:
          final e = event as UserJoinedEvent;
          _participants.add(e.participant);
          notifyListeners();
          break;

        case UserLeftEvent:
          final e = event as UserLeftEvent;
          _participants.removeWhere((p) => p.id == e.participant.id);
          notifyListeners();
          break;

        case MessageReceivedEvent:
          final e = event as MessageReceivedEvent;
          _messages.add(e.message);
          notifyListeners();
          break;

        case LocalStreamAddedEvent:
          final e = event as LocalStreamAddedEvent;
          _localStream = e.stream;
          notifyListeners();
          break;

        case RemoteStreamAddedEvent:
          final e = event as RemoteStreamAddedEvent;
          _remoteStreams[e.userId] = e.stream;
          notifyListeners();
          break;

        case RemoteStreamRemovedEvent:
          final e = event as RemoteStreamRemovedEvent;
          _remoteStreams.remove(e.userId);
          notifyListeners();
          break;

        case CallStartedEvent:
          _isInCall = true;
          notifyListeners();
          break;

        case CallEndedEvent:
          _endCall();
          notifyListeners();
          break;
      }
    });
  }

  // Connection methods
  Future<void> connect() async {
    try {
      await _client.connect();
    } catch (e) {
      _connectionError = e.toString();
      notifyListeners();
    }
  }

  void disconnect() {
    _client.disconnect();
    _reset();
  }

  // User methods
  void setCurrentUser(User user) {
    _currentUser = user;
    _client.setCurrentUser(user);
    notifyListeners();
  }

  // Room methods
  Future<Room> createRoom(CreateRoomOptions options) async {
    return await _client.createRoom(options);
  }

  Future<List<Room>> getRooms() async {
    return await _client.getRooms();
  }

  // Override the existing joinRoom method to be more robust
  @override
  Future<void> joinRoom(String roomId) async {
    try {
      if (_currentUser == null) {
        throw Exception('No current user set. Please create a user first.');
      }

      // Use the current user's external ID or database ID
      final userId = _currentUser!.externalId ?? _currentUser!.id.toString();

      final result = await _client.joinRoom(
        roomId,
        userId: userId,
        userName: _currentUser!.name,
        userEmail: _currentUser!.email,
      );

      _currentRoom = result.room;
      _participants = result.participants;

      notifyListeners();
    } catch (e) {
      print('Failed to join room: $e');
      rethrow;
    }
  }

  // Future<void> joinRoom(String roomId) async {
  //   if (_currentUser == null) {
  //     throw WebRTCException('Current user must be set before joining a room');
  //   }

  //   await _client.joinRoom(roomId, username: _currentUser!.name);
  //   // Load existing messages
  //   _loadMessages(roomId);
  // }

  Future<void> joinRoomWithUserData(
    String roomId, {
    required String userId,
    String? userName,
    String? userEmail,
  }) async {
    try {
      await _client.joinRoom(
        roomId,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
      );
    } catch (e) {
      print('Failed to join room with user data: $e');
      rethrow;
    }
  }

  // Method to join room with username
  Future<void> joinRoomWithUsername(String roomId, String username) async {
    try {
      await _client.joinRoomWithUsername(roomId, username);
    } catch (e) {
      print('Failed to join room with username: $e');
      rethrow;
    }
  }

  // Method to create user
  Future<User> createUser({
    required String name,
    String? email,
    String? externalId,
  }) async {
    try {
      final user = await _client.createUser(
        name: name,
        email: email,
        externalId: externalId,
      );

      setCurrentUser(user);
      notifyListeners();

      return user;
    } catch (e) {
      print('Failed to create user: $e');
      rethrow;
    }
  }

  // Method to get user by identifier
  Future<User?> getUser(String identifier) async {
    try {
      return await _client.getUser(identifier);
    } catch (e) {
      print('Failed to get user: $e');
      return null;
    }
  }

  Future<void> leaveRoom() async {
    if (_currentRoom != null && _currentUser != null) {
      await _client.leaveRoom(_currentRoom!.roomId,
          username: _currentUser!.name);
    }
  }

  // Media methods
  Future<void> getUserMedia([MediaConstraints? constraints]) async {
    try {
      final stream = await _client.getUserMedia(constraints);
      _localStream = stream;
      notifyListeners();
    } catch (e) {
      _connectionError = e.toString();
      notifyListeners();
    }
  }

  Future<void> startCall() async {
    if (_currentRoom == null || _currentUser == null) return;

    try {
      // Ensure we have local media first
      if (_localStream == null) {
        await getUserMedia();
      }

      final participantIds = _participants.map((p) => p.user.id).toList();
      await _client.startCall(_currentRoom!.roomId, participantIds);
    } catch (e) {
      _connectionError = e.toString();
      notifyListeners();
    }
  }

  void endCall() {
    if (_currentRoom != null) {
      _client.endCall(_currentRoom!.roomId);
    }
  }

  Future<void> toggleAudio() async {
    _isAudioEnabled = !_isAudioEnabled;
    await _client.toggleAudio(_isAudioEnabled);
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    _isVideoEnabled = !_isVideoEnabled;
    await _client.toggleVideo(_isVideoEnabled);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _client.switchCamera();
  }

  // Chat methods
  Future<void> sendMessage(String message) async {
    if (_currentRoom == null || _currentUser == null) return;

    try {
      final sendOptions = SendMessageOptions(
        userId: _currentUser!.id,
        message: message,
        type: Message.MessageType.text,
      );

      final chatMessage =
          await _client.sendMessage(_currentRoom!.roomId, sendOptions);

      // Only add if it's not already in the list (avoid duplicates from WebSocket)
      if (!_messages.any((m) => m.id == chatMessage.id)) {
        _messages.add(chatMessage);
        notifyListeners();
      }
    } catch (e) {
      _connectionError = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendFile(String filePath) async {
    if (_currentRoom == null || _currentUser == null) return;

    try {
      final sendOptions = SendMessageOptions(
        userId: _currentUser!.id,
        filePath: filePath,
        type: Message.MessageType.file,
      );

      final chatMessage =
          await _client.sendMessage(_currentRoom!.roomId, sendOptions);

      // Only add if it's not already in the list
      if (!_messages.any((m) => m.id == chatMessage.id)) {
        _messages.add(chatMessage);
        notifyListeners();
      }
    } catch (e) {
      _connectionError = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendTypingIndicator(bool isTyping) async {
    if (_currentRoom == null || _currentUser == null) return;

    try {
      await _client.sendTypingIndicator(_currentRoom!.roomId, isTyping,
          userId: _currentUser!.id);
    } catch (e) {
      // Don't show error for typing indicators
      print('Failed to send typing indicator: $e');
    }
  }

  Future<void> _loadMessages(String roomId) async {
    try {
      final messages = await _client.getMessages(roomId);
      _messages = messages.reversed.toList(); // Show newest first
      notifyListeners();
    } catch (e) {
      // Don't show error for message loading
      print('Failed to load messages: $e');
    }
  }

  void _endCall() {
    _isInCall = false;
    _localStream = null;
    _remoteStreams.clear();
    _isAudioEnabled = true;
    _isVideoEnabled = true;
  }

  void _reset() {
    _isConnected = false;
    _connectionError = null;
    _currentRoom = null;
    _participants.clear();
    _messages.clear();
    _endCall();
    notifyListeners();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}
