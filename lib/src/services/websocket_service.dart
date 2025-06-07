// lib/src/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:talklynk_sdk/talklynk_sdk.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final String wsUrl;
  final String apiKey;
  final Logger _logger;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Map<String, StreamController> _eventControllers = {};

  bool _isConnected = false;
  bool _isConnecting = false;

  WebSocketService({
    required this.wsUrl,
    required this.apiKey,
    required bool enableLogs,
  }) : _logger = Logger(
          printer: enableLogs ? PrettyPrinter() : PrettyPrinter(methodCount: 0),
          level: enableLogs ? Level.debug : Level.off,
        );

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    _isConnecting = true;
    _logger.d('Connecting to WebSocket: $wsUrl');

    try {
      // Create WebSocket URL with API key
      final uri = Uri.parse(wsUrl).replace(
        queryParameters: {'api_key': apiKey},
      );

      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      _isConnected = true;
      _isConnecting = false;

      _emitEvent('connection:connected', {});
      _logger.d('WebSocket connected successfully');
    } catch (e) {
      _isConnecting = false;
      _logger.e('WebSocket connection failed: $e');
      _emitEvent('connection:error', {'error': e.toString()});
      throw WebRTCException('WebSocket connection failed: $e');
    }
  }

  void disconnect() {
    _logger.d('Disconnecting WebSocket');

    _subscription?.cancel();
    _channel?.sink.close();

    _isConnected = false;
    _isConnecting = false;

    _emitEvent('connection:disconnected', {});
  }

  void subscribeToRoom(String roomId) {
    if (!_isConnected) {
      throw WebRTCException('WebSocket not connected');
    }

    _logger.d('Subscribing to room: $roomId');

    _sendMessage({
      'event': 'subscribe',
      'channel': 'room.$roomId',
    });
  }

  void unsubscribeFromRoom(String roomId) {
    if (!_isConnected) return;

    _logger.d('Unsubscribing from room: $roomId');

    _sendMessage({
      'event': 'unsubscribe',
      'channel': 'room.$roomId',
    });
  }

  void sendWebRTCSignal(Map<String, dynamic> data) {
    _sendMessage({
      'event': 'webrtc-signal',
      'data': data,
    });
  }

  Stream<T> on<T>(String eventType) {
    if (!_eventControllers.containsKey(eventType)) {
      _eventControllers[eventType] = StreamController<T>.broadcast();
    }
    return _eventControllers[eventType]!.stream.cast<T>();
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
      _logger.d('Sent WebSocket message: $message');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final eventType = data['event'] as String?;
      final eventData = data['data'] as Map<String, dynamic>? ?? {};

      _logger.d('Received WebSocket event: $eventType');

      if (eventType != null) {
        _emitEvent(eventType, eventData);
      }
    } catch (e) {
      _logger.e('Failed to parse WebSocket message: $e');
    }
  }

  void _handleError(dynamic error) {
    _logger.e('WebSocket error: $error');
    _emitEvent('connection:error', {'error': error.toString()});
  }

  void _handleDisconnection() {
    _logger.d('WebSocket disconnected');
    _isConnected = false;
    _emitEvent('connection:disconnected', {});
  }

  void _emitEvent(String eventType, Map<String, dynamic> data) {
    if (_eventControllers.containsKey(eventType)) {
      _eventControllers[eventType]!.add(data);
    }
  }

  void dispose() {
    disconnect();
    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
  }
}
