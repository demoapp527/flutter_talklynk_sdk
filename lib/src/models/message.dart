import 'dart:convert';

import 'package:talklynk_sdk/src/models/enums.dart';

// lib/src/models/message.dart - Fixed ChatMessage.fromJson method

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String message;
  final ChatMessageType type;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.type,
    required this.timestamp,
    this.metadata = const {},
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    try {
      // Extract sender info with fallbacks
      String senderId = '0';
      String senderName = 'Unknown';

      if (json.containsKey('user') && json['user'] != null) {
        final user = json['user'];
        if (user is Map<String, dynamic>) {
          senderId = user['id']?.toString() ?? '0';
          senderName = user['name'] ?? user['username'] ?? 'Unknown';
        }
      } else {
        senderId =
            json['user_id']?.toString() ?? json['sender_id']?.toString() ?? '0';
        senderName = json['sender_name'] ?? json['username'] ?? 'Unknown';
      }

      // Extract room ID
      String roomIdValue = json['room_id']?.toString() ?? '0';

      // Handle timestamp
      DateTime timestamp;
      try {
        final timestampStr =
            json['created_at']?.toString() ?? DateTime.now().toIso8601String();
        timestamp = DateTime.parse(timestampStr);
      } catch (e) {
        timestamp = DateTime.now();
      }

      // FIXED: Handle metadata properly - it can be Map, List, or null
      Map<String, dynamic> metadata = {};
      final metadataValue = json['metadata'];

      if (metadataValue != null) {
        if (metadataValue is Map<String, dynamic>) {
          // It's already a Map - use it directly
          metadata = metadataValue;
        } else if (metadataValue is Map) {
          // It's a Map but not the right type - convert it
          metadata = Map<String, dynamic>.from(metadataValue);
        } else if (metadataValue is List) {
          // It's a List (like []) - convert to empty Map
          metadata = {};
        } else if (metadataValue is String) {
          // It's a JSON string - try to parse it
          try {
            final parsed = jsonDecode(metadataValue);
            if (parsed is Map<String, dynamic>) {
              metadata = parsed;
            } else {
              metadata = {};
            }
          } catch (e) {
            metadata = {};
          }
        } else {
          // Any other type - use empty Map
          metadata = {};
        }
      }

      return ChatMessage(
        id: json['id']?.toString() ?? '0',
        roomId: roomIdValue,
        senderId: senderId,
        senderName: senderName,
        message: json['message']?.toString() ?? '',
        type: _parseMessageType(json['type']?.toString() ?? 'text'),
        timestamp: timestamp,
        metadata: metadata,
      );
    } catch (e, stackTrace) {
      // Return a basic message to prevent crashes
      return ChatMessage(
        id: json['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        roomId: json['room_id']?.toString() ?? '0',
        senderId: json['user_id']?.toString() ?? '0',
        senderName: json['sender_name']?.toString() ?? 'Unknown',
        message: json['message']?.toString() ?? 'Failed to parse message',
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        metadata: {},
      );
    }
  }

  static ChatMessageType _parseMessageType(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return ChatMessageType.image;
      case 'file':
        return ChatMessageType.file;
      case 'audio':
        return ChatMessageType.audio;
      case 'video':
        return ChatMessageType.video;
      case 'location':
        return ChatMessageType.location;
      case 'contact':
        return ChatMessageType.contact;
      default:
        return ChatMessageType.text;
    }
  }

  bool get isFromCurrentUser => false; // Will be set by room context
  bool get hasAttachment => type != ChatMessageType.text;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': senderId,
      'sender_name': senderName,
      'message': message,
      'type': type.toString().split('.').last,
      'created_at': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}
