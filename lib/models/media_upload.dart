class MediaUpload {
  MediaUpload({
    required this.id,
    required this.albumId,
    this.guestId,
    required this.type,
    required this.fileUrl,
    this.thumbnailUrl,
    this.caption,
    required this.status,
    required this.isFeatured,
    required this.isHidden,
    required this.createdAt,
  });

  final String id;
  final String albumId;
  final String? guestId;
  final String type;
  final String fileUrl;
  final String? thumbnailUrl;
  final String? caption;
  final String status;
  final bool isFeatured;
  final bool isHidden;
  final DateTime createdAt;

  factory MediaUpload.fromJson(Map<String, dynamic> json) {
    return MediaUpload(
      id: json['id'],
      albumId: json['album_id'],
      guestId: json['guest_id'],
      type: json['type'],
      fileUrl: json['file_url'],
      thumbnailUrl: json['thumbnail_url'],
      caption: json['caption'],
      status: json['status'],
      isFeatured: json['is_featured'] ?? false,
      isHidden: json['is_hidden'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
