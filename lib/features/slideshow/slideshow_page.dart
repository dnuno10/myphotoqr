import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../models/album.dart';
import '../../models/media_upload.dart';
import '../../models/note.dart';
import '../../models/slideshow_settings.dart';
import '../../services/album_service.dart';
import '../../services/guest_session_service.dart';
import '../../services/slideshow_settings_service.dart';
import '../../services/upload_service.dart';
import '../../shared/ui/color_utils.dart';
import '../../shared/ui/event_icons.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/logo_mark.dart';
import '../../shared/widgets/saas_surface.dart';

class SlideshowPage extends StatefulWidget {
  const SlideshowPage({super.key, required this.slug, this.nextLocation});

  final String slug;
  final String? nextLocation;

  @override
  State<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends State<SlideshowPage> {
  final _service = AlbumService();
  final _slideshowSettingsService = SlideshowSettingsService();
  final _guestSessionService = GuestSessionService();
  final _uploadService = UploadService();
  final _focusNode = FocusNode();

  Album? _album;
  SlideshowSettings? _settings;
  bool _accessGranted = false;
  bool _unlocking = false;
  final _codeCtrl = TextEditingController();
  final Map<String, MediaUpload> _mediaById = {};
  final Map<String, MemoryNote> _notesById = {};
  final List<_SlideContent> _queue = [];
  int _index = 0;
  Timer? _timer;
  StreamSubscription<List<Map<String, dynamic>>>? _mediaSub;
  StreamSubscription<List<Map<String, dynamic>>>? _notesSub;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mediaSub?.cancel();
    _notesSub?.cancel();
    _focusNode.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_queue.isEmpty) return;
    setState(() => _index = (_index + 1) % _queue.length);
  }

  void _prev() {
    if (_queue.isEmpty) return;
    setState(() => _index = (_index - 1 + _queue.length) % _queue.length);
  }

  void _exitSlideshow() {
    final slug = _album?.slug ?? widget.slug;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    final next = (widget.nextLocation ?? '').trim();
    if (next.isNotEmpty && next.startsWith('/')) {
      context.go(next);
      return;
    }

    final user = supabase.auth.currentUser;
    final isOwnerSession = (user?.email ?? '').trim().isNotEmpty;
    context.go(isOwnerSession ? '/' : '/a/$slug');
  }

  Future<void> _load() async {
    try {
      final album = await _service.getAlbumBySlug(widget.slug);
      final settings =
          await _slideshowSettingsService.get(album.id) ??
          SlideshowSettings.defaults(album.id);

      final requiresCode =
          album.guestAccessCodeEnabled || album.visibility == 'code_protected';

      bool granted = true;
      if (requiresCode) {
        await _guestSessionService.ensureSignedIn();
        granted = await _uploadService.hasAlbumAccess(albumId: album.id);
      }

      if (!mounted) return;
      setState(() {
        _album = album;
        _settings = settings;
        _accessGranted = granted;
      });

      if (!granted) return;

      _startSlideshow(album: album, settings: settings);
    } catch (e) {
      setState(() => _error = e);
    }
  }

  void _startSlideshow({
    required Album album,
    required SlideshowSettings settings,
  }) {
    _timer?.cancel();
    _mediaSub?.cancel();
    _notesSub?.cancel();
    _mediaById.clear();
    _notesById.clear();
    _queue.clear();
    _index = 0;

    _mediaSub = supabase
        .from('media_uploads')
        .stream(primaryKey: ['id'])
        .eq('album_id', album.id)
        .order('created_at', ascending: true)
        .listen((rows) {
          final media = rows.map((e) => MediaUpload.fromJson(e)).where((m) {
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
          }).toList();

          if (!mounted) return;
          setState(() {
            _applyMediaSnapshot(media);
          });
        });

    if (settings.showNotes) {
      _notesSub = supabase
          .from('notes')
          .stream(primaryKey: ['id'])
          .eq('album_id', album.id)
          .order('created_at', ascending: true)
          .listen((rows) {
            final notes = rows.map((e) => MemoryNote.fromJson(e)).where((n) {
              if (settings.onlyApprovedMedia &&
                  n.status.toLowerCase() != 'approved') {
                return false;
              }
              if (n.isHidden) return false;
              if (settings.onlyFeaturedMedia && !n.isFeatured) return false;
              return true;
            }).toList();

            if (!mounted) return;
            setState(() => _applyNotesSnapshot(notes));
          });
    }

    final interval = settings.intervalSeconds <= 0
        ? 5
        : settings.intervalSeconds;
    _timer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!mounted) return;
      if (_queue.isEmpty) return;
      setState(() => _index = (_index + 1) % _queue.length);
    });
  }

  Future<void> _unlock(Album album) async {
    if (_unlocking) return;
    final code = _codeCtrl.text.trim();
    if (code.length < 4) return;

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

      final settings = _settings ?? SlideshowSettings.defaults(album.id);
      _startSlideshow(album: album, settings: settings);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: ErrorView(message: _error.toString()));
    }
    if (_album == null) {
      return const Scaffold(body: LoadingView(message: 'Loading slideshow...'));
    }

    final album = _album!;
    final settings = _settings ?? SlideshowSettings.defaults(album.id);
    final requiresCode =
        album.guestAccessCodeEnabled || album.visibility == 'code_protected';

    if (requiresCode && !_accessGranted) {
      final hint = (album.guestAccessCodeHint ?? '').trim();
      return Scaffold(
        backgroundColor: (settings.backgroundColor).toColorOr(Colors.black),
        body: Center(
          child: SaasSurface(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoMark(size: 56),
                const SizedBox(height: 14),
                const Text(
                  'Protected slideshow',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  hint.isEmpty
                      ? 'Enter the access code to start the slideshow.'
                      : hint,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeCtrl,
                  enabled: !_unlocking,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_unlocking) _unlock(album);
                  },
                  decoration: const InputDecoration(labelText: 'Access code'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: _unlocking ? null : () => _unlock(album),
                    child: Text(_unlocking ? 'Verifying...' : 'Enter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final items = _queue;
    final safeIndex = items.isEmpty ? 0 : (_index >= items.length ? 0 : _index);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final hudPad = compact ? 16.0 : 34.0;

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
                  LogoMark(size: compact ? 56 : 72),
                  SizedBox(height: compact ? 16 : 22),
                  Icon(
                    iconForEventType(album.eventType),
                    size: compact ? 30 : 34,
                    color: (album.themeColor)
                        .toColorOr(Colors.white)
                        .mix(Colors.white, 0.25),
                  ),
                  SizedBox(height: compact ? 10 : 12),
                  Text(
                    'Waiting for memories...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 28 : 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _focusNode.requestFocus(),
                  child: Focus(
                    focusNode: _focusNode,
                    autofocus: true,
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (items.isEmpty) return KeyEventResult.ignored;

                      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                        _next();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        _prev();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.escape) {
                        _exitSlideshow();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 850),
                  transitionBuilder: (child, animation) {
                    if (settings.transitionStyle.toLowerCase() == 'slide') {
                      final offsetAnimation =
                          Tween<Offset>(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          );
                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
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
                  top: hudPad,
                  right: hudPad,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.35),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(.12)),
                    ),
                    child: IconButton(
                      tooltip: 'Salir del slideshow',
                      onPressed: _exitSlideshow,
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: hudPad,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.28),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(.12),
                        ),
                      ),
                      child: IconButton(
                        tooltip: 'Anterior',
                        onPressed: _prev,
                        icon: const Icon(Icons.chevron_left_rounded),
                        iconSize: compact ? 42 : 54,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: hudPad,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.28),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(.12),
                        ),
                      ),
                      child: IconButton(
                        tooltip: 'Siguiente',
                        onPressed: _next,
                        icon: const Icon(Icons.chevron_right_rounded),
                        iconSize: compact ? 42 : 54,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: hudPad,
                  right: hudPad,
                  bottom: hudPad,
                  child: Container(
                    padding: EdgeInsets.all(compact ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(.14)),
                    ),
                    child: Row(
                      children: [
                        LogoMark(size: compact ? 38 : 44),
                        SizedBox(width: compact ? 12 : 16),
                        Expanded(
                          child: Text(
                            album.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 22 : 30,
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

  void _applyMediaSnapshot(List<MediaUpload> media) {
    final incomingIds = <String>{};
    for (final m in media) {
      incomingIds.add(m.id);
      _mediaById[m.id] = m;
    }
    _mediaById.removeWhere((id, _) => !incomingIds.contains(id));
    _reconcileQueue();
  }

  void _applyNotesSnapshot(List<MemoryNote> notes) {
    final incomingIds = <String>{};
    for (final n in notes) {
      incomingIds.add(n.id);
      _notesById[n.id] = n;
    }
    _notesById.removeWhere((id, _) => !incomingIds.contains(id));
    _reconcileQueue();
  }

  void _reconcileQueue() {
    final allowedIds = <String>{..._mediaById.keys, ..._notesById.keys};

    // Remove items that no longer exist / no longer match filters.
    _queue.removeWhere((item) => !allowedIds.contains(item.id));

    final queuedIds = _queue.map((e) => e.id).toSet();

    // Append new items at the end (real-time without re-sorting).
    final newItems = <_SlideContent>[
      for (final m in _mediaById.values)
        if (!queuedIds.contains(m.id)) _SlideContent.media(m),
      for (final n in _notesById.values)
        if (!queuedIds.contains(n.id)) _SlideContent.note(n),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _queue.addAll(newItems);

    if (_queue.isEmpty) {
      _index = 0;
    } else if (_index >= _queue.length) {
      _index = 0;
    }
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
            if (showCaptions && (media.caption ?? '').trim().isNotEmpty) ...[
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
  String get id => key;

  DateTime get createdAt =>
      kind == _SlideKind.media ? media!.createdAt : note!.createdAt;

  factory _SlideContent.media(MediaUpload media) =>
      _SlideContent._(kind: _SlideKind.media, media: media);

  factory _SlideContent.note(MemoryNote note) =>
      _SlideContent._(kind: _SlideKind.note, note: note);
}
