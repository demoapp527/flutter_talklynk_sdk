class User {
  final int id;
  final String? name;
  final String? email;
  final String? externalId;
  final String? avatarUrl;
  final Map<String, dynamic>? metadata;
  final String? status;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    this.name,
    this.email,
    this.externalId,
    this.avatarUrl,
    this.metadata,
    this.status,
    this.lastSeenAt,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String?,
      email: json['email'] as String?,
      externalId: json['external_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      status: json['status'] as String?,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'external_id': externalId,
      'avatar_url': avatarUrl,
      'metadata': metadata,
      'status': status,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? externalId,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
    String? status,
    DateTime? lastSeenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      externalId: externalId ?? this.externalId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName => name ?? email ?? 'User $id';

  bool get isOnline {
    if (lastSeenAt == null) return false;
    return DateTime.now().difference(lastSeenAt!).inMinutes <= 5;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'User{id: $id, name: $name, email: $email, externalId: $externalId}';
  }
}
