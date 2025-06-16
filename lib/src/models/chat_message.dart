import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'chat_message.g.dart';

@JsonSerializable()
class ChatMessage {
  final int id;
  @JsonKey(name: 'room_id')
  final dynamic roomId; // Can be String or int
  final User user;
  final String message;
  final MessageType type;
  final Map<String, dynamic>? metadata;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.user,
    required this.message,
    required this.type,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    try {
      return _$ChatMessageFromJson(json);
    } catch (e) {
      print('Error parsing ChatMessage JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  // Helper getter for room ID as string
  String get roomIdString => roomId.toString();
}

enum MessageType {
  @JsonValue('text')
  text,
  @JsonValue('image')
  image,
  @JsonValue('file')
  file,
  @JsonValue('audio')
  audio,
  @JsonValue('video')
  video,
  @JsonValue('location')
  location,
  @JsonValue('contact')
  contact,
}
