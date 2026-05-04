class MemoryNote {
  MemoryNote({
    required this.id,
    required this.albumId,
    this.guestId,
    required this.message,
    required this.status,
    required this.isFeatured,
    required this.isHidden,
    required this.createdAt,
  });

  final String id;
  final String albumId;
  final String? guestId;
  final String message;
  final String status;
  final bool isFeatured;
  final bool isHidden;
  final DateTime createdAt;

  factory MemoryNote.fromJson(Map<String, dynamic> json) {
    return MemoryNote(
      id: json['id'],
      albumId: json['album_id'],
      guestId: json['guest_id'],
      message: json['message'],
      status: json['status'],
      isFeatured: json['is_featured'] ?? false,
      isHidden: json['is_hidden'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
