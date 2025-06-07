// lib/src/models/participant.dart

import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'participant.g.dart';

@JsonSerializable()
class Participant {
  final int id;
  final User user;
  @JsonKey(name: 'room_id')
  final String roomId;
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;
  @JsonKey(name: 'left_at')
  final DateTime? leftAt;
  final ParticipantStatus status;

  Participant({
    required this.id,
    required this.user,
    required this.roomId,
    required this.joinedAt,
    this.leftAt,
    required this.status,
  });

  factory Participant.fromJson(Map<String, dynamic> json) =>
      _$ParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$ParticipantToJson(this);
}

enum ParticipantStatus {
  @JsonValue('active')
  active,
  @JsonValue('left')
  left,
  @JsonValue('kicked')
  kicked,
}
