// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'participant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Participant _$ParticipantFromJson(Map<String, dynamic> json) => Participant(
      id: (json['id'] as num).toInt(),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      roomId: json['room_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      leftAt: json['left_at'] == null
          ? null
          : DateTime.parse(json['left_at'] as String),
      status: $enumDecode(_$ParticipantStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$ParticipantToJson(Participant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'room_id': instance.roomId,
      'joined_at': instance.joinedAt.toIso8601String(),
      'left_at': instance.leftAt?.toIso8601String(),
      'status': _$ParticipantStatusEnumMap[instance.status]!,
    };

const _$ParticipantStatusEnumMap = {
  ParticipantStatus.active: 'active',
  ParticipantStatus.left: 'left',
  ParticipantStatus.kicked: 'kicked',
};
