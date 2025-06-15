import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final String wsUrl;
  final String apiKey;
  final Logger _logger;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Map<String, StreamController> _eventControllers = {};
  final Set<String> _subscribedChannels = {};

  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

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
      // Create WebSocket URL with API key authentication
      final uri = Uri.parse(wsUrl).replace(
        path: '/app/pusher',
        queryParameters: {
          'protocol': '7',
          'client': 'talklynk-flutter-sdk',
          'version': '1.0.0',
          'flash': 'false',
          'X-API-Key': apiKey, // Include API key for authentication
        },
      );

      _channel = WebSocketChannel.connect(uri, protocols: ['pusher']);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      // Send authentication message immediately after connection
      _sendAuthMessage();

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      // Start heartbeat
      _startHeartbeat();

      _emitEvent('connection:connected', {});
      _logger.d('WebSocket connected successfully');
    } catch (e) {
      _isConnecting = false;
      _logger.e('WebSocket connection failed: $e');
      _emitEvent('connection:error', {'error': e.toString()});
      _scheduleReconnect();
      throw WebRTCException('WebSocket connection failed: $e');
    }
  }

  void _sendAuthMessage() {
    // Send authentication with API key
    _sendMessage({
      'event': 'pusher:connection_established',
      'auth': {
        'api_key': apiKey,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _sendMessage({
          'event': 'pusher:ping',
          'data': {},
        });
      }
    });
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.e('Max reconnection attempts reached');
      _emitEvent(
          'connection:failed', {'error': 'Max reconnection attempts reached'});
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    _logger.d(
        'Scheduling reconnect in ${delay.inSeconds} seconds (attempt $_reconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void disconnect() {
    _logger.d('Disconnecting WebSocket');

    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();

    _isConnected = false;
    _isConnecting = false;
    _subscribedChannels.clear();

    _emitEvent('connection:disconnected', {});
  }

  void subscribeToRoom(String roomId) {
    if (!_isConnected) {
      throw WebRTCException('WebSocket not connected');
    }

    final channelName = 'presence-room.$roomId';

    if (_subscribedChannels.contains(channelName)) {
      _logger.d('Already subscribed to room: $roomId');
      return;
    }

    _logger.d('Subscribing to room: $roomId');

    // Subscribe to presence channel with authentication
    _sendMessage({
      'event': 'pusher:subscribe',
      'data': {
        'channel': channelName,
        'auth': _generateAuthSignature(channelName),
        'channel_data': jsonEncode({
          'user_id': 'flutter_user', // This should be set when user joins
          'user_info': {
            'api_key': apiKey,
          }
        }),
      }
    });

    _subscribedChannels.add(channelName);
  }

  void unsubscribeFromRoom(String roomId) {
    if (!_isConnected) return;

    final channelName = 'presence-room.$roomId';

    if (!_subscribedChannels.contains(channelName)) {
      return;
    }

    _logger.d('Unsubscribing from room: $roomId');

    _sendMessage({
      'event': 'pusher:unsubscribe',
      'data': {
        'channel': channelName,
      }
    });

    _subscribedChannels.remove(channelName);
  }

  void sendWebRTCSignal(Map<String, dynamic> data) {
    if (!_isConnected) {
      throw WebRTCException('WebSocket not connected');
    }

    final roomId = data['room_id'] as String?;
    if (roomId == null) {
      throw WebRTCException('room_id is required for WebRTC signaling');
    }

    final channelName = 'presence-room.$roomId';
    final eventName = 'client-webrtc-signal';

    _sendMessage({
      'event': eventName,
      'channel': channelName,
      'data': data,
    });
  }

  String _generateAuthSignature(String channelName) {
    // Generate authentication signature for presence channels
    // This should match your Laravel broadcasting authentication
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final stringToSign = '$channelName:$apiKey:$timestamp';

    // For simplicity, we'll use the API key as the signature
    // In production, you might want to implement proper HMAC signing
    return '$apiKey:$timestamp';
  }

  Stream<T> on<T>(String eventType) {
    if (!_eventControllers.containsKey(eventType)) {
      _eventControllers[eventType] = StreamController<T>.broadcast();
    }
    return _eventControllers[eventType]!.stream.cast<T>();
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
      _logger.d('Sent WebSocket message: $message');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final eventType = data['event'] as String?;
      final channelName = data['channel'] as String?;
      final eventData = data['data'] as Map<String, dynamic>? ?? {};

      _logger
          .d('Received WebSocket event: $eventType on channel: $channelName');

      // Handle Pusher protocol events
      switch (eventType) {
        case 'pusher:connection_established':
          _handleConnectionEstablished(eventData);
          break;
        case 'pusher:pong':
          _logger.d('Received heartbeat pong');
          break;
        case 'pusher:error':
          _handlePusherError(eventData);
          break;
        case 'pusher_internal:subscription_succeeded':
          _handleSubscriptionSucceeded(channelName, eventData);
          break;
        case 'pusher_internal:subscription_error':
          _handleSubscriptionError(channelName, eventData);
          break;
        default:
          // Handle application events
          if (eventType != null) {
            _handleApplicationEvent(eventType, channelName, eventData);
          }
      }
    } catch (e) {
      _logger.e('Failed to parse WebSocket message: $e');
    }
  }

  void _handleConnectionEstablished(Map<String, dynamic> data) {
    _logger.d('Pusher connection established');
    _emitEvent('connection:established', data);
  }

  void _handlePusherError(Map<String, dynamic> data) {
    final error = data['message'] ?? 'Unknown Pusher error';
    _logger.e('Pusher error: $error');
    _emitEvent('connection:error', {'error': error});
  }

  void _handleSubscriptionSucceeded(
      String? channelName, Map<String, dynamic> data) {
    _logger.d('Subscription succeeded for channel: $channelName');
    if (channelName != null && channelName.startsWith('presence-room.')) {
      final roomId = channelName.replaceFirst('presence-room.', '');
      _emitEvent('room:subscription_succeeded', {
        'room_id': roomId,
        'presence_data': data,
      });
    }
  }

  void _handleSubscriptionError(
      String? channelName, Map<String, dynamic> data) {
    final error = data['message'] ?? 'Subscription failed';
    _logger.e('Subscription error for channel $channelName: $error');
    _emitEvent('subscription:error', {
      'channel': channelName,
      'error': error,
    });
  }

  void _handleApplicationEvent(
      String eventType, String? channelName, Map<String, dynamic> data) {
    // Map Pusher events to application events
    String mappedEventType = eventType;

    // Handle Laravel broadcasting events
    switch (eventType) {
      case 'user.joined':
        mappedEventType = 'user.joined';
        break;
      case 'user.left':
        mappedEventType = 'user.left';
        break;
      case 'chat.message':
        mappedEventType = 'chat.message';
        break;
      case 'call.started':
        mappedEventType = 'call.started';
        break;
      case 'call.ended':
        mappedEventType = 'call.ended';
        break;
      case 'webrtc.offer':
        mappedEventType = 'webrtc.offer';
        break;
      case 'webrtc.answer':
        mappedEventType = 'webrtc.answer';
        break;
      case 'webrtc.ice-candidate':
        mappedEventType = 'webrtc.ice-candidate';
        break;
      case 'typing.indicator':
        mappedEventType = 'typing.indicator';
        break;
      case 'client-webrtc-signal':
        // Handle client-side WebRTC signaling
        mappedEventType = 'webrtc.signal';
        break;
    }

    _emitEvent(mappedEventType, {
      'event': mappedEventType,
      'channel': channelName,
      'data': data,
      ...data, // Flatten data for easier access
    });
  }

  void _handleError(dynamic error) {
    _logger.e('WebSocket error: $error');
    _emitEvent('connection:error', {'error': error.toString()});
    _isConnected = false;
    _scheduleReconnect();
  }

  void _handleDisconnection() {
    _logger.d('WebSocket disconnected');
    _isConnected = false;
    _subscribedChannels.clear();
    _emitEvent('connection:disconnected', {});

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  void _emitEvent(String eventType, Map<String, dynamic> data) {
    // Emit to specific event listeners
    if (_eventControllers.containsKey(eventType)) {
      _eventControllers[eventType]!.add(data);
    }

    // Emit to general event listeners (empty string key)
    if (_eventControllers.containsKey('')) {
      _eventControllers['']!.add({
        'event': eventType,
        'data': data,
      });
    }
  }

  void dispose() {
    disconnect();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
  }
}
