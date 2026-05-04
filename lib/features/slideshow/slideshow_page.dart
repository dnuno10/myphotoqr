import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../../models/album.dart';
import '../../models/media_upload.dart';
import '../../models/note.dart';
import '../../models/slideshow_settings.dart';
import '../../services/album_service.dart';
import '../../services/slideshow_settings_service.dart';
import '../../shared/ui/color_utils.dart';
import '../../shared/ui/event_icons.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/logo_mark.dart';
import '../../shared/widgets/saas_surface.dart';

class SlideshowPage extends StatefulWidget {
  const SlideshowPage({super.key, required this.slug});

  final String slug;

  @override
  State<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends State<SlideshowPage> {
  final _service = AlbumService();
  final _slideshowSettingsService = SlideshowSettingsService();

  Album? _album;
  SlideshowSettings? _settings;
  List<MediaUpload> _media = [];
  List<MemoryNote> _notes = [];
  int _index = 0;
  Timer? _timer;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final album = await _service.getAlbumBySlug(widget.slug);
      final settings =
          await _slideshowSettingsService.get(album.id) ??
          SlideshowSettings.defaults(album.id);

      setState(() {
        _album = album;
        _settings = settings;
      });

      supabase
          .from('media_uploads')
          .stream(primaryKey: ['id'])
          .eq('album_id', album.id)
          .order('created_at', ascending: false)
          .listen((rows) {
            final media = rows
                .map((e) => MediaUpload.fromJson(e))
                .where((m) {
                  if (settings.onlyApprovedMedia &&
                      m.status.toLowerCase() != 'approved') {
                    return false;
                  }
                  if (m.isHidden) return false;
                  if (settings.onlyFeaturedMedia && !m.isFeatured) return false;

                  if (m.type == 'photo') return settings.showPhotos;
                  if (m.type == 'video') return settings.showVideos;
                  if (m.type == 'audio') return settings.showVideos;

                  return true;
                })
                .toList();

            if (!mounted) return;
            setState(() {
              _media = media;
              if (_index >= _media.length) _index = 0;
            });
          });

      if (settings.showNotes) {
        supabase
            .from('notes')
            .stream(primaryKey: ['id'])
            .eq('album_id', album.id)
            .order('created_at', ascending: false)
            .listen((rows) {
              final notes = rows
                  .map((e) => MemoryNote.fromJson(e))
                  .where((n) {
                    if (settings.onlyApprovedMedia &&
                        n.status.toLowerCase() != 'approved') {
                      return false;
                    }
                    if (n.isHidden) return false;
                    if (settings.onlyFeaturedMedia && !n.isFeatured) return false;
                    return true;
                  })
                  .toList();

              if (!mounted) return;
              setState(() => _notes = notes);
            });
      }

      final interval = settings.intervalSeconds <= 0 ? 5 : settings.intervalSeconds;
      _timer = Timer.periodic(Duration(seconds: interval), (_) {
        if (!mounted) return;
        final items = _buildItems(settings);
        if (items.isEmpty) return;
        setState(() => _index = (_index + 1) % items.length);
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: ErrorView(message: _error.toString()));
    }
    if (_album == null) {
      return const Scaffold(
        body: LoadingView(message: 'Cargando slideshow...'),
      );
    }

    final album = _album!;
    final settings = _settings ?? SlideshowSettings.defaults(album.id);

    final items = _buildItems(settings);
    final safeIndex = items.isEmpty ? 0 : (_index >= items.length ? 0 : _index);

    return Scaffold(
      backgroundColor: (settings.backgroundColor).toColorOr(Colors.black),
      body: !settings.enabled
          ? Center(
              child: SaasSurface(
                constraints: const BoxConstraints(maxWidth: 540),
                child: const Text('Slideshow is disabled for this album.'),
              ),
            )
          : items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoMark(size: 72),
                  const SizedBox(height: 22),
                  Icon(
                    iconForEventType(album.eventType),
                    size: 34,
                    color: (album.themeColor)
                        .toColorOr(Colors.white)
                        .mix(Colors.white, 0.25),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Esperando recuerdos...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 850),
                  transitionBuilder: (child, animation) {
                    if (settings.transitionStyle.toLowerCase() == 'slide') {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOut),
                      );
                      return SlideTransition(position: offsetAnimation, child: child);
                    }
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _SlideItem(
                    key: ValueKey(items[safeIndex].key),
                    item: items[safeIndex],
                    textColor: (settings.textColor).toColorOr(Colors.white),
                    showCaptions: settings.showCaptions,
                  ),
                ),
                Positioned(
                  left: 34,
                  right: 34,
                  bottom: 34,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(.14)),
                    ),
                    child: Row(
                      children: [
                        const LogoMark(size: 44),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            album.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        Text(
                          '${safeIndex + 1}/${items.length}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<_SlideContent> _buildItems(SlideshowSettings settings) {
    final items = <_SlideContent>[
      for (final m in _media) _SlideContent.media(m),
      if (settings.showNotes) for (final n in _notes) _SlideContent.note(n),
    ];

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}

class _SlideItem extends StatelessWidget {
  const _SlideItem({
    super.key,
    required this.item,
    required this.textColor,
    required this.showCaptions,
  });

  final _SlideContent item;
  final Color textColor;
  final bool showCaptions;

  @override
  Widget build(BuildContext context) {
    if (item.kind == _SlideKind.note) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 880),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.32),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Text(
            item.note!.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 34,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    final media = item.media!;

    if (media.type == 'photo') {
      return CachedNetworkImage(
        imageUrl: media.fileUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator()),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              media.type == 'video'
                  ? Icons.play_circle_fill_rounded
                  : Icons.audiotrack_rounded,
              color: textColor,
              size: 100,
            ),
            const SizedBox(height: 18),
            Text(
              media.type == 'video' ? 'Video recibido' : 'Audio recibido',
              style: TextStyle(
                color: textColor,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (showCaptions &&
                (media.caption ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                media.caption!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor.withOpacity(0.85),
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SlideKind { media, note }

class _SlideContent {
  const _SlideContent._({required this.kind, this.media, this.note});

  final _SlideKind kind;
  final MediaUpload? media;
  final MemoryNote? note;

  String get key => kind == _SlideKind.media ? media!.id : note!.id;

  DateTime get createdAt =>
      kind == _SlideKind.media ? media!.createdAt : note!.createdAt;

  factory _SlideContent.media(MediaUpload media) =>
      _SlideContent._(kind: _SlideKind.media, media: media);

  factory _SlideContent.note(MemoryNote note) =>
      _SlideContent._(kind: _SlideKind.note, note: note);
}
