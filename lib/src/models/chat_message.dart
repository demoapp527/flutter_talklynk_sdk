// lib/src/models/chat_message.dart

import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'chat_message.g.dart';

@JsonSerializable()
class ChatMessage {
  final int id;
  @JsonKey(name: 'room_id')
  final String roomId;
  final User user;
  final String message;
  final MessageType type;
  final Map<String, dynamic>? metadata;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.user,
    required this.message,
    required this.type,
    this.metadata,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);
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
