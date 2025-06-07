// lib/src/models/room.dart

import 'package:json_annotation/json_annotation.dart';

part 'room.g.dart';

@JsonSerializable()
class Room {
  final int id;
  @JsonKey(name: 'room_id')
  final String roomId;
  final String name;
  final RoomType type;
  final RoomStatus status;
  @JsonKey(name: 'max_participants')
  final int maxParticipants;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'started_at')
  final DateTime? startedAt;
  @JsonKey(name: 'ended_at')
  final DateTime? endedAt;

  Room({
    required this.id,
    required this.roomId,
    required this.name,
    required this.type,
    required this.status,
    required this.maxParticipants,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
  Map<String, dynamic> toJson() => _$RoomToJson(this);
}

enum RoomType {
  @JsonValue('video')
  video,
  @JsonValue('audio')
  audio,
  @JsonValue('chat')
  chat,
}

enum RoomStatus {
  @JsonValue('active')
  active,
  @JsonValue('ended')
  ended,
}
