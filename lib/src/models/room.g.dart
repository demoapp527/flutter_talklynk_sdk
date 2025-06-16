// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Room _$RoomFromJson(Map<String, dynamic> json) => Room(
      id: (json['id'] as num).toInt(),
      roomId: json['room_id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$RoomTypeEnumMap, json['type']),
      status: json['status'] == null
          ? RoomStatus.active
          : Room._statusFromJson(json['status']),
      maxParticipants: (json['max_participants'] as num).toInt(),
      clientId: (json['client_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      settings: json['settings'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$RoomToJson(Room instance) => <String, dynamic>{
      'id': instance.id,
      'room_id': instance.roomId,
      'name': instance.name,
      'type': _$RoomTypeEnumMap[instance.type]!,
      'status': Room._statusToJson(instance.status),
      'max_participants': instance.maxParticipants,
      'client_id': instance.clientId,
      'created_at': instance.createdAt.toIso8601String(),
      'started_at': instance.startedAt?.toIso8601String(),
      'ended_at': instance.endedAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'settings': instance.settings,
    };

const _$RoomTypeEnumMap = {
  RoomType.video: 'video',
  RoomType.audio: 'audio',
  RoomType.chat: 'chat',
};
