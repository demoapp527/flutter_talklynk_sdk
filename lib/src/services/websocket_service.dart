import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final String wsUrl;
  final String apiKey;
  final String pusherAppKey;
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
  String? _socketId;

  WebSocketService({
    required this.wsUrl,
    required this.apiKey,
    required this.pusherAppKey,
    required bool enableLogs,
  }) : _logger = Logger(
          printer: enableLogs ? PrettyPrinter() : PrettyPrinter(methodCount: 0),
          level: enableLogs ? Level.debug : Level.off,
        );

  bool get isConnected => _isConnected;
  String? get socketId => _socketId;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    _isConnecting = true;
    _logger.d('Connecting to WebSocket: $wsUrl');

    try {
      final wsUri = _buildWebSocketUri();
      _logger.d('Connecting to: $wsUri');

      _channel = WebSocketChannel.connect(wsUri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      // Wait for connection established event with timeout
      final connectionTimeout = Timer(Duration(seconds: 10), () {
        if (!_isConnected && _isConnecting) {
          _isConnecting = false;
          _logger.e(
              'Connection timeout - no connection_established event received');
          throw Exception(
              'Connection timeout - no connection_established event received');
        }
      });

      // Wait for connection to be established
      while (_isConnecting && !_isConnected) {
        await Future.delayed(Duration(milliseconds: 100));
      }

      connectionTimeout.cancel();

      if (_isConnected) {
        _isConnecting = false;
        _reconnectAttempts = 0;
        _logger.d('WebSocket connected successfully');
        _emitEvent('connection:connected', {});
      } else {
        throw Exception('Connection failed - unknown reason');
      }
    } catch (e) {
      _isConnecting = false;
      _logger.e('WebSocket connection failed: $e');
      _emitEvent('connection:error', {'error': e.toString()});
      _scheduleReconnect();
      throw WebRTCException('WebSocket connection failed: $e');
    }
  }

  Uri _buildWebSocketUri() {
    final uri = Uri.parse(wsUrl);

    String wsScheme = uri.scheme;
    int port = uri.hasPort ? uri.port : (wsScheme == 'wss' ? 443 : 80);

    return Uri(
      scheme: wsScheme,
      host: uri.host,
      port: port,
      path: '/app/$pusherAppKey',
      queryParameters: {
        'protocol': '7',
        'client': 'flutter',
        'version': '1.0.0',
        'flash': 'false',
      },
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
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

    try {
      _channel?.sink.close(1000, 'Client disconnecting');
    } catch (e) {
      _logger.w('Error closing WebSocket: $e');
    }

    _isConnected = false;
    _isConnecting = false;
    _subscribedChannels.clear();
    _socketId = null;

    _emitEvent('connection:disconnected', {});
  }

  void subscribeToRoom(String roomId) {
    if (!_isConnected) {
      _logger.w('Cannot subscribe: WebSocket not connected');
      return;
    }

    final channelName = 'presence-room.$roomId';

    if (_subscribedChannels.contains(channelName)) {
      _logger.d('Already subscribed to room: $roomId');
      return;
    }

    _logger.d('Subscribing to room: $roomId');

    _sendMessage({
      'event': 'pusher:subscribe',
      'data': {
        'channel': channelName,
        'auth': _generateAuthToken(channelName),
        'channel_data': jsonEncode({
          'user_id': 'flutter_user',
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

  String _generateAuthToken(String channelName) {
    if (_socketId != null) {
      return '$_socketId:$apiKey';
    }
    return apiKey;
  }

  Stream<T> on<T>(String eventType) {
    if (!_eventControllers.containsKey(eventType)) {
      _eventControllers[eventType] = StreamController<T>.broadcast();
    }
    return _eventControllers[eventType]!.stream.cast<T>();
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      try {
        final jsonMessage = jsonEncode(message);
        _channel!.sink.add(jsonMessage);
        _logger.d('Sent WebSocket message: $message');
      } catch (e) {
        _logger.e('Failed to send message: $e');
      }
    } else {
      _logger.w('Cannot send message: WebSocket not connected');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      _logger.d('Raw WebSocket message: $message');

      final data = jsonDecode(message) as Map<String, dynamic>;
      final eventType = data['event'] as String?;
      final channelName = data['channel'] as String?;
      final eventDataRaw = data['data'];

      _logger.d('Parsed WebSocket event: $eventType on channel: $channelName');

      // Parse event data if it's a JSON string
      dynamic eventData;
      if (eventDataRaw is String) {
        try {
          eventData = jsonDecode(eventDataRaw);
        } catch (e) {
          eventData = eventDataRaw;
        }
      } else {
        eventData = eventDataRaw;
      }

      // Handle Pusher protocol events - check for both colon and dot notation
      if (eventType != null) {
        // Normalize event names (replace dots with colons for consistent handling)
        final normalizedEventType = eventType.replaceAll('.', ':');

        switch (normalizedEventType) {
          case 'pusher:connection_established':
            _handleConnectionEstablished(eventData);
            return; // Return early to avoid application event handling

          case 'pusher:pong':
            _logger.d('Received heartbeat pong');
            return;

          case 'pusher:error':
            _handlePusherError(eventData);
            return;

          case 'pusher_internal:subscription_succeeded':
            _handleSubscriptionSucceeded(channelName, eventData);
            return;

          case 'pusher_internal:subscription_error':
            _handleSubscriptionError(channelName, eventData);
            return;

          case 'pusher_internal:member_added':
            _handleMemberAdded(channelName, eventData);
            return;

          case 'pusher_internal:member_removed':
            _handleMemberRemoved(channelName, eventData);
            return;
        }
      }

      // If we reach here, it's an application event
      if (eventType != null && !eventType.startsWith('pusher')) {
        _handleApplicationEvent(eventType, channelName, eventData);
      }
    } catch (e) {
      _logger.e('Failed to parse WebSocket message: $e');
    }
  }

  void _handleConnectionEstablished(dynamic data) {
    try {
      _socketId = data['socket_id'];

      _logger.d('Pusher connection established with socket_id: $_socketId');

      _isConnected = true; // Mark as connected
      _isConnecting = false; // Stop connecting flag

      // Start heartbeat after connection is established
      _startHeartbeat();

      _emitEvent('connection:established', data);
    } catch (e) {
      _logger.e('Error handling connection established: $e');
    }
  }

  void _handlePusherError(dynamic data) {
    try {
      final error = data['message'] ?? 'Unknown Pusher error';
      final code = data['code'];

      _logger.e('Pusher error (code: $code): $error');
      _emitEvent('connection:error', {'error': error, 'code': code});
    } catch (e) {
      _logger.e('Error handling Pusher error: $e');
    }
  }

  void _handleSubscriptionSucceeded(String? channelName, dynamic data) {
    _logger.d('Subscription succeeded for channel: $channelName');

    if (channelName != null && channelName.startsWith('presence-room.')) {
      final roomId = channelName.replaceFirst('presence-room.', '');

      _emitEvent('room:subscription_succeeded', {
        'room_id': roomId,
        'presence_data': data,
      });
    }
  }

  void _handleSubscriptionError(String? channelName, dynamic data) {
    try {
      final error = data['message'] ?? 'Subscription failed';

      _logger.e('Subscription error for channel $channelName: $error');
      _emitEvent('subscription:error', {
        'channel': channelName,
        'error': error,
      });
    } catch (e) {
      _logger.e('Error handling subscription error: $e');
    }
  }

  void _handleMemberAdded(String? channelName, dynamic data) {
    if (channelName != null && channelName.startsWith('presence-room.')) {
      final roomId = channelName.replaceFirst('presence-room.', '');

      _emitEvent('user.joined', {
        'room_id': roomId,
        'user': data,
      });
    }
  }

  void _handleMemberRemoved(String? channelName, dynamic data) {
    if (channelName != null && channelName.startsWith('presence-room.')) {
      final roomId = channelName.replaceFirst('presence-room.', '');

      _emitEvent('user.left', {
        'room_id': roomId,
        'user': data,
      });
    }
  }

  void _handleApplicationEvent(
      String eventType, String? channelName, dynamic eventData) {
    try {
      _logger.d('Application event: $eventType with data: $eventData');

      // Map Laravel broadcasting events to application events
      String mappedEventType = eventType;

      switch (eventType) {
        case 'user.joined':
        case 'user.left':
        case 'chat.message':
        case 'call.started':
        case 'call.ended':
        case 'webrtc.offer':
        case 'webrtc.answer':
        case 'webrtc.ice-candidate':
        case 'typing.indicator':
          mappedEventType = eventType;
          break;
        case 'client-webrtc-signal':
          mappedEventType = 'webrtc.signal';
          break;
      }

      _emitEvent(mappedEventType, {
        'event': mappedEventType,
        'channel': channelName,
        'data': eventData,
        ...eventData is Map<String, dynamic> ? eventData : {},
      });
    } catch (e) {
      _logger.e('Error handling application event: $e');
    }
  }

  void _handleError(dynamic error) {
    _logger.e('WebSocket error: $error');
    _emitEvent('connection:error', {'error': error.toString()});
    _isConnected = false;
    _isConnecting = false;

    // Don't auto-reconnect on certain errors
    if (error.toString().contains('426') ||
        error.toString().contains('401') ||
        error.toString().contains('403')) {
      _logger.e('Authentication or protocol error, not retrying');
      return;
    }

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  void _handleDisconnection() {
    _logger.d('WebSocket disconnected');
    _isConnected = false;
    _isConnecting = false;
    _subscribedChannels.clear();
    _socketId = null;
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
