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
  // Add optional settings field that might be in the response
  final Map<String, dynamic>? settings;

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
    this.settings,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    try {
      // Clean and prepare the JSON data
      final roomData = Map<String, dynamic>.from(json);

      // Ensure required integer fields are properly typed
      if (roomData['id'] != null) {
        roomData['id'] = _ensureInt(roomData['id']);
      }
      if (roomData['max_participants'] != null) {
        roomData['max_participants'] = _ensureInt(roomData['max_participants']);
      }
      if (roomData['client_id'] != null) {
        roomData['client_id'] = _ensureInt(roomData['client_id']);
      }

      // Handle status field - if missing, default to 'active'
      if (!roomData.containsKey('status')) {
        roomData['status'] = 'active';
      }

      // Handle RoomType parsing
      if (roomData['type'] != null) {
        final typeStr = roomData['type'].toString().toLowerCase();
        roomData['type'] = typeStr;
      }

      // Handle dates - ensure they're proper ISO strings
      for (String dateField in [
        'created_at',
        'started_at',
        'ended_at',
        'updated_at'
      ]) {
        if (roomData[dateField] != null && roomData[dateField] is! DateTime) {
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

  // Helper method to ensure int conversion
  static int _ensureInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

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

  @override
  String toString() {
    return 'Room{id: $id, roomId: $roomId, name: $name, type: $type, status: $status}';
  }
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
