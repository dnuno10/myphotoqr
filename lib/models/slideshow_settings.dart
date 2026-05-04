class SlideshowSettings {
  const SlideshowSettings({
    required this.albumId,
    required this.enabled,
    required this.transitionStyle,
    required this.intervalSeconds,
    required this.showPhotos,
    required this.showVideos,
    required this.showNotes,
    required this.showGuestNames,
    required this.showCaptions,
    required this.onlyApprovedMedia,
    required this.onlyFeaturedMedia,
    required this.backgroundMusicUrl,
    required this.backgroundMusicStoragePath,
    required this.backgroundColor,
    required this.textColor,
  });

  final String albumId;
  final bool enabled;
  final String transitionStyle;
  final int intervalSeconds;
  final bool showPhotos;
  final bool showVideos;
  final bool showNotes;
  final bool showGuestNames;
  final bool showCaptions;
  final bool onlyApprovedMedia;
  final bool onlyFeaturedMedia;
  final String? backgroundMusicUrl;
  final String? backgroundMusicStoragePath;
  final String backgroundColor;
  final String textColor;

  factory SlideshowSettings.defaults(String albumId) {
    return SlideshowSettings(
      albumId: albumId,
      enabled: true,
      transitionStyle: 'fade',
      intervalSeconds: 5,
      showPhotos: true,
      showVideos: true,
      showNotes: true,
      showGuestNames: true,
      showCaptions: true,
      onlyApprovedMedia: true,
      onlyFeaturedMedia: false,
      backgroundMusicUrl: null,
      backgroundMusicStoragePath: null,
      backgroundColor: '#000000',
      textColor: '#ffffff',
    );
  }

  factory SlideshowSettings.fromJson(Map<String, dynamic> json) {
    return SlideshowSettings(
      albumId: json['album_id'] as String,
      enabled: json['enabled'] ?? true,
      transitionStyle: json['transition_style']?.toString() ?? 'fade',
      intervalSeconds: json['interval_seconds'] ?? 5,
      showPhotos: json['show_photos'] ?? true,
      showVideos: json['show_videos'] ?? true,
      showNotes: json['show_notes'] ?? true,
      showGuestNames: json['show_guest_names'] ?? true,
      showCaptions: json['show_captions'] ?? true,
      onlyApprovedMedia: json['only_approved_media'] ?? true,
      onlyFeaturedMedia: json['only_featured_media'] ?? false,
      backgroundMusicUrl: json['background_music_url'],
      backgroundMusicStoragePath: json['background_music_storage_path'],
      backgroundColor: json['background_color']?.toString() ?? '#000000',
      textColor: json['text_color']?.toString() ?? '#ffffff',
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'enabled': enabled,
      'transition_style': transitionStyle,
      'interval_seconds': intervalSeconds,
      'show_photos': showPhotos,
      'show_videos': showVideos,
      'show_notes': showNotes,
      'show_guest_names': showGuestNames,
      'show_captions': showCaptions,
      'only_approved_media': onlyApprovedMedia,
      'only_featured_media': onlyFeaturedMedia,
      'background_music_url': backgroundMusicUrl,
      'background_music_storage_path': backgroundMusicStoragePath,
      'background_color': backgroundColor,
      'text_color': textColor,
    };
  }

  SlideshowSettings copyWith({
    bool? enabled,
    String? transitionStyle,
    int? intervalSeconds,
    bool? showPhotos,
    bool? showVideos,
    bool? showNotes,
    bool? showGuestNames,
    bool? showCaptions,
    bool? onlyApprovedMedia,
    bool? onlyFeaturedMedia,
    String? backgroundMusicUrl,
    String? backgroundMusicStoragePath,
    String? backgroundColor,
    String? textColor,
  }) {
    return SlideshowSettings(
      albumId: albumId,
      enabled: enabled ?? this.enabled,
      transitionStyle: transitionStyle ?? this.transitionStyle,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      showPhotos: showPhotos ?? this.showPhotos,
      showVideos: showVideos ?? this.showVideos,
      showNotes: showNotes ?? this.showNotes,
      showGuestNames: showGuestNames ?? this.showGuestNames,
      showCaptions: showCaptions ?? this.showCaptions,
      onlyApprovedMedia: onlyApprovedMedia ?? this.onlyApprovedMedia,
      onlyFeaturedMedia: onlyFeaturedMedia ?? this.onlyFeaturedMedia,
      backgroundMusicUrl: backgroundMusicUrl ?? this.backgroundMusicUrl,
      backgroundMusicStoragePath:
          backgroundMusicStoragePath ?? this.backgroundMusicStoragePath,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
    );
  }
}
