import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/supabase_client.dart';
import '../../models/media_upload.dart';
import '../../models/note.dart';
import '../../shared/widgets/saas_surface.dart';

enum GalleryFilter { all, photos, videos, audios, notes }

class GalleryGrid extends StatelessWidget {
  const GalleryGrid({
    super.key,
    required this.albumId,
    this.filter = GalleryFilter.all,
    this.showGuestNames = true,
  });

  final String albumId;
  final GalleryFilter filter;
  final bool showGuestNames;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('media_uploads')
          .stream(primaryKey: ['id'])
          .eq('album_id', albumId)
          .order('created_at', ascending: false),
      builder: (context, mediaSnapshot) {
        if (mediaSnapshot.connectionState == ConnectionState.waiting) {
          return const _SkeletonGrid();
        }

        final media = (mediaSnapshot.data ?? [])
            .map((e) => MediaUpload.fromJson(e))
            .where((m) => m.status == 'approved' && !m.isHidden)
            .where((m) {
              return switch (filter) {
                GalleryFilter.photos => m.type == 'photo',
                GalleryFilter.videos => m.type == 'video',
                GalleryFilter.audios => m.type == 'audio',
                GalleryFilter.notes => false,
                GalleryFilter.all => true,
              };
            })
            .toList();

        return FutureBuilder<List<MemoryNote>>(
          future: _loadNotes(),
          builder: (context, notesSnapshot) {
            if (notesSnapshot.connectionState == ConnectionState.waiting) {
              return const _SkeletonGrid();
            }

            final notes = (filter == GalleryFilter.notes ||
                    filter == GalleryFilter.all)
                ? (notesSnapshot.data ?? const <MemoryNote>[])
                : const <MemoryNote>[];

            if (media.isEmpty && notes.isEmpty) {
              return Center(
                child: SaasSurface(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.all(18),
                  child: const Text('No memories yet in this album.'),
                ),
              );
            }

            final items = <Widget>[
              for (final item in media)
                _MediaCard(media: item, showGuestNames: showGuestNames),
              for (final note in notes)
                _NoteCard(note: note, showGuestNames: showGuestNames),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1100
                    ? 4
                    : width >= 760
                    ? 3
                    : width >= 480
                    ? 2
                    : 1;

                return MasonryGridView.count(
                  crossAxisCount: columns,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  itemCount: items.length,
                  itemBuilder: (context, index) => items[index],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<MemoryNote>> _loadNotes() async {
    final rows = await supabase
        .from('notes')
        .select()
        .eq('album_id', albumId)
        .eq('status', 'approved')
        .eq('is_hidden', false)
        .order('created_at', ascending: false);

    return rows.map<MemoryNote>((row) => MemoryNote.fromJson(row)).toList();
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.media, required this.showGuestNames});

  final MediaUpload media;
  final bool showGuestNames;

  @override
  Widget build(BuildContext context) {
    final isPhoto = media.type == 'photo';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showDialog<void>(
              context: context,
              barrierColor: Colors.black.withOpacity(0.82),
              builder: (context) {
                return _MediaViewerDialog(
                  media: media,
                  showGuestNames: showGuestNames,
                );
              },
            );
          },
          child: AspectRatio(
            aspectRatio: isPhoto ? 4 / 3 : 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isPhoto)
                  Container(
                    color: const Color(0xFFF8F8FA),
                    child: CachedNetworkImage(
                      imageUrl: media.thumbnailUrl ?? media.fileUrl,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) {
                        final lower = url.toLowerCase();
                        final isHeic =
                            lower.contains('.heic') || lower.contains('.heif');

                        return Container(
                          color: const Color(0xFFF8F8FA),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.image_not_supported_outlined,
                                size: 44,
                                color: Color(0xFF6A6A74),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                isHeic
                                    ? 'HEIC is not supported in this browser.'
                                    : 'Could not load the image.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.55),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final uri = Uri.tryParse(url);
                                  if (uri == null) return;
                                  launchUrl(uri, mode: LaunchMode.platformDefault);
                                },
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                label: Text(isHeic ? 'Open/Download' : 'Open'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF050505), Color(0xFF1D1D1D)],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        media.type == 'video'
                            ? Icons.play_circle_fill_rounded
                            : Icons.audiotrack_rounded,
                        color: Colors.white,
                        size: 58,
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(
                    media.type == 'photo'
                        ? Icons.image_outlined
                        : media.type == 'video'
                        ? Icons.videocam_outlined
                        : Icons.mic_none_outlined,
                    color:
                        isPhoto ? Colors.black.withOpacity(0.65) : Colors.white,
                    size: 20,
                  ),
                ),
                if (media.caption != null && media.caption!.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.56),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        media.caption!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.showGuestNames});

  final MemoryNote note;
  final bool showGuestNames;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 168),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () {
            showDialog<void>(
              context: context,
              barrierColor: Colors.black.withOpacity(0.82),
              builder: (context) {
                return _NoteViewerDialog(
                  note: note,
                  showGuestNames: showGuestNames,
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB).withOpacity(.9),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Center(
              child: Text(
                '“${note.message}”',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaViewerDialog extends StatefulWidget {
  const _MediaViewerDialog({required this.media, required this.showGuestNames});

  final MediaUpload media;
  final bool showGuestNames;

  @override
  State<_MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<_MediaViewerDialog> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late final Future<_GuestInfo?> _guestFuture;

  @override
  void initState() {
    super.initState();
    _guestFuture = _loadGuestInfo();

    if (widget.media.type == 'video') {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.media.fileUrl),
      );

      _videoController!.initialize().then((_) {
        if (!mounted) return;
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          showControlsOnInitialize: true,
        );
        setState(() {});
      });
    }
  }

  Future<_GuestInfo?> _loadGuestInfo() async {
    if (!widget.showGuestNames) return null;
    final guestId = widget.media.guestId;
    if (guestId == null || guestId.trim().isEmpty) return null;

    final row = await supabase
        .from('guests')
        .select('name, email')
        .eq('id', guestId)
        .maybeSingle();

    if (row == null) return null;
    return _GuestInfo(
      name: row['name'] as String?,
      email: row['email'] as String?,
    );
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.media.fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  @override
  Widget build(BuildContext context) {
    final isPhoto = widget.media.type == 'photo';
    final isVideo = widget.media.type == 'video';
    final isAudio = widget.media.type == 'audio';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(
                    isPhoto
                        ? Icons.image_outlined
                        : isVideo
                        ? Icons.videocam_outlined
                        : Icons.mic_none_outlined,
                    size: 18,
                    color: const Color(0xFF15151A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.media.caption?.trim().isNotEmpty == true
                          ? widget.media.caption!.trim()
                          : 'Memory',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15151A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 620),
              color: Colors.black,
              child: Builder(
                builder: (context) {
                  if (isPhoto) {
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: widget.media.fileUrl,
                          fit: BoxFit.contain,
                          errorWidget: (context, url, error) {
                            final lower = url.toLowerCase();
                            final isHeic =
                                lower.contains('.heic') || lower.contains('.heif');

                            return Container(
                              color: Colors.black,
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.white,
                                    size: 54,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isHeic
                                        ? 'HEIC is not supported in this browser.'
                                        : 'Could not load the image.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () {
                                      final uri = Uri.tryParse(url);
                                      if (uri == null) return;
                                      launchUrl(uri, mode: LaunchMode.platformDefault);
                                    },
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Open/Download'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }

                  if (isVideo) {
                    final chewie = _chewieController;
                    if (chewie == null) {
                      return const SizedBox(
                        height: 260,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    }

                    return AspectRatio(
                      aspectRatio:
                          _videoController?.value.aspectRatio ?? (16 / 9),
                      child: Chewie(controller: chewie),
                    );
                  }

                  return SizedBox(
                    height: 240,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.audiotrack_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _openExternally,
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text('Open audio'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FutureBuilder<_GuestInfo?>(
                future: _guestFuture,
                builder: (context, snapshot) {
                  final guest = snapshot.data;
                  final showLine =
                      widget.showGuestNames && (widget.media.guestId != null);

                  if (!showLine) {
                    return const SizedBox.shrink();
                  }

                  final title = (guest?.displayName ?? '').trim().isEmpty
                      ? 'Guest'
                      : guest!.displayName;

                  return Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: Color(0xFF667085),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Uploaded by $title',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ),
                      if (isAudio)
                        TextButton(
                          onPressed: _openExternally,
                          child: const Text('Open'),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteViewerDialog extends StatelessWidget {
  const _NoteViewerDialog({required this.note, required this.showGuestNames});

  final MemoryNote note;
  final bool showGuestNames;

  Future<_GuestInfo?> _loadGuestInfo() async {
    if (!showGuestNames) return null;
    final guestId = note.guestId;
    if (guestId == null || guestId.trim().isEmpty) return null;
    final row = await supabase
        .from('guests')
        .select('name, email')
        .eq('id', guestId)
        .maybeSingle();
    if (row == null) return null;
    return _GuestInfo(
      name: row['name'] as String?,
      email: row['email'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 18,
                    color: Color(0xFF15151A),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Note',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15151A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Text(
                '“${note.message}”',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: FutureBuilder<_GuestInfo?>(
                future: _loadGuestInfo(),
                builder: (context, snapshot) {
                  final showLine = showGuestNames && (note.guestId != null);
                  if (!showLine) return const SizedBox.shrink();

                  final guest = snapshot.data;
                  final title = (guest?.displayName ?? '').trim().isEmpty
                      ? 'Guest'
                      : guest!.displayName;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: Color(0xFF667085),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Uploaded by $title',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestInfo {
  const _GuestInfo({required this.name, required this.email});

  final String? name;
  final String? email;

  String get displayName {
    final n = (name ?? '').trim();
    if (n.isNotEmpty) return n;
    final e = (email ?? '').trim();
    if (e.isNotEmpty) return e;
    return 'Guest';
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: MasonryGridView.count(
        itemCount: 8,
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        itemBuilder: (context, index) {
          return Container(
            height: index.isEven ? 220 : 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: const Center(child: Text(' ')),
          );
        },
      ),
    );
  }
}
