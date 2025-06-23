import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../exceptions/exceptions.dart';
import '../models/models.dart';

class ApiService {
  final String baseUrl;
  final String apiKey;
  final Logger _logger;
  late final http.Client _client;

  ApiService({
    required this.baseUrl,
    required this.apiKey,
    required bool enableLogs,
  }) : _logger = Logger(
          printer: enableLogs ? PrettyPrinter() : PrettyPrinter(methodCount: 0),
          level: enableLogs ? Level.debug : Level.off,
        ) {
    _client = http.Client();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-Key': apiKey,
        'Authorization': 'Bearer $apiKey',
      };

  /// Validate API key with backend
  Future<Map<String, dynamic>> validateApiKey() async {
    try {
      _logger.d('Validating API key...');

      final response = await _client.get(
        Uri.parse('$baseUrl/sdk/rooms'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        _logger.d('API key validation successful');
        return jsonDecode(response.body);
      } else {
        throw TalkLynkException('Invalid API key: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('API key validation failed: $e');
      throw TalkLynkException('API key validation failed: $e');
    }
  }

  /// Join a room
  Future<Map<String, dynamic>> joinRoom({
    required String roomId,
    required String username,
    required String displayName,
    required RoomType type,
  }) async {
    try {
      _logger.d('Joining room: $roomId as $username');

      final response = await _client.post(
        Uri.parse('$baseUrl/sdk/rooms/$roomId/join'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'display_name': displayName,
          'type': type.toString().split('.').last,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _logger.d('Successfully joined room: $roomId');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw TalkLynkException(
            'Failed to join room: ${error['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _logger.e('Failed to join room $roomId: $e');
      rethrow;
    }
  }

  /// Leave a room
  Future<void> leaveRoom(String roomId) async {
    try {
      _logger.d('Leaving room: $roomId');

      final response = await _client.post(
        Uri.parse('$baseUrl/sdk/rooms/$roomId/leave'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw TalkLynkException(
            'Failed to leave room: ${error['message'] ?? 'Unknown error'}');
      }

      _logger.d('Successfully left room: $roomId');
    } catch (e) {
      _logger.e('Failed to leave room $roomId: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRoomMessages(String roomId) async {
    try {
      _logger.d('Fetching messages for room: $roomId');

      final response = await _client.get(
        Uri.parse('$baseUrl/sdk/rooms/$roomId/messages'),
        headers: _headers,
      );

      _logger.d('Messages response status: ${response.statusCode}');
      _logger.d('Messages response body type: ${response.body.runtimeType}');
      _logger.d(
          'Messages response body preview: ${response.body.substring(0, Math.min(200, response.body.length))}...');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _logger.d('Decoded response type: ${responseData.runtimeType}');

        if (responseData is Map<String, dynamic>) {
          _logger.d('Response keys: ${responseData.keys.toList()}');
          return responseData;
        } else if (responseData is List) {
          _logger.d('Response is list with ${responseData.length} items');
          return {
            'data': responseData,
            'pagination': {
              'current_page': 1,
              'total': responseData.length,
              'per_page': responseData.length,
              'last_page': 1,
            }
          };
        } else {
          _logger.e('Unexpected response format: ${responseData.runtimeType}');
          throw TalkLynkException('Unexpected response format for messages');
        }
      } else {
        final error = jsonDecode(response.body);
        throw TalkLynkException(
            'Failed to get messages: ${error['message'] ?? error['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _logger.e('Failed to get room messages: $e');
      _logger.e('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Get room participants - FIXED VERSION
  Future<Map<String, dynamic>> getRoomParticipants(String roomId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/sdk/rooms/$roomId/participants'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Handle both old format and new format
        if (responseData is Map<String, dynamic>) {
          // New format: {"data": [...], "total_count": 5, "room": {...}}
          return responseData;
        } else if (responseData is List) {
          // Old format: direct array
          return {
            'data': responseData,
            'total_count': responseData.length,
          };
        } else {
          throw TalkLynkException(
              'Unexpected response format for participants');
        }
      } else {
        final error = jsonDecode(response.body);
        throw TalkLynkException(
            'Failed to get participants: ${error['message'] ?? error['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _logger.e('Failed to get room participants: $e');
      rethrow;
    }
  }

  /// Send message - FIXED VERSION
  Future<Map<String, dynamic>> sendMessage({
    required String roomId,
    required String username,
    required String message,
    required ChatMessageType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.d('Sending message to room: $roomId from user: $username');

      final requestBody = {
        'username': username,
        'message': message,
        'type': type.toString().split('.').last,
        'metadata': metadata ?? {},
      };

      _logger.d('Request body: $requestBody');

      final response = await _client.post(
        Uri.parse('$baseUrl/sdk/rooms/$roomId/messages'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      _logger.d('Send message response status: ${response.statusCode}');
      _logger.d('Send message response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // Handle different response formats
        if (responseData is Map<String, dynamic>) {
          // New format: {"success": true, "data": {...}}
          if (responseData.containsKey('data')) {
            return responseData;
          }
          // Old format: direct message object
          return {
            'success': true,
            'data': responseData,
          };
        } else if (responseData is List) {
          // Unexpected list format - shouldn't happen but handle gracefully
          _logger.w('Received unexpected list response for send message');
          return {
            'success': true,
            'data': responseData.isNotEmpty ? responseData.first : {},
          };
        } else {
          throw TalkLynkException(
              'Unexpected response format for send message');
        }
      } else {
        final error = jsonDecode(response.body);
        final errorMessage =
            error['message'] ?? error['error'] ?? 'Unknown error';
        throw TalkLynkException('Failed to send message: $errorMessage');
      }
    } catch (e) {
      _logger.e('Failed to send message: $e');
      _logger.e('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Send typing indicator - FIXED VERSION
  Future<void> sendTypingIndicator({
    required String roomId,
    required String username, // Add username parameter
    required bool isTyping,
  }) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/sdk/rooms/$roomId/typing'),
        headers: _headers,
        body: jsonEncode({
          'username': username, // Include username
          'is_typing': isTyping
        }),
      );
    } catch (e) {
      _logger.w('Failed to send typing indicator: $e');
    }
  }

  /// Admin: Kick participant
  Future<void> kickParticipant({
    required String roomId,
    required String participantId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(
            '$baseUrl/sdk/rooms/$roomId/participants/$participantId/kick'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw TalkLynkException(
            'Failed to kick participant: ${error['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _logger.e('Failed to kick participant: $e');
      rethrow;
    }
  }

  /// Admin: Mute all participants
  Future<void> muteAllParticipants(String roomId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/sdk/rooms/$roomId/mute-all'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw TalkLynkException(
            'Failed to mute all: ${error['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _logger.e('Failed to mute all participants: $e');
      rethrow;
    }
  }

  /// Admin: Transfer admin role
  Future<void> transferAdmin({
    required String roomId,
    required String newAdminId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/sdk/rooms/$roomId/admin'),
        headers: _headers,
        body: jsonEncode({'new_admin_id': newAdminId}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw TalkLynkException(
            'Failed to transfer admin: ${error['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _logger.e('Failed to transfer admin role: $e');
      rethrow;
    }
  }

  /// Send WebRTC offer
  Future<void> sendWebRTCOffer({
    required String roomId,
    required String targetUserId,
    required Map<String, dynamic> offer,
  }) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/sdk/webrtc/offer'),
        headers: _headers,
        body: jsonEncode({
          'room_id': roomId,
          'target_user_id': targetUserId,
          'offer': offer,
        }),
      );
    } catch (e) {
      _logger.e('Failed to send WebRTC offer: $e');
      rethrow;
    }
  }

  /// Send WebRTC answer
  Future<void> sendWebRTCAnswer({
    required String roomId,
    required String targetUserId,
    required Map<String, dynamic> answer,
  }) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/sdk/webrtc/answer'),
        headers: _headers,
        body: jsonEncode({
          'room_id': roomId,
          'target_user_id': targetUserId,
          'answer': answer,
        }),
      );
    } catch (e) {
      _logger.e('Failed to send WebRTC answer: $e');
      rethrow;
    }
  }

  /// Send WebRTC ICE candidate
  Future<void> sendWebRTCIceCandidate({
    required String roomId,
    required String targetUserId,
    required Map<String, dynamic> candidate,
  }) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/sdk/webrtc/ice-candidate'),
        headers: _headers,
        body: jsonEncode({
          'room_id': roomId,
          'target_user_id': targetUserId,
          'candidate': candidate,
        }),
      );
    } catch (e) {
      _logger.e('Failed to send WebRTC ICE candidate: $e');
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}
