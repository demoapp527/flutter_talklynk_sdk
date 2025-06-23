import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final String baseUrl;
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
    required this.baseUrl,
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

// Update your _authenticateChannel to catch and log the specific error
  Future<Map<String, dynamic>> _authenticateChannel(String channelName) async {
    try {
      if (_socketId == null) {
        throw Exception('Socket ID not available for authentication');
      }

      _logger.d('🔐 Starting authentication for channel: $channelName');
      _logger.d('🔐 Socket ID: $_socketId');
      _logger.d('🔐 API Key: ${apiKey.substring(0, 10)}...');
      _logger.d('🔐 Original WS URL: $wsUrl');

      final authUrl = '$baseUrl/broadcasting/auth';

      _logger.d('🔐 Constructed auth URL: $authUrl');

      final requestBody = {
        'socket_id': _socketId!,
        'channel_name': channelName,
        'api_key': apiKey,
      };

      _logger.d('🔐 Making HTTP request...');

      final response = await http
          .post(
            Uri.parse(authUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
              'User-Agent': 'Flutter-TalkLynk-SDK/1.0',
            },
            body: requestBody,
          )
          .timeout(Duration(seconds: 10)); // Add timeout

      _logger.d('🔐 HTTP request completed');
      _logger.d('🔐 Auth response status: ${response.statusCode}');
      _logger.d('🔐 Auth response body: ${response.body}');

      if (response.statusCode == 200) {
        final authData = jsonDecode(response.body);
        _logger.d('✅ Authentication successful');
        return authData;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException catch (e) {
      _logger.e('⏰ Authentication timeout: $e');
      rethrow;
    } on SocketException catch (e) {
      _logger.e('🌐 Network error: $e');
      rethrow;
    } on FormatException catch (e) {
      _logger.e('📝 JSON parsing error: $e');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('❌ Authentication error: $e');
      _logger.e('❌ Error type: ${e.runtimeType}');
      _logger.e('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

// Also update subscribeToRoom to handle auth failures gracefully
  void subscribeToRoom(String roomId) async {
    if (!_isConnected) {
      _logger.w('Cannot subscribe: WebSocket not connected');
      return;
    }

    final channelName = 'private-room.$roomId';

    if (_subscribedChannels.contains(channelName)) {
      _logger.d('Already subscribed to room: $roomId');
      return;
    }

    _logger.d(
        '🚀 Starting subscription to room: $roomId on channel: $channelName');

    try {
      // Get authentication data
      _logger.d('🔐 Getting authentication...');
      final authData = await _authenticateChannel(channelName);

      final subscribeData = {
        'channel': channelName,
        'auth': authData['auth'],
      };

      // Add channel_data if provided
      if (authData.containsKey('channel_data')) {
        subscribeData['channel_data'] = authData['channel_data'];
      }

      _logger.d('📡 Sending subscription message: $subscribeData');

      _sendMessage({
        'event': 'pusher:subscribe',
        'data': subscribeData,
      });

      _subscribedChannels.add(channelName);
      _logger.d('✅ Subscription request sent for: $channelName');
    } catch (e, stackTrace) {
      _logger.e('💥 Failed to subscribe to room: $e');
      _logger.e('💥 Stack trace: $stackTrace');

      // Try fallback without authentication for debugging
      _logger.w('🔄 Trying fallback subscription without auth...');
      try {
        _sendMessage({
          'event': 'pusher:subscribe',
          'data': {
            'channel': channelName,
            'auth': '$_socketId:$apiKey', // Simple auth fallback
          }
        });
        _subscribedChannels.add(channelName);
        _logger.w(
            '⚠️ Fallback subscription sent (may not work for private channels)');
      } catch (fallbackError) {
        _logger.e('💥 Even fallback failed: $fallbackError');
      }

      // Emit subscription error
      _emitEvent('subscription:error', {
        'room_id': roomId,
        'channel': channelName,
        'error': e.toString(),
      });
    }
  }

  void unsubscribeFromRoom(String roomId) {
    if (!_isConnected) return;

    final channelName = 'private-room.$roomId';

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
      // Log EVERY message - even before parsing
      _logger.d('🔍 RAW WebSocket message received: $message');

      final data = jsonDecode(message) as Map<String, dynamic>;
      final eventType = data['event'] as String?;
      final channelName = data['channel'] as String?;
      final eventDataRaw = data['data'];

      _logger
          .d('📡 Parsed WebSocket - Event: $eventType, Channel: $channelName');

      // Special logging for user.joined events
      if (eventType == 'user.joined') {
        _logger.d('🎉 RECEIVED user.joined EVENT!');
        _logger.d('🎉 Channel: $channelName');
        _logger.d('🎉 Data: $eventDataRaw');
      }

      // Special logging for chat.message events
      if (eventType == 'chat.message') {
        _logger.d('💬 RECEIVED chat.message EVENT!');
        _logger.d('💬 Channel: $channelName');
        _logger.d('💬 Data: $eventDataRaw');
      }

      // Parse event data if it's a JSON string
      dynamic eventData;
      if (eventDataRaw is String) {
        try {
          eventData = jsonDecode(eventDataRaw);
          _logger.d('📦 Parsed event data from JSON string: $eventData');
        } catch (e) {
          eventData = eventDataRaw;
          _logger.d('📦 Event data as string: $eventData');
        }
      } else {
        eventData = eventDataRaw;
        _logger.d('📦 Event data as object: $eventData');
      }

      // Handle Pusher protocol events
      if (eventType != null) {
        final normalizedEventType = eventType.replaceAll('.', ':');

        switch (normalizedEventType) {
          case 'pusher:connection_established':
            _logger.d('✅ Pusher connection established');
            _handleConnectionEstablished(eventData);
            return;

          case 'pusher:pong':
            _logger.d('💓 Received heartbeat pong');
            return;

          case 'pusher:error':
            _logger.e('❌ Pusher error received');
            _handlePusherError(eventData);
            return;

          case 'pusher:subscribe:response':
            _logger.d('📝 Subscription response: $eventData');
            return;

          case 'pusher_internal:subscription_succeeded':
            _logger.d('🎉 Subscription succeeded for: $channelName');
            _handleSubscriptionSucceeded(channelName, eventData);
            return;

          case 'pusher_internal:subscription_error':
            _logger.e('💥 Subscription error for: $channelName');
            _handleSubscriptionError(channelName, eventData);
            return;

          case 'pusher_internal:member_added':
            _logger.d('👤 Member added to: $channelName');
            _handleMemberAdded(channelName, eventData);
            return;

          case 'pusher_internal:member_removed':
            _logger.d('👤 Member removed from: $channelName');
            _handleMemberRemoved(channelName, eventData);
            return;
        }
      }

      // Log all non-Pusher events
      if (eventType != null && !eventType.startsWith('pusher')) {
        _logger.d('🎯 APPLICATION EVENT RECEIVED!');
        _logger.d('   Event Type: $eventType');
        _logger.d('   Channel: $channelName');
        _logger.d('   Data: $eventData');

        _handleApplicationEvent(eventType, channelName, eventData);
      } else if (eventType != null) {
        _logger.d('🔧 Pusher system event: $eventType');
      } else {
        _logger.w('❓ Event with no type: $data');
      }
    } catch (e, stackTrace) {
      _logger.e('💥 Failed to parse WebSocket message: $e');
      _logger.e('Stack trace: $stackTrace');
      _logger.e('Raw message was: $message');
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

    if (channelName != null && channelName.startsWith('private-room.')) {
      final roomId = channelName.replaceFirst('private-room.', '');

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
    if (channelName != null && channelName.startsWith('private-room.')) {
      final roomId = channelName.replaceFirst('private-room.', '');

      _emitEvent('user.joined', {
        'room_id': roomId,
        'user': data,
      });
    }
  }

  void _handleMemberRemoved(String? channelName, dynamic data) {
    if (channelName != null && channelName.startsWith('private-room.')) {
      final roomId = channelName.replaceFirst('private-room.', '');

      _emitEvent('user.left', {
        'room_id': roomId,
        'user': data,
      });
    }
  }

  void _handleApplicationEvent(
      String eventType, String? channelName, dynamic eventData) {
    try {
      _logger.d('🚀 Processing application event: $eventType');
      _logger.d('   Channel: $channelName');
      _logger.d('   Data: $eventData');

      // Map event types
      String mappedEventType = eventType;

      // Extract room_id from channel name
      String? roomId;
      if (channelName != null && channelName.startsWith('private-room.')) {
        roomId = channelName.replaceFirst('private-room.', '');
        _logger.d('   Extracted room_id: $roomId');
      }

      // Prepare final event data
      Map<String, dynamic> finalEventData = {
        'event': mappedEventType,
        'channel': channelName,
        'room_id': roomId,
      };

      if (eventData is Map<String, dynamic>) {
        finalEventData.addAll(eventData);
      } else {
        finalEventData['data'] = eventData;
      }

      _logger.d('🎉 Emitting event: $mappedEventType');
      _logger.d('   Final data: $finalEventData');

      _emitEvent(mappedEventType, finalEventData);

      // Also emit to any general listeners
      _emitEvent('*', {
        'event': mappedEventType,
        'data': finalEventData,
      });
    } catch (e, stackTrace) {
      _logger.e('💥 Error in _handleApplicationEvent: $e');
      _logger.e('Stack trace: $stackTrace');
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
