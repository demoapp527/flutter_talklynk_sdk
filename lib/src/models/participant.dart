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
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  // User relationship
  final User? user;

  Participant({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.joinedAt,
    this.leftAt,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.user,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    try {
      // Clean and prepare the JSON data
      final participantData = Map<String, dynamic>.from(json);

      // Ensure required integer fields are properly typed
      if (participantData['id'] != null) {
        participantData['id'] = _ensureInt(participantData['id']);
      }
      if (participantData['room_id'] != null) {
        participantData['room_id'] = _ensureInt(participantData['room_id']);
      }
      if (participantData['user_id'] != null) {
        participantData['user_id'] = _ensureInt(participantData['user_id']);
      }

      // Handle status field
      if (!participantData.containsKey('status')) {
        participantData['status'] = 'active';
      }

      // Handle dates
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

      // Handle user relationship
      if (participantData['user'] != null &&
          participantData['user'] is Map<String, dynamic>) {
        try {
          participantData['user'] =
              User.fromJson(participantData['user'] as Map<String, dynamic>);
        } catch (e) {
          print('Error parsing participant user: $e');
          participantData['user'] = null;
        }
      }

      return _$ParticipantFromJson(participantData);
    } catch (e) {
      print('Error parsing Participant JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$ParticipantToJson(this);

  // Helper method to ensure int conversion
  static int _ensureInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Getters for convenience
  String get displayName => user?.displayName ?? 'User $userId';
  bool get isActive => status.toLowerCase() == 'active';

  @override
  String toString() {
    return 'Participant{id: $id, userId: $userId, status: $status, user: ${user?.name}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
