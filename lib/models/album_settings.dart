class AlbumSettings {
  const AlbumSettings({
    required this.albumId,
    required this.allowPhotos,
    required this.allowVideos,
    required this.allowAudio,
    required this.allowNotes,
    required this.requireGuestName,
    required this.requireGuestEmail,
    required this.moderationEnabled,
    required this.autoApproveUploads,
    required this.autoApproveNotes,
    required this.allowGuestViewGallery,
    required this.allowGuestDownloads,
    required this.maxFileSizeMb,
    required this.maxVideoDurationSeconds,
    required this.maxAudioDurationSeconds,
    required this.showGuestNames,
    required this.showUploadDate,
    required this.enableLiveGallery,
    required this.enableLiveSlideshow,
  });

  final String albumId;

  final bool allowPhotos;
  final bool allowVideos;
  final bool allowAudio;
  final bool allowNotes;

  final bool requireGuestName;
  final bool requireGuestEmail;

  final bool moderationEnabled;
  final bool autoApproveUploads;
  final bool autoApproveNotes;

  final bool allowGuestViewGallery;
  final bool allowGuestDownloads;

  final int maxFileSizeMb;
  final int? maxVideoDurationSeconds;
  final int? maxAudioDurationSeconds;

  final bool showGuestNames;
  final bool showUploadDate;

  final bool enableLiveGallery;
  final bool enableLiveSlideshow;

  factory AlbumSettings.defaults(String albumId) {
    return AlbumSettings(
      albumId: albumId,
      allowPhotos: true,
      allowVideos: true,
      allowAudio: true,
      allowNotes: true,
      requireGuestName: false,
      requireGuestEmail: false,
      moderationEnabled: false,
      autoApproveUploads: true,
      autoApproveNotes: true,
      allowGuestViewGallery: true,
      allowGuestDownloads: false,
      maxFileSizeMb: 500,
      maxVideoDurationSeconds: null,
      maxAudioDurationSeconds: null,
      showGuestNames: true,
      showUploadDate: true,
      enableLiveGallery: true,
      enableLiveSlideshow: true,
    );
  }

  factory AlbumSettings.fromJson(Map<String, dynamic> json) {
    return AlbumSettings(
      albumId: json['album_id'] as String,
      allowPhotos: json['allow_photos'] ?? true,
      allowVideos: json['allow_videos'] ?? true,
      allowAudio: json['allow_audio'] ?? true,
      allowNotes: json['allow_notes'] ?? true,
      requireGuestName: json['require_guest_name'] ?? false,
      requireGuestEmail: json['require_guest_email'] ?? false,
      moderationEnabled: json['moderation_enabled'] ?? false,
      autoApproveUploads: json['auto_approve_uploads'] ?? true,
      autoApproveNotes: json['auto_approve_notes'] ?? true,
      allowGuestViewGallery: json['allow_guest_view_gallery'] ?? true,
      allowGuestDownloads: json['allow_guest_downloads'] ?? false,
      maxFileSizeMb: json['max_file_size_mb'] ?? 500,
      maxVideoDurationSeconds: json['max_video_duration_seconds'],
      maxAudioDurationSeconds: json['max_audio_duration_seconds'],
      showGuestNames: json['show_guest_names'] ?? true,
      showUploadDate: json['show_upload_date'] ?? true,
      enableLiveGallery: json['enable_live_gallery'] ?? true,
      enableLiveSlideshow: json['enable_live_slideshow'] ?? true,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'allow_photos': allowPhotos,
      'allow_videos': allowVideos,
      'allow_audio': allowAudio,
      'allow_notes': allowNotes,
      'require_guest_name': requireGuestName,
      'require_guest_email': requireGuestEmail,
      'moderation_enabled': moderationEnabled,
      'auto_approve_uploads': autoApproveUploads,
      'auto_approve_notes': autoApproveNotes,
      'allow_guest_view_gallery': allowGuestViewGallery,
      'allow_guest_downloads': allowGuestDownloads,
      'max_file_size_mb': maxFileSizeMb,
      'max_video_duration_seconds': maxVideoDurationSeconds,
      'max_audio_duration_seconds': maxAudioDurationSeconds,
      'show_guest_names': showGuestNames,
      'show_upload_date': showUploadDate,
      'enable_live_gallery': enableLiveGallery,
      'enable_live_slideshow': enableLiveSlideshow,
    };
  }

  AlbumSettings copyWith({
    bool? allowPhotos,
    bool? allowVideos,
    bool? allowAudio,
    bool? allowNotes,
    bool? requireGuestName,
    bool? requireGuestEmail,
    bool? moderationEnabled,
    bool? autoApproveUploads,
    bool? autoApproveNotes,
    bool? allowGuestViewGallery,
    bool? allowGuestDownloads,
    int? maxFileSizeMb,
    int? maxVideoDurationSeconds,
    int? maxAudioDurationSeconds,
    bool clearMaxVideoDurationSeconds = false,
    bool clearMaxAudioDurationSeconds = false,
    bool? showGuestNames,
    bool? showUploadDate,
    bool? enableLiveGallery,
    bool? enableLiveSlideshow,
  }) {
    return AlbumSettings(
      albumId: albumId,
      allowPhotos: allowPhotos ?? this.allowPhotos,
      allowVideos: allowVideos ?? this.allowVideos,
      allowAudio: allowAudio ?? this.allowAudio,
      allowNotes: allowNotes ?? this.allowNotes,
      requireGuestName: requireGuestName ?? this.requireGuestName,
      requireGuestEmail: requireGuestEmail ?? this.requireGuestEmail,
      moderationEnabled: moderationEnabled ?? this.moderationEnabled,
      autoApproveUploads: autoApproveUploads ?? this.autoApproveUploads,
      autoApproveNotes: autoApproveNotes ?? this.autoApproveNotes,
      allowGuestViewGallery:
          allowGuestViewGallery ?? this.allowGuestViewGallery,
      allowGuestDownloads: allowGuestDownloads ?? this.allowGuestDownloads,
      maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
      maxVideoDurationSeconds: clearMaxVideoDurationSeconds
          ? null
          : (maxVideoDurationSeconds ?? this.maxVideoDurationSeconds),
      maxAudioDurationSeconds: clearMaxAudioDurationSeconds
          ? null
          : (maxAudioDurationSeconds ?? this.maxAudioDurationSeconds),
      showGuestNames: showGuestNames ?? this.showGuestNames,
      showUploadDate: showUploadDate ?? this.showUploadDate,
      enableLiveGallery: enableLiveGallery ?? this.enableLiveGallery,
      enableLiveSlideshow: enableLiveSlideshow ?? this.enableLiveSlideshow,
    );
  }
}
