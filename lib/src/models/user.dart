import 'package:talklynk_sdk/src/models/enums.dart';

class TalkLynkUser {
  final String id;
  final String username;
  final String displayName;
  final UserRole role;
  final DateTime joinedAt;
  final bool isOnline;
  final Map<String, dynamic> metadata;

  TalkLynkUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.isOnline = true,
    this.metadata = const {},
  });

  factory TalkLynkUser.fromJson(Map<String, dynamic> json) {
    return TalkLynkUser(
      id: json['id'].toString(),
      username: json['username'] ?? json['name'] ?? 'Unknown',
      displayName:
          json['display_name'] ?? json['name'] ?? json['username'] ?? 'Unknown',
      role: _parseUserRole(json['role'] ?? 'participant'),
      joinedAt: DateTime.tryParse(json['joined_at'] ?? '') ?? DateTime.now(),
      isOnline: json['is_online'] ?? true,
      metadata: json['metadata'] ?? {},
    );
  }

  static UserRole _parseUserRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      default:
        return UserRole.participant;
    }
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isModerator => role == UserRole.moderator;
  bool get canKick => isAdmin || isModerator;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'role': role.toString().split('.').last,
      'joined_at': joinedAt.toIso8601String(),
      'is_online': isOnline,
      'metadata': metadata,
    };
  }
}
