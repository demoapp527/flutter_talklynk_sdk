// lib/src/models/participant.dart

import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'participant.g.dart';

@JsonSerializable()
class Participant {
  final int id;
  @JsonKey(name: 'room_id')
  final int roomId;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;
  @JsonKey(name: 'left_at')
  final DateTime? leftAt;
  final String status;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  // User relationship
  final User? user;

  const Participant({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.joinedAt,
    this.leftAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    try {
      // Handle the response from Laravel API
      final participantData = Map<String, dynamic>.from(json);

      // Ensure dates are properly formatted
      for (String dateField in [
        'joined_at',
        'left_at',
        'created_at',
        'updated_at'
      ]) {
        if (participantData[dateField] != null &&
            participantData[dateField] is! DateTime) {
          participantData[dateField] = participantData[dateField].toString();
        }
      }

      // Handle user relationship if present
      if (participantData['user'] != null) {
        participantData['user'] =
            User.fromJson(participantData['user'] as Map<String, dynamic>);
      }

      return _$ParticipantFromJson(participantData);
    } catch (e) {
      print('Error parsing Participant JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$ParticipantToJson(this);

  bool get isActive => status.toLowerCase() == 'active';
  bool get hasLeft => leftAt != null;

  String get displayName => user?.displayName ?? 'User $userId';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Participant{id: $id, userId: $userId, status: $status, user: ${user?.name}}';
  }
}
