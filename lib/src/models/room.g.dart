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
      status: $enumDecode(_$RoomStatusEnumMap, json['status']),
      maxParticipants: (json['max_participants'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
    );

Map<String, dynamic> _$RoomToJson(Room instance) => <String, dynamic>{
      'id': instance.id,
      'room_id': instance.roomId,
      'name': instance.name,
      'type': _$RoomTypeEnumMap[instance.type]!,
      'status': _$RoomStatusEnumMap[instance.status]!,
      'max_participants': instance.maxParticipants,
      'created_at': instance.createdAt.toIso8601String(),
      'started_at': instance.startedAt?.toIso8601String(),
      'ended_at': instance.endedAt?.toIso8601String(),
    };

const _$RoomTypeEnumMap = {
  RoomType.video: 'video',
  RoomType.audio: 'audio',
  RoomType.chat: 'chat',
};

const _$RoomStatusEnumMap = {
  RoomStatus.active: 'active',
  RoomStatus.ended: 'ended',
};
