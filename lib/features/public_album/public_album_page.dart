import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/album.dart';
import '../../models/album_settings.dart';
import '../../services/album_service.dart';
import '../../services/album_settings_service.dart';
import '../../services/album_export_service.dart';
import '../../services/guest_session_service.dart';
import '../../services/upload_service.dart';
import '../../shared/ui/app_snackbars.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/ui/event_theme.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/logo_mark.dart';
import '../../shared/ui/color_fill.dart';
import '../../shared/widgets/saas_surface.dart';
import '../gallery/gallery_grid.dart';

class PublicAlbumPage extends StatefulWidget {
  const PublicAlbumPage({super.key, required this.slug});

  final String slug;

  @override
  State<PublicAlbumPage> createState() => _PublicAlbumPageState();
}

class _PublicAlbumPageState extends State<PublicAlbumPage> {
  final _service = AlbumService();
  final _albumSettingsService = AlbumSettingsService();
  final _exportService = AlbumExportService();
  final _guestSessionService = GuestSessionService();
  final _uploadService = UploadService();
  late Future<_PublicAlbumBundle> _future;
  GalleryFilter _filter = GalleryFilter.photos;
  bool _exporting = false;
  bool _unlocking = false;
  bool _accessGranted = false;
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _loadAlbum();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<_PublicAlbumBundle> _loadAlbum() async {
    final album = await _service.getAlbumBySlug(widget.slug);
    final settings =
        await _albumSettingsService.get(album.id) ??
        AlbumSettings.defaults(album.id);

    final requiresCode =
        album.guestAccessCodeEnabled || album.visibility == 'code_protected';
    if (requiresCode) {
      await _guestSessionService.ensureSignedIn();
      _accessGranted = await _uploadService.hasAlbumAccess(albumId: album.id);
    } else {
      _accessGranted = true;
    }

    return _PublicAlbumBundle(album: album, settings: settings);
  }

  Future<void> _unlockAlbum(Album album) async {
    if (_unlocking) return;

    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      context.showTopRightSnackBar(
        'Please enter the access code.',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _unlocking = true);
    try {
      await _guestSessionService.ensureSignedIn();
      final ok = await _uploadService.verifyAccessCode(
        albumId: album.id,
        code: code,
      );
      if (!ok) throw Exception('Incorrect access code.');

      if (!mounted) return;
      setState(() => _accessGranted = true);
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<String?> _askForAccessCode() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Access code required'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter access code'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.of(context).pop(ctrl.text.trim()),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(ctrl.text.trim()),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    final value = (result ?? '').trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _exportAlbum(Album album, AlbumSettings settings) async {
    if (_exporting) return;
    if (!settings.allowGuestDownloads) return;

    setState(() => _exporting = true);

    try {
      String? guestCode;
      if (album.guestAccessCodeEnabled) {
        guestCode = await _askForAccessCode();
        if (guestCode == null) return;

        final ok = await _uploadService.verifyAccessCode(
          albumId: album.id,
          code: guestCode,
        );
        if (!ok) throw Exception('Incorrect access code.');
      }

      final uri = await _exportService.exportAlbumZip(
        albumId: album.id,
        guestCode: guestCode,
      );

      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not export album: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  bool _isFilterAllowed(GalleryFilter filter, AlbumSettings settings) {
    return switch (filter) {
      GalleryFilter.photos => settings.allowPhotos,
      GalleryFilter.videos => settings.allowVideos,
      GalleryFilter.audios => settings.allowAudio,
      GalleryFilter.notes => settings.allowNotes,
      GalleryFilter.all => true,
    };
  }

  GalleryFilter _fallbackFilter(AlbumSettings settings) {
    if (settings.allowPhotos) return GalleryFilter.photos;
    if (settings.allowVideos) return GalleryFilter.videos;
    if (settings.allowAudio) return GalleryFilter.audios;
    if (settings.allowNotes) return GalleryFilter.notes;
    return GalleryFilter.photos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_PublicAlbumBundle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _EventEmojiBackground(
              eventType: 'other',
              child: LoadingView(),
            );
          }

          if (snapshot.hasError) {
            return _EventEmojiBackground(
              eventType: 'other',
              child: ErrorView(message: snapshot.error.toString()),
            );
          }

          final bundle = snapshot.data!;
          final album = bundle.album;
          final settings = bundle.settings;
          final eventCopy = eventThemeCopy(album.eventType);
          final backgroundFill = ColorFillValue.fromAlbumFields(
            solidHexFallback: album.themeBackgroundColor,
            mode: album.themeBackgroundMode,
            gradient: album.themeBackgroundGradient,
          );
          final effectiveFilter = (!_isFilterAllowed(_filter, settings))
              ? _fallbackFilter(settings)
              : _filter;

          return _EventEmojiBackground(
            eventType: album.eventType,
            backgroundFill: backgroundFill,
            child:
                (album.guestAccessCodeEnabled ||
                        album.visibility == 'code_protected') &&
                    !_accessGranted
                ? _LockedAlbumView(
                    album: album,
                    controller: _codeCtrl,
                    loading: _unlocking,
                    onUnlock: () => _unlockAlbum(album),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: SaasSurface(
                              padding: const EdgeInsets.all(20),
                              color: Colors.white.withOpacity(0.92),
                              borderColor: Colors.white.withOpacity(0.65),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AlbumHeroImages(album: album),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isCompact =
                                          constraints.maxWidth < 720;

                                      if (isCompact) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const LogoMark(size: 44),
                                                const Spacer(),
                                                if (settings
                                                    .allowGuestDownloads)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 10,
                                                        ),
                                                    child: SizedBox(
                                                      width: 46,
                                                      height: 46,
                                                      child: OutlinedButton(
                                                        onPressed: _exporting
                                                            ? null
                                                            : () =>
                                                                  _exportAlbum(
                                                                    album,
                                                                    settings,
                                                                  ),
                                                        child: _exporting
                                                            ? const SizedBox(
                                                                width: 18,
                                                                height: 18,
                                                                child:
                                                                    CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2.2,
                                                                    ),
                                                              )
                                                            : const Icon(
                                                                Icons
                                                                    .download_outlined,
                                                                size: 20,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                SizedBox(
                                                  width: 118,
                                                  height: 46,
                                                  child: _PrimaryUploadButton(
                                                    compact: true,
                                                    onPressed: () {
                                                      context.go(
                                                        '/a/${album.slug}/upload',
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 18),
                                            _AlbumPublicHeaderText(
                                              eventCopy: eventCopy,
                                              album: album,
                                            ),
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          const LogoMark(size: 44),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: _AlbumPublicHeaderText(
                                              eventCopy: eventCopy,
                                              album: album,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          if (settings.allowGuestDownloads) ...[
                                            SizedBox(
                                              width: 160,
                                              height: 46,
                                              child: OutlinedButton.icon(
                                                onPressed: _exporting
                                                    ? null
                                                    : () => _exportAlbum(
                                                        album,
                                                        settings,
                                                      ),
                                                icon: _exporting
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2.2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.download_outlined,
                                                        size: 18,
                                                      ),
                                                label: Text(
                                                  _exporting
                                                      ? 'Preparing…'
                                                      : 'Download',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                          SizedBox(
                                            width: 178,
                                            height: 46,
                                            child: _PrimaryUploadButton(
                                              onPressed: () {
                                                context.go(
                                                  '/a/${album.slug}/upload',
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: settings.allowGuestViewGallery
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  14,
                                ),
                                child: _PublicGalleryTabs(
                                  selected: effectiveFilter,
                                  showPhotos: settings.allowPhotos,
                                  showVideos: settings.allowVideos,
                                  showAudios: settings.allowAudio,
                                  showNotes: settings.allowNotes,
                                  onChanged: (filter) =>
                                      setState(() => _filter = filter),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: settings.allowGuestViewGallery
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE5E5EA),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x05000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: GalleryGrid(
                                    albumId: album.id,
                                    filter: effectiveFilter,
                                    showGuestNames: settings.showGuestNames,
                                  ),
                                )
                              : Center(
                                  child: SaasSurface(
                                    constraints: const BoxConstraints(
                                      maxWidth: 520,
                                    ),
                                    padding: const EdgeInsets.all(18),
                                    color: Colors.white.withOpacity(0.92),
                                    borderColor: Colors.white.withOpacity(0.65),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Gallery is disabled for guests.',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 46,
                                          child: FilledButton.icon(
                                            onPressed: () => context.go(
                                              '/a/${album.slug}/upload',
                                            ),
                                            icon: const Icon(
                                              Icons.cloud_upload_outlined,
                                              size: 18,
                                            ),
                                            label: const Text('Go to upload'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _LockedAlbumView extends StatelessWidget {
  const _LockedAlbumView({
    required this.album,
    required this.controller,
    required this.loading,
    required this.onUnlock,
  });

  final Album album;
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final hint = (album.guestAccessCodeHint ?? '').trim();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SaasSurface(
            padding: const EdgeInsets.all(22),
            color: Colors.white.withOpacity(0.92),
            borderColor: Colors.white.withOpacity(0.65),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoMark(size: 52),
                const SizedBox(height: 16),
                const Text(
                  'Protected album',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                    color: Color(0xFF15151A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hint.isEmpty
                      ? 'Enter the access code to view the album.'
                      : hint,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  enabled: !loading,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!loading) onUnlock();
                  },
                  cursorColor: Colors.black,
                  decoration: const InputDecoration(labelText: 'Access code'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: loading ? null : onUnlock,
                    child: Text(loading ? 'Verifying...' : 'Enter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicAlbumBundle {
  const _PublicAlbumBundle({required this.album, required this.settings});

  final Album album;
  final AlbumSettings settings;
}

class _AlbumHeroImages extends StatelessWidget {
  const _AlbumHeroImages({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = (album.bannerImageUrl ?? '').trim();
    final coverUrl = (album.coverImageUrl ?? '').trim();
    final hasBanner = bannerUrl.isNotEmpty;
    final hasCover = coverUrl.isNotEmpty;

    if (!hasBanner && !hasCover) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bannerHeight = width < 520
            ? 140.0
            : width < 900
            ? 180.0
            : 220.0;
        final coverSize = width < 520 ? 72.0 : 84.0;

        Widget imageBox({
          required String url,
          required double width,
          required double height,
          BorderRadius? borderRadius,
        }) {
          return ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.circular(14),
            child: SizedBox(
              width: width,
              height: height,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  return Container(
                    color: const Color(0xFFF1F2F5),
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF1F2F5),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }

        if (hasBanner) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    imageBox(
                      url: bannerUrl,
                      width: double.infinity,
                      height: bannerHeight,
                    ),
                    if (hasCover)
                      Positioned(
                        left: 14,
                        bottom: -coverSize / 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 18,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: imageBox(
                            url: coverUrl,
                            width: coverSize,
                            height: coverSize,
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                  ],
                ),
                if (hasCover) SizedBox(height: coverSize / 2),
              ],
            ),
          );
        }

        // Cover only
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: imageBox(
                url: coverUrl,
                width: coverSize,
                height: coverSize,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlbumPublicHeaderText extends StatelessWidget {
  const _AlbumPublicHeaderText({required this.eventCopy, required this.album});

  final dynamic eventCopy;
  final Album album;

  @override
  Widget build(BuildContext context) {
    final description = album.description?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eventCopy.guestTitle.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.55,
            color: Colors.black.withOpacity(0.46),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(album.themeEmoji ?? '').trim().isNotEmpty ? album.themeEmoji!.trim() : _emojiForEvent(album.eventType)} ${album.title}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 30,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: Color(0xFF15151A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description == null || description.isEmpty
              ? eventCopy.guestDescription
              : description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.black.withOpacity(0.52),
            fontSize: 14.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PrimaryUploadButton extends StatelessWidget {
  const _PrimaryUploadButton({required this.onPressed, this.compact = false});

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      clipBehavior: Clip.antiAlias,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
      label: const Text('Upload'),
    );
  }
}

class _PublicGalleryTabs extends StatelessWidget {
  const _PublicGalleryTabs({
    required this.selected,
    required this.onChanged,
    required this.showPhotos,
    required this.showVideos,
    required this.showAudios,
    required this.showNotes,
  });

  final GalleryFilter selected;
  final ValueChanged<GalleryFilter> onChanged;
  final bool showPhotos;
  final bool showVideos;
  final bool showAudios;
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    final specs = <({GalleryFilter filter, IconData icon, String label})>[
      if (showPhotos)
        (
          filter: GalleryFilter.photos,
          icon: Icons.photo_outlined,
          label: 'Photos',
        ),
      if (showVideos)
        (
          filter: GalleryFilter.videos,
          icon: Icons.videocam_outlined,
          label: 'Videos',
        ),
      if (showAudios)
        (
          filter: GalleryFilter.audios,
          icon: Icons.mic_none_outlined,
          label: 'Audios',
        ),
      if (showNotes)
        (
          filter: GalleryFilter.notes,
          icon: Icons.sticky_note_2_outlined,
          label: 'Notes',
        ),
    ];

    final tabs = <Widget>[];
    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      final isFirst = i == 0;
      final isLast = i == specs.length - 1;
      final radius = BorderRadius.horizontal(
        left: isFirst ? const Radius.circular(8) : Radius.zero,
        right: isLast ? const Radius.circular(8) : Radius.zero,
      );

      tabs.add(
        _GalleryTabButton(
          selected: selected == spec.filter,
          icon: spec.icon,
          label: spec.label,
          borderRadius: radius,
          onTap: () => onChanged(spec.filter),
        ),
      );
    }

    if (tabs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            Expanded(child: tabs[i]),
            if (i != tabs.length - 1)
              Container(width: 1, color: const Color(0xFFE5E5EA)),
          ],
        ],
      ),
    );
  }
}

class _GalleryTabButton extends StatelessWidget {
  const _GalleryTabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.borderRadius,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF15151A),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF15151A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventEmojiBackground extends StatelessWidget {
  const _EventEmojiBackground({
    required this.eventType,
    required this.child,
    this.backgroundFill,
  });

  final String eventType;
  final Widget child;
  final ColorFillValue? backgroundFill;

  @override
  Widget build(BuildContext context) {
    final emoji = _emojiForEvent(eventType);
    final bg = backgroundFill;

    final decoration = bg == null
        ? const BoxDecoration(color: Colors.white)
        : bg.mode == ColorFillMode.solid
        ? BoxDecoration(color: bg.primaryColor)
        : BoxDecoration(
            gradient: LinearGradient(
              begin: angleToBeginEnd(bg.gradient!.angleDegrees).$1,
              end: angleToBeginEnd(bg.gradient!.angleDegrees).$2,
              colors: bg.gradient!.colors,
            ),
          );

    return Stack(
      children: [
        Positioned.fill(child: DecoratedBox(decoration: decoration)),
        Positioned.fill(child: child),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // No emoji in the upper-left area.
                // That area already has the event emoji in the title.
                _FloatingEmoji(
                  emoji: emoji,
                  top: 170,
                  right: 18,
                  size: 32,
                  opacity: 0.68,
                  rotation: 0.12,
                ),
                _FloatingEmoji(
                  emoji: emoji,
                  top: 330,
                  left: 10,
                  size: 28,
                  opacity: 0.62,
                  rotation: 0.10,
                ),
                _FloatingEmoji(
                  emoji: emoji,
                  top: 412,
                  right: 10,
                  size: 30,
                  opacity: 0.64,
                  rotation: -0.10,
                ),
                _FloatingEmoji(
                  emoji: emoji,
                  bottom: 142,
                  left: 14,
                  size: 30,
                  opacity: 0.60,
                  rotation: 0.08,
                ),
                _FloatingEmoji(
                  emoji: emoji,
                  bottom: 82,
                  right: 18,
                  size: 28,
                  opacity: 0.66,
                  rotation: -0.08,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingEmoji extends StatelessWidget {
  const _FloatingEmoji({
    required this.emoji,
    required this.size,
    required this.opacity,
    required this.rotation,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  final String emoji;
  final double size;
  final double opacity;
  final double rotation;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: rotation,
        child: Opacity(
          opacity: opacity,
          child: Text(
            emoji,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size,
              height: 1,
              fontFamilyFallback: const [
                'Apple Color Emoji',
                'Segoe UI Emoji',
                'Noto Color Emoji',
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _emojiForEvent(String eventType) {
  switch (eventType.toLowerCase().trim()) {
    case 'wedding':
      return '💍';
    case 'birthday':
      return '🎂';
    case 'graduation':
      return '🎓';
    case 'anniversary':
      return '❤️';
    case 'baby_shower':
      return '🍼';
    case 'corporate':
      return '🏢';
    case 'party':
      return '🎉';
    case 'travel':
      return '✈️';
    default:
      return '📸';
  }
}
