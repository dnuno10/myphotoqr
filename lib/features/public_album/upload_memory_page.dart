import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/album.dart';
import '../../models/album_settings.dart';
import '../../services/album_service.dart';
import '../../services/album_settings_service.dart';
import '../../services/guest_session_service.dart';
import '../../services/upload_service.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/ui/event_theme.dart';
import '../../shared/ui/color_fill.dart';
import '../../shared/ui/app_snackbars.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/logo_mark.dart';
import '../../shared/widgets/saas_surface.dart';

class UploadMemoryPage extends StatefulWidget {
  const UploadMemoryPage({super.key, required this.slug});

  final String slug;

  @override
  State<UploadMemoryPage> createState() => _UploadMemoryPageState();
}

class _UploadMemoryPageState extends State<UploadMemoryPage> {
  static const _photoExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
  ];

  static const _videoExtensions = ['mp4', 'mov', 'm4v', 'webm'];
  static const _audioExtensions = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'webm'];
  static final _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  final _albumService = AlbumService();
  final _albumSettingsService = AlbumSettingsService();
  final _guestSessionService = GuestSessionService();
  final _uploadService = UploadService();

  late Future<_UploadAlbumBundle> _future;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _accessGranted = false;
  bool _loading = false;
  List<PlatformFile> _files = [];
  UploadKind _kind = UploadKind.media;
  bool _allowPhotos = true;
  bool _allowVideos = true;
  bool _allowAudio = false;
  bool _allowNotes = true;
  bool _requireGuestName = false;
  bool _requireGuestEmail = false;
  int _maxFileSizeMb = 500;
  bool _moderationEnabled = false;
  bool _autoApproveUploads = true;
  bool _autoApproveNotes = true;

  @override
  void initState() {
    super.initState();
    _future = _loadAlbum();
  }

  Future<_UploadAlbumBundle> _loadAlbum() async {
    final album = await _albumService.getAlbumBySlug(widget.slug);
    final settings =
        await _albumSettingsService.get(album.id) ??
        AlbumSettings.defaults(album.id);

    _allowPhotos = settings.allowPhotos;
    _allowVideos = settings.allowVideos;
    _allowAudio = settings.allowAudio;
    _allowNotes = settings.allowNotes;
    _requireGuestName = settings.requireGuestName;
    _requireGuestEmail = settings.requireGuestEmail;
    _maxFileSizeMb = settings.maxFileSizeMb;
    _moderationEnabled = settings.moderationEnabled;
    _autoApproveUploads = settings.autoApproveUploads;
    _autoApproveNotes = settings.autoApproveNotes;

    if (!_allowNotes && _kind == UploadKind.note) {
      _kind = UploadKind.media;
    }

    if (!_allowPhotos && !_allowVideos && !_allowAudio) {
      _allowPhotos = true;
    }

    final requiresCode =
        album.guestAccessCodeEnabled || album.visibility == 'code_protected';
    if (requiresCode) {
      await _guestSessionService.ensureSignedIn();
      _accessGranted = await _uploadService.hasAlbumAccess(albumId: album.id);
    } else {
      _accessGranted = true;
    }

    return _UploadAlbumBundle(album: album, settings: settings);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _captionCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyCode(Album album) async {
    setState(() => _loading = true);

    try {
      await _guestSessionService.ensureSignedIn();
      final ok = await _uploadService.verifyAccessCode(
        albumId: album.id,
        code: _codeCtrl.text.trim(),
      );

      if (!ok) throw Exception('Incorrect access code.');

      setState(() => _accessGranted = true);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFiles() async {
    if (_kind != UploadKind.media) return;

    final onlyPhotos = _allowPhotos && !_allowVideos;
    final onlyVideos = _allowVideos && !_allowPhotos;
    final onlyAudio = _allowAudio && !_allowPhotos && !_allowVideos;

    final allowedExtensions = onlyPhotos
        ? _photoExtensions
        : onlyVideos
        ? _videoExtensions
        : onlyAudio
        ? _audioExtensions
        : [..._photoExtensions, ..._videoExtensions, ..._audioExtensions];

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (result == null) return;

    final validFiles = result.files.where(_isAllowedMediaFile).toList();

    final invalidFiles = result.files
        .where((file) => !_isAllowedMediaFile(file))
        .map((file) => file.name)
        .toList();

    if (invalidFiles.isNotEmpty) {
      _showError(
        'Some files are not allowed. Please remove: ${invalidFiles.join(', ')}',
      );
    }

    if (validFiles.isEmpty) return;

    setState(() => _files = validFiles);
  }

  Future<void> _submit(Album album) async {
    final note = _noteCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (_requireGuestName && name.isEmpty) {
      _showError('Please enter your name.');
      return;
    }

    if (_requireGuestEmail && email.isEmpty) {
      _showError('Please enter your email.');
      return;
    }

    if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email (or leave it blank).');
      return;
    }

    if (_kind == UploadKind.media && _files.isEmpty) {
      _showError('Please select at least one file.');
      return;
    }

    if (_kind == UploadKind.media &&
        _files.any((file) => !_isAllowedMediaFile(file))) {
      _showError('Some selected files are not allowed.');
      return;
    }

    if (_kind == UploadKind.note && note.isEmpty) {
      _showError('Please write a note for the album.');
      return;
    }

    if (_kind == UploadKind.media) {
      final maxBytes = _maxFileSizeMb * 1024 * 1024;
      final tooBig = _files.where((f) => f.size > maxBytes).toList();
      if (tooBig.isNotEmpty) {
        _showError(
          'File too large. Max is ${_maxFileSizeMb}MB. Please remove: ${tooBig.map((e) => e.name).join(', ')}',
        );
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final guest = await _uploadService.getOrCreateGuest(
        albumId: album.id,
        name: name,
        email: email,
        accessCodeUsed: album.guestAccessCodeEnabled && _accessGranted,
      );

      if (_kind == UploadKind.media) {
        final status = (_moderationEnabled && !_autoApproveUploads)
            ? 'pending'
            : 'approved';
        for (final file in _files) {
          await _uploadService.uploadMedia(
            albumId: album.id,
            guestId: guest['id'],
            pickedFile: file,
            caption: _captionCtrl.text.trim(),
            status: status,
          );
        }
      }

      if (_kind == UploadKind.note) {
        final noteStatus = (_moderationEnabled && !_autoApproveNotes)
            ? 'pending'
            : 'approved';
        await _uploadService.createNote(
          albumId: album.id,
          guestId: guest['id'],
          message: note,
          status: noteStatus,
        );
      }

      if (!mounted) return;

      final pending =
          _moderationEnabled &&
          ((_kind == UploadKind.media && !_autoApproveUploads) ||
              (_kind == UploadKind.note && !_autoApproveNotes));

      context.showTopRightSnackBar(
        pending
            ? 'Done! Your submission is pending approval.'
            : 'Done! Your submission is published.',
        type: ToastType.success,
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) context.go('/a/${album.slug}');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isAllowedMediaFile(PlatformFile file) {
    final fileName = file.name.toLowerCase().trim();
    final extension = (file.extension ?? '').toLowerCase().trim();
    final mimeType = lookupMimeType(file.name);

    final hasPhotoExtension = _photoExtensions.contains(extension);
    final hasVideoExtension = _videoExtensions.contains(extension);
    final hasAudioExtension = _audioExtensions.contains(extension);

    final hasPhotoMime = mimeType?.startsWith('image/') == true;
    final hasVideoMime = mimeType?.startsWith('video/') == true;
    final hasAudioMime = mimeType?.startsWith('audio/') == true;

    final isPhoto = hasPhotoExtension || hasPhotoMime;
    final isVideo = hasVideoExtension || hasVideoMime;
    final isAudio = hasAudioExtension || hasAudioMime;

    if (fileName.endsWith('.keystore')) return false;
    if (!isPhoto && !isVideo && !isAudio) return false;
    if (!_allowPhotos && isPhoto) return false;
    if (!_allowVideos && isVideo) return false;
    if (!_allowAudio && isAudio) return false;

    return true;
  }

  void _showError(Object e) {
    context.showTopRightSnackBar(
      _friendlyErrorMessage(e),
      type: ToastType.error,
    );
  }

  String _friendlyErrorMessage(Object e) {
    if (e is PostgrestException) {
      if (e.code == '42501' || e.message.contains('row-level security')) {
        return 'Uploads are currently unavailable. Please contact the album host.';
      }
      if (e.message.trim().isNotEmpty) return e.message.trim();
    }

    final raw = e.toString();
    if (raw.contains('42501') || raw.contains('row-level security')) {
      return 'Uploads are currently unavailable. Please contact the album host.';
    }
    if (raw.contains('ClientException: Load failed')) {
      return 'Network request failed. Please check your connection and try again.';
    }

    // Avoid leaking internal URLs and noisy exception types to guests.
    var simplified = raw.trim();
    simplified = simplified.replaceFirst('ClientException: ', '');
    simplified = simplified.replaceFirst('ClientException:', '');

    if (simplified.startsWith('PostgrestException(')) {
      simplified = simplified.replaceFirst(
        RegExp(r'^PostgrestException\(message:\s*'),
        '',
      );
      final codeIndex = simplified.indexOf(', code:');
      if (codeIndex != -1) simplified = simplified.substring(0, codeIndex);
      simplified = simplified.replaceAll(RegExp(r'\)$'), '');
    }

    simplified = simplified.trim();
    return simplified.isEmpty ? 'Upload failed. Please try again.' : simplified;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_UploadAlbumBundle>(
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
          final requiresCode = album.guestAccessCodeEnabled && !_accessGranted;
          final backgroundFill = ColorFillValue.fromAlbumFields(
            solidHexFallback: album.themeBackgroundColor,
            mode: album.themeBackgroundMode,
            gradient: album.themeBackgroundGradient,
          );

          return _EventEmojiBackground(
            eventType: album.eventType,
            backgroundFill: backgroundFill,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SaasSurface(
                    padding: const EdgeInsets.all(22),
                    color: Colors.white.withOpacity(0.92),
                    borderColor: Colors.white.withOpacity(0.65),
                    child: requiresCode
                        ? _codeForm(album)
                        : _uploadForm(album, settings),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _codeForm(Album album) {
    return Column(
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
          'Enter the event access code to upload memories.',
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
          controller: _codeCtrl,
          enabled: !_loading,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_loading) _verifyCode(album);
          },
          cursorColor: Colors.black,
          decoration: const InputDecoration(labelText: 'Access code'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _loading ? null : () => _verifyCode(album),
            child: Text(_loading ? 'Verifying...' : 'Enter'),
          ),
        ),
      ],
    );
  }

  Widget _uploadForm(Album album, AlbumSettings settings) {
    final eventCopy = eventThemeCopy(album.eventType);

    return ListView(
      shrinkWrap: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(
          children: [
            const LogoMark(size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(album.themeEmoji ?? '').trim().isNotEmpty ? album.themeEmoji!.trim() : _emojiForEvent(album.eventType)} ${eventCopy.uploadTitle}',
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Color(0xFF15151A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    eventCopy.uploadDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;

            final fields = [
              TextField(
                controller: _nameCtrl,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: _requireGuestName ? 'Name *' : 'Name (optional)',
                ),
              ),
              TextField(
                controller: _emailCtrl,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: _requireGuestEmail
                      ? 'Email *'
                      : 'Email (optional)',
                ),
              ),
            ];

            if (compact) {
              return Column(
                children: [fields[0], const SizedBox(height: 10), fields[1]],
              );
            }

            return Row(
              children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 12),
                Expanded(child: fields[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        if (settings.allowNotes)
          _UploadKindSelector(
            value: _kind,
            enabled: !_loading,
            onChanged: (next) {
              if (next == _kind) return;

              setState(() {
                _kind = next;

                if (_kind == UploadKind.note) {
                  _files = [];
                  _captionCtrl.clear();
                  _allowPhotos = settings.allowPhotos;
                  _allowVideos = settings.allowVideos;
                  _allowAudio = settings.allowAudio;
                } else {
                  _noteCtrl.clear();
                }
              });
            },
          )
        else
          const SizedBox.shrink(),
        const SizedBox(height: 12),
        if (_kind == UploadKind.media) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('Photos'),
                selected: _allowPhotos,
                onSelected: _loading
                    ? null
                    : !settings.allowPhotos
                    ? null
                    : (value) {
                        final nextPhotos = value;
                        final nextVideos = nextPhotos ? _allowVideos : true;

                        setState(() {
                          _allowPhotos = nextPhotos;
                          _allowVideos = nextVideos;
                          _files = [];
                        });
                      },
              ),
              FilterChip(
                label: const Text('Videos'),
                selected: _allowVideos,
                onSelected: _loading
                    ? null
                    : !settings.allowVideos
                    ? null
                    : (value) {
                        final nextVideos = value;
                        final nextPhotos = nextVideos ? _allowPhotos : true;

                        setState(() {
                          _allowVideos = nextVideos;
                          _allowPhotos = nextPhotos;
                          _files = [];
                        });
                      },
              ),
              FilterChip(
                label: const Text('Audio'),
                selected: _allowAudio,
                onSelected: _loading
                    ? null
                    : !settings.allowAudio
                    ? null
                    : (value) {
                        final nextAudio = value;
                        final nextPhotos = nextAudio
                            ? _allowPhotos
                            : (_allowPhotos || _allowVideos);
                        final nextVideos = nextAudio
                            ? _allowVideos
                            : (_allowVideos || _allowPhotos);

                        setState(() {
                          _allowAudio = nextAudio;
                          _allowPhotos = nextPhotos;
                          _allowVideos = nextVideos;
                          if (!_allowPhotos && !_allowVideos && !_allowAudio) {
                            // Keep at least one media type enabled.
                            _allowPhotos = settings.allowPhotos;
                            _allowVideos = settings.allowVideos;
                            _allowAudio = settings.allowAudio;
                          }
                          _files = [];
                        });
                      },
              ),
              if (settings.allowNotes)
                Text(
                  'Notes are uploaded separately.',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.50),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading ? null : _pickFiles,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(
              _files.isEmpty
                  ? _allowAudio && !_allowPhotos && !_allowVideos
                        ? 'Select audio'
                        : _allowAudio
                        ? 'Select photos, videos or audio'
                        : 'Select photos or videos'
                  : '${_files.length} file(s) selected',
            ),
          ),
          const SizedBox(height: 10),
          if (_files.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final file in _files)
                  Chip(
                    label: Text(file.name, overflow: TextOverflow.ellipsis),
                    onDeleted: _loading
                        ? null
                        : () {
                            setState(() {
                              _files = _files.where((item) {
                                return item.identifier != file.identifier ||
                                    item.name != file.name;
                              }).toList();
                            });
                          },
                  ),
              ],
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _captionCtrl,
            enabled: !_loading,
            decoration: const InputDecoration(labelText: 'Caption optional'),
          ),
        ] else ...[
          TextField(
            controller: _noteCtrl,
            enabled: !_loading,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Your note',
              hintText: 'A message, a story or a memory...',
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (!album.uploadEnabled) ...[
          Text(
            'Uploads are disabled for this album.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: (_loading || !album.uploadEnabled)
                ? null
                : () => _submit(album),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_loading ? 'Uploading...' : 'Upload'),
          ),
        ),
      ],
    );
  }
}

class _UploadAlbumBundle {
  const _UploadAlbumBundle({required this.album, required this.settings});

  final Album album;
  final AlbumSettings settings;
}

enum UploadKind { media, note }

class _UploadKindSelector extends StatelessWidget {
  const _UploadKindSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final UploadKind value;
  final bool enabled;
  final ValueChanged<UploadKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _UploadTab(
              selected: value == UploadKind.media,
              enabled: enabled,
              icon: Icons.photo_library_outlined,
              label: 'Media',
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
              onTap: () => onChanged(UploadKind.media),
            ),
          ),
          Container(width: 1, color: const Color(0xFFE5E5EA)),
          Expanded(
            child: _UploadTab(
              selected: value == UploadKind.note,
              enabled: enabled,
              icon: Icons.sticky_note_2_outlined,
              label: 'Note',
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
              onTap: () => onChanged(UploadKind.note),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadTab extends StatelessWidget {
  const _UploadTab({
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.borderRadius,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: enabled ? onTap : null,
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
                _FloatingEmoji(
                  emoji: emoji,
                  top: 110,
                  left: 18,
                  size: 30,
                  opacity: 0.72,
                  rotation: -0.12,
                ),
                _FloatingEmoji(
                  emoji: emoji,
                  top: 156,
                  right: 18,
                  size: 32,
                  opacity: 0.68,
                  rotation: 0.12,
                ),
                _FloatingEmoji(
                  emoji: emoji,
                  top: 304,
                  left: 12,
                  size: 28,
                  opacity: 0.62,
                  rotation: 0.10,
                ),
                _FloatingEmoji(
                  emoji: emoji,
                  bottom: 164,
                  right: 16,
                  size: 30,
                  opacity: 0.64,
                  rotation: -0.10,
                ),
                _FloatingEmoji(
                  emoji: emoji,
                  bottom: 96,
                  left: 18,
                  size: 30,
                  opacity: 0.60,
                  rotation: 0.08,
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
