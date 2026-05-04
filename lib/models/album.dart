class Album {
  Album({
    required this.id,
    required this.userId,
    required this.title,
    required this.slug,
    this.description,
    required this.eventType,
    this.eventTypeLabel,
    this.eventDate,
    this.eventLocation,
    this.themeEmoji,
    required this.themeColor,
    required this.themeBackgroundColor,
    this.themeColorMode,
    this.themeColorGradient,
    this.themeBackgroundMode,
    this.themeBackgroundGradient,
    this.coverImageUrl,
    this.coverImageStoragePath,
    this.bannerImageUrl,
    this.bannerImageStoragePath,
    required this.status,
    required this.visibility,
    required this.guestAccessCodeEnabled,
    this.guestAccessCodeHint,
    required this.uploadEnabled,
    required this.galleryEnabled,
    required this.totalUploads,
    required this.totalPhotos,
    required this.totalVideos,
    required this.totalAudios,
    required this.totalNotes,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String slug;
  final String? description;
  final String eventType;
  final String? eventTypeLabel;
  final DateTime? eventDate;
  final String? eventLocation;
  final String? themeEmoji;
  final String themeColor;
  final String themeBackgroundColor;
  final String? themeColorMode;
  final Map<String, dynamic>? themeColorGradient;
  final String? themeBackgroundMode;
  final Map<String, dynamic>? themeBackgroundGradient;
  final String? coverImageUrl;
  final String? coverImageStoragePath;
  final String? bannerImageUrl;
  final String? bannerImageStoragePath;
  final String status;
  final String visibility;
  final bool guestAccessCodeEnabled;
  final String? guestAccessCodeHint;
  final bool uploadEnabled;
  final bool galleryEnabled;
  final int totalUploads;
  final int totalPhotos;
  final int totalVideos;
  final int totalAudios;
  final int totalNotes;
  final DateTime createdAt;

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      slug: json['slug'],
      description: json['description'],
      eventType: json['event_type'] ?? 'other',
      eventTypeLabel: json['event_type_label'],
      eventDate: json['event_date'] == null
          ? null
          : DateTime.parse(json['event_date']),
      eventLocation: json['event_location'],
      themeEmoji: json['theme_emoji'],
      themeColor: json['theme_color'] ?? '#111827',
      themeBackgroundColor: json['theme_background_color'] ?? '#ffffff',
      themeColorMode: json['theme_color_mode'],
      themeColorGradient: (json['theme_color_gradient'] as Map?)?.cast(),
      themeBackgroundMode: json['theme_background_mode'],
      themeBackgroundGradient:
          (json['theme_background_gradient'] as Map?)?.cast(),
      coverImageUrl: json['cover_image_url'],
      coverImageStoragePath: json['cover_image_storage_path'],
      bannerImageUrl: json['banner_image_url'],
      bannerImageStoragePath: json['banner_image_storage_path'],
      status: json['status'] ?? 'draft',
      visibility: json['visibility'] ?? 'public',
      guestAccessCodeEnabled: json['guest_access_code_enabled'] ?? false,
      guestAccessCodeHint: json['guest_access_code_hint'],
      uploadEnabled: json['upload_enabled'] ?? true,
      galleryEnabled: json['gallery_enabled'] ?? true,
      totalUploads: json['total_uploads'] ?? 0,
      totalPhotos: json['total_photos'] ?? 0,
      totalVideos: json['total_videos'] ?? 0,
      totalAudios: json['total_audios'] ?? 0,
      totalNotes: json['total_notes'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
