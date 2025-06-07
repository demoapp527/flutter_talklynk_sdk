// lib/src/providers/webrtc_provider.dart

import 'package:flutter/foundation.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';
import 'package:talklynk_sdk/src/models/chat_message.dart' as Message;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCProvider extends ChangeNotifier {
  final WebRTCClient _client;

  // Connection state
  bool _isConnected = false;
  String? _connectionError;

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
    _client.setCurrentUser(user);
  }

  // Room methods
  Future<Room> createRoom(CreateRoomOptions options) async {
    return await _client.createRoom(options);
  }

  Future<List<Room>> getRooms() async {
    return await _client.getRooms();
  }

  Future<void> joinRoom(String roomId) async {
    await _client.joinRoom(roomId);
    // Load existing messages
    _loadMessages(roomId);
  }

  Future<void> leaveRoom() async {
    if (_currentRoom != null) {
      await _client.leaveRoom(_currentRoom!.roomId);
    }
  }

  // Media methods
  Future<void> startCall() async {
    if (_currentRoom == null) return;

    try {
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
    if (_currentRoom == null) return;

    try {
      final chatMessage = await _client.sendMessage(
        _currentRoom!.roomId,
        SendMessageOptions(message: message, type: Message.MessageType.text),
      );
      _messages.add(chatMessage);
      notifyListeners();
    } catch (e) {
      _connectionError = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendFile(String filePath) async {
    if (_currentRoom == null) return;

    try {
      final chatMessage = await _client.sendMessage(
        _currentRoom!.roomId,
        SendMessageOptions(
          filePath: filePath,
          type: Message.MessageType.file,
        ),
      );
      _messages.add(chatMessage);
      notifyListeners();
    } catch (e) {
      _connectionError = e.toString();
      notifyListeners();
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
