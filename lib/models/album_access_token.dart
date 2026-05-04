class AlbumAccessToken {
  const AlbumAccessToken({
    required this.id,
    required this.albumId,
    required this.token,
    required this.type,
    required this.isActive,
    required this.expiresAt,
    required this.lastUsedAt,
    required this.createdAt,
  });

  final String id;
  final String albumId;
  final String token;
  final String type;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  factory AlbumAccessToken.fromJson(Map<String, dynamic> json) {
    return AlbumAccessToken(
      id: json['id'] as String,
      albumId: json['album_id'] as String,
      token: json['token'] as String,
      type: json['type']?.toString() ?? '',
      isActive: json['is_active'] ?? true,
      expiresAt:
          json['expires_at'] == null ? null : DateTime.parse(json['expires_at']),
      lastUsedAt: json['last_used_at'] == null
          ? null
          : DateTime.parse(json['last_used_at']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'is_active': isActive,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  AlbumAccessToken copyWith({
    bool? isActive,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
  }) {
    return AlbumAccessToken(
      id: id,
      albumId: albumId,
      token: token,
      type: type,
      isActive: isActive ?? this.isActive,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
    );
  }
}

