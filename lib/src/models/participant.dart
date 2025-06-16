import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'participant.g.dart';

@JsonSerializable()
class Participant {
  final int id;
  final User user;
  @JsonKey(name: 'room_id')
  final dynamic roomId; // Can be String or int
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;
  @JsonKey(name: 'left_at')
  final DateTime? leftAt;
  @JsonKey(name: 'status', fromJson: _statusFromJson, toJson: _statusToJson)
  final ParticipantStatus status;
  @JsonKey(name: 'role')
  final String? role;

  Participant({
    required this.id,
    required this.user,
    required this.roomId,
    required this.joinedAt,
    this.leftAt,
    this.status = ParticipantStatus.active,
    this.role,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    try {
      return _$ParticipantFromJson(json);
    } catch (e) {
      print('Error parsing Participant JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$ParticipantToJson(this);

  // Helper getter for room ID as string
  String get roomIdString => roomId.toString();

  // Helper methods for status conversion
  static ParticipantStatus _statusFromJson(dynamic status) {
    if (status == null) return ParticipantStatus.active;

    switch (status.toString().toLowerCase()) {
      case 'active':
        return ParticipantStatus.active;
      case 'left':
        return ParticipantStatus.left;
      case 'kicked':
        return ParticipantStatus.kicked;
      case 'banned':
        return ParticipantStatus.banned;
      default:
        return ParticipantStatus.active;
    }
  }

  static String _statusToJson(ParticipantStatus status) => status.name;
}

enum ParticipantStatus {
  @JsonValue('active')
  active,
  @JsonValue('left')
  left,
  @JsonValue('kicked')
  kicked,
  @JsonValue('banned')
  banned,
}
