// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
      id: (json['id'] as num).toInt(),
      roomId: json['room_id'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      message: json['message'] as String,
      type: $enumDecode(_$MessageTypeEnumMap, json['type']),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'room_id': instance.roomId,
      'user': instance.user,
      'message': instance.message,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'metadata': instance.metadata,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.file: 'file',
  MessageType.audio: 'audio',
  MessageType.video: 'video',
  MessageType.location: 'location',
  MessageType.contact: 'contact',
};
