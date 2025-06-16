import 'package:json_annotation/json_annotation.dart';

part 'room.g.dart';

@JsonSerializable()
class Room {
  final int id;
  @JsonKey(name: 'room_id')
  final String roomId;
  final String name;
  final RoomType type;
  @JsonKey(name: 'status', fromJson: _statusFromJson, toJson: _statusToJson)
  final RoomStatus status;
  @JsonKey(name: 'max_participants')
  final int maxParticipants;
  @JsonKey(name: 'client_id')
  final int? clientId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'started_at')
  final DateTime? startedAt;
  @JsonKey(name: 'ended_at')
  final DateTime? endedAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  Room({
    required this.id,
    required this.roomId,
    required this.name,
    required this.type,
    this.status = RoomStatus.active,
    required this.maxParticipants,
    this.clientId,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    // Handle the response from Laravel API
    try {
      // Ensure all required fields are present with proper types
      final roomData = Map<String, dynamic>.from(json);

      // Handle status field - if missing, default to 'active'
      if (!roomData.containsKey('status')) {
        roomData['status'] = 'active';
      }

      // Handle dates - ensure they're proper ISO strings or DateTime objects
      for (String dateField in [
        'created_at',
        'started_at',
        'ended_at',
        'updated_at'
      ]) {
        if (roomData[dateField] != null && roomData[dateField] is! DateTime) {
          // Keep as string for JsonSerializable to parse
          roomData[dateField] = roomData[dateField].toString();
        }
      }

      return _$RoomFromJson(roomData);
    } catch (e) {
      print('Error parsing Room JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$RoomToJson(this);

  // Helper methods for status conversion
  static RoomStatus _statusFromJson(dynamic status) {
    if (status == null) return RoomStatus.active;

    switch (status.toString().toLowerCase()) {
      case 'active':
        return RoomStatus.active;
      case 'ended':
        return RoomStatus.ended;
      case 'inactive':
        return RoomStatus.ended;
      default:
        return RoomStatus.active;
    }
  }

  static String _statusToJson(RoomStatus status) => status.name;
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
