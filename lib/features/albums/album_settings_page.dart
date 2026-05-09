import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';
import '../../models/album.dart';
import '../../models/album_settings.dart';
import '../../models/slideshow_settings.dart';
import '../../services/album_service.dart';
import '../../services/album_settings_service.dart';
import '../../services/slideshow_settings_service.dart';
import '../../shared/ui/app_snackbars.dart';
import '../../shared/widgets/color_fill_picker.dart';
import '../../shared/ui/color_fill.dart';
import '../../shared/widgets/logo_mark.dart';
import '../../shared/widgets/saas_surface.dart';

class AlbumSettingsPage extends StatefulWidget {
  const AlbumSettingsPage({super.key, required this.albumId});

  final String albumId;

  @override
  State<AlbumSettingsPage> createState() => _AlbumSettingsPageState();
}

class _AlbumSettingsPageState extends State<AlbumSettingsPage> {
  final _albumService = AlbumService();
  final _albumSettingsService = AlbumSettingsService();
  final _slideshowSettingsService = SlideshowSettingsService();

  final _titleCtrl = TextEditingController();
  final _eventTypeLabelCtrl = TextEditingController();
  final _themeEmojiCtrl = TextEditingController();
  ColorFillValue _themeColorFill = const ColorFillValue.solid(
    Color(0xFF111827),
  );
  ColorFillValue _backgroundFill = const ColorFillValue.solid(
    Color(0xFFFFFFFF),
  );
  ColorFillValue _slideshowBackgroundFill = const ColorFillValue.solid(
    Color(0xFF000000),
  );
  ColorFillValue _slideshowTextFill = const ColorFillValue.solid(
    Color(0xFFFFFFFF),
  );
  final _accessCodeHintCtrl = TextEditingController();
  final _accessCodeCtrl = TextEditingController();

  final _maxFileSizeCtrl = TextEditingController();
  final _maxVideoDurationCtrl = TextEditingController();
  final _maxAudioDurationCtrl = TextEditingController();

  final _slideshowIntervalCtrl = TextEditingController();
  final _slideshowTransitionCtrl = TextEditingController();
  final _slideshowBgColorCtrl = TextEditingController();
  final _slideshowTextColorCtrl = TextEditingController();
  final _slideshowMusicUrlCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;

  Album? _album;
  AlbumSettings? _albumSettings;
  SlideshowSettings? _slideshowSettings;

  // Album fields
  String _status = 'active';
  bool _codeProtected = false;

  // AlbumSettings fields
  bool _allowPhotos = true;
  bool _allowVideos = true;
  bool _allowAudio = true;
  bool _allowNotes = true;
  bool _requireGuestName = false;
  bool _requireGuestEmail = false;
  bool _allowGuestViewGallery = true;
  bool _allowGuestDownloads = false;
  bool _showGuestNames = true;
  bool _showUploadDate = true;
  bool _moderationEnabled = false;
  bool _autoApproveUploads = true;
  bool _autoApproveNotes = true;
  bool _enableLiveGallery = true;
  bool _enableLiveSlideshow = true;

  // SlideshowSettings fields
  bool _slideshowEnabled = true;
  bool _slideshowShowPhotos = true;
  bool _slideshowShowVideos = true;
  bool _slideshowShowNotes = true;
  bool _slideshowShowGuestNames = true;
  bool _slideshowShowCaptions = true;
  bool _slideshowOnlyApproved = true;
  bool _slideshowOnlyFeatured = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _eventTypeLabelCtrl.dispose();
    _themeEmojiCtrl.dispose();
    _accessCodeHintCtrl.dispose();
    _accessCodeCtrl.dispose();
    _maxFileSizeCtrl.dispose();
    _maxVideoDurationCtrl.dispose();
    _maxAudioDurationCtrl.dispose();
    _slideshowIntervalCtrl.dispose();
    _slideshowTransitionCtrl.dispose();
    _slideshowBgColorCtrl.dispose();
    _slideshowTextColorCtrl.dispose();
    _slideshowMusicUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final album = await _albumService.getAlbumById(widget.albumId);
      final albumSettings = await _albumSettingsService.getOrCreate(album.id);
      final slideshowSettings = await _slideshowSettingsService.getOrCreate(
        album.id,
      );

      if (!mounted) return;

      setState(() {
        _album = album;
        _albumSettings = albumSettings;
        _slideshowSettings = slideshowSettings;

        _status = album.status;
        _codeProtected = album.guestAccessCodeEnabled;

        _titleCtrl.text = album.title;
        _eventTypeLabelCtrl.text = album.eventTypeLabel ?? '';
        _themeEmojiCtrl.text = album.themeEmoji ?? '';
        _themeColorFill = ColorFillValue.fromAlbumFields(
          solidHexFallback: album.themeColor,
          mode: album.themeColorMode,
          gradient: album.themeColorGradient,
        );
        _backgroundFill = ColorFillValue.fromAlbumFields(
          solidHexFallback: album.themeBackgroundColor,
          mode: album.themeBackgroundMode,
          gradient: album.themeBackgroundGradient,
        );
        _accessCodeHintCtrl.text = album.guestAccessCodeHint ?? '';

        _allowPhotos = albumSettings.allowPhotos;
        _allowVideos = albumSettings.allowVideos;
        _allowAudio = albumSettings.allowAudio;
        _allowNotes = albumSettings.allowNotes;
        _requireGuestName = albumSettings.requireGuestName;
        _requireGuestEmail = albumSettings.requireGuestEmail;
        _allowGuestViewGallery = albumSettings.allowGuestViewGallery;
        _allowGuestDownloads = albumSettings.allowGuestDownloads;
        _showGuestNames = albumSettings.showGuestNames;
        _showUploadDate = albumSettings.showUploadDate;
        _moderationEnabled = albumSettings.moderationEnabled;
        _autoApproveUploads = albumSettings.autoApproveUploads;
        _autoApproveNotes = albumSettings.autoApproveNotes;
        _enableLiveGallery = albumSettings.enableLiveGallery;
        _enableLiveSlideshow = albumSettings.enableLiveSlideshow;

        _maxFileSizeCtrl.text = albumSettings.maxFileSizeMb.toString();
        _maxVideoDurationCtrl.text =
            (albumSettings.maxVideoDurationSeconds ?? '').toString();
        _maxAudioDurationCtrl.text =
            (albumSettings.maxAudioDurationSeconds ?? '').toString();

        _slideshowEnabled = slideshowSettings.enabled;
        _slideshowTransitionCtrl.text = slideshowSettings.transitionStyle;
        _slideshowIntervalCtrl.text = slideshowSettings.intervalSeconds
            .toString();
        _slideshowShowPhotos = slideshowSettings.showPhotos;
        _slideshowShowVideos = slideshowSettings.showVideos;
        _slideshowShowNotes = slideshowSettings.showNotes;
        _slideshowShowGuestNames = slideshowSettings.showGuestNames;
        _slideshowShowCaptions = slideshowSettings.showCaptions;
        _slideshowOnlyApproved = slideshowSettings.onlyApprovedMedia;
        _slideshowOnlyFeatured = slideshowSettings.onlyFeaturedMedia;
        _slideshowBgColorCtrl.text = slideshowSettings.backgroundColor;
        _slideshowTextColorCtrl.text = slideshowSettings.textColor;
        _slideshowMusicUrlCtrl.text =
            slideshowSettings.backgroundMusicUrl ?? '';

        _slideshowBackgroundFill = ColorFillValue.solid(
          hexToColor(_slideshowBgColorCtrl.text) ?? const Color(0xFF000000),
        );
        _slideshowTextFill = ColorFillValue.solid(
          hexToColor(_slideshowTextColorCtrl.text) ?? const Color(0xFFFFFFFF),
        );

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      context.showTopRightSnackBar(
        'Could not load settings: $e',
        type: ToastType.error,
      );
    }
  }

  Future<void> _saveAll() async {
    final album = _album;
    final currentAlbumSettings = _albumSettings;
    final currentSlideshowSettings = _slideshowSettings;
    if (album == null ||
        currentAlbumSettings == null ||
        currentSlideshowSettings == null) {
      return;
    }

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      context.showTopRightSnackBar(
        'Album name is required.',
        type: ToastType.error,
      );
      return;
    }
    if (title.length > 150) {
      context.showTopRightSnackBar(
        'Album name must be 150 characters or less.',
        type: ToastType.error,
      );
      return;
    }

    final maxFileSizeMb = int.tryParse(_maxFileSizeCtrl.text.trim());
    if (maxFileSizeMb == null || maxFileSizeMb <= 0) {
      context.showTopRightSnackBar(
        'Max file size must be a positive number.',
        type: ToastType.error,
      );
      return;
    }

    final maxVideoDuration = int.tryParse(_maxVideoDurationCtrl.text.trim());
    final maxAudioDuration = int.tryParse(_maxAudioDurationCtrl.text.trim());

    if (!_allowPhotos && !_allowVideos && !_allowAudio) {
      context.showTopRightSnackBar(
        'Enable at least one media type: photos, videos or audio.',
        type: ToastType.error,
      );
      return;
    }

    if (_codeProtected && _accessCodeCtrl.text.trim().isNotEmpty) {
      if (_accessCodeCtrl.text.trim().length < 4) {
        context.showTopRightSnackBar(
          'Access code must be at least 4 characters.',
          type: ToastType.error,
        );
        return;
      }
    }
    if (_codeProtected &&
        !album.guestAccessCodeEnabled &&
        _accessCodeCtrl.text.trim().isEmpty) {
      context.showTopRightSnackBar(
        'Enter a new access code to enable protection.',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      String? accessCodeHash;
      final newCode = _accessCodeCtrl.text.trim();
      if (_codeProtected && newCode.isNotEmpty) {
        accessCodeHash = await _albumService.hashGuestAccessCode(newCode);
      }

      final updatedAlbum = await _albumService.updateAlbum(
        albumId: album.id,
        patch: {
          'title': title,
          'event_type_label': _eventTypeLabelCtrl.text.trim().isEmpty
              ? null
              : _eventTypeLabelCtrl.text.trim(),
          'theme_emoji': _themeEmojiCtrl.text.trim().isEmpty
              ? null
              : _themeEmojiCtrl.text.trim(),
          'theme_color': _themeColorFill.primaryHex,
          'theme_background_color': _backgroundFill.primaryHex,
          'theme_color_mode': _themeColorFill.mode.name,
          'theme_color_gradient': _themeColorFill.gradientJson,
          'theme_background_mode': _backgroundFill.mode.name,
          'theme_background_gradient': _backgroundFill.gradientJson,
          'status': _status,
          'visibility': _codeProtected ? 'code_protected' : 'public',
          'guest_access_code_enabled': _codeProtected,
          if (_codeProtected)
            'guest_access_code_hint': _accessCodeHintCtrl.text.trim().isEmpty
                ? null
                : _accessCodeHintCtrl.text.trim(),
          if (_codeProtected && accessCodeHash != null)
            'guest_access_code_hash': accessCodeHash,
          if (!_codeProtected) ...{
            'guest_access_code_hash': null,
            'guest_access_code_hint': null,
          },
        },
      );

      final updatedAlbumSettings = currentAlbumSettings.copyWith(
        allowPhotos: _allowPhotos,
        allowVideos: _allowVideos,
        allowAudio: _allowAudio,
        allowNotes: _allowNotes,
        requireGuestName: _requireGuestName,
        requireGuestEmail: _requireGuestEmail,
        allowGuestViewGallery: _allowGuestViewGallery,
        allowGuestDownloads: _allowGuestDownloads,
        showGuestNames: _showGuestNames,
        showUploadDate: _showUploadDate,
        moderationEnabled: _moderationEnabled,
        autoApproveUploads: _autoApproveUploads,
        autoApproveNotes: _autoApproveNotes,
        enableLiveGallery: _enableLiveGallery,
        enableLiveSlideshow: _enableLiveSlideshow,
        maxFileSizeMb: maxFileSizeMb,
        maxVideoDurationSeconds: maxVideoDuration,
        maxAudioDurationSeconds: maxAudioDuration,
        clearMaxVideoDurationSeconds: _maxVideoDurationCtrl.text.trim().isEmpty,
        clearMaxAudioDurationSeconds: _maxAudioDurationCtrl.text.trim().isEmpty,
      );

      await _albumSettingsService.update(
        albumId: album.id,
        settings: updatedAlbumSettings,
      );

      final updatedSlideshowSettings = currentSlideshowSettings.copyWith(
        enabled: _slideshowEnabled,
        transitionStyle: _slideshowTransitionCtrl.text.trim().isEmpty
            ? 'fade'
            : _slideshowTransitionCtrl.text.trim(),
        intervalSeconds: int.tryParse(_slideshowIntervalCtrl.text.trim()) ?? 5,
        showPhotos: _slideshowShowPhotos,
        showVideos: _slideshowShowVideos,
        showNotes: _slideshowShowNotes,
        showGuestNames: _slideshowShowGuestNames,
        showCaptions: _slideshowShowCaptions,
        onlyApprovedMedia: _slideshowOnlyApproved,
        onlyFeaturedMedia: _slideshowOnlyFeatured,
        backgroundColor: _slideshowBgColorCtrl.text.trim().isEmpty
            ? '#000000'
            : _slideshowBgColorCtrl.text.trim(),
        textColor: _slideshowTextColorCtrl.text.trim().isEmpty
            ? '#ffffff'
            : _slideshowTextColorCtrl.text.trim(),
        backgroundMusicUrl: _slideshowMusicUrlCtrl.text.trim().isEmpty
            ? null
            : _slideshowMusicUrlCtrl.text.trim(),
      );

      await _slideshowSettingsService.update(
        albumId: album.id,
        settings: updatedSlideshowSettings,
      );

      if (!mounted) return;
      setState(() {
        _album = updatedAlbum;
        _albumSettings = updatedAlbumSettings;
        _slideshowSettings = updatedSlideshowSettings;
        _accessCodeCtrl.clear();
      });

      context.showTopRightSnackBar('Settings saved.', type: ToastType.success);
    } catch (e) {
      context.showTopRightSnackBar(
        'Could not save settings: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteAlbum(Album album) async {
    if (_deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete album?'),
          content: Text(
            'This will permanently delete "${album.title}" and all related data. This action cannot be undone.',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _albumService.deleteAlbum(albumId: album.id);
      if (!mounted) return;
      context.showTopRightSnackBar('Album deleted.', type: ToastType.success);
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not delete album: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _pickAndUploadAlbumImage({required String kind}) async {
    final album = _album;
    if (album == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final extension = (file.extension ?? p.extension(file.name))
        .replaceAll('.', '')
        .toLowerCase();
    final mimeType =
        lookupMimeType(file.name, headerBytes: file.bytes) ??
        (extension == 'png'
            ? 'image/png'
            : extension == 'webp'
            ? 'image/webp'
            : 'image/jpeg');

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final storagePath = '${album.id}/${kind}_$timestamp.$extension';

    final storage = Supabase.instance.client.storage.from(
      AppConfig.albumMediaBucket,
    );

    if (kind == 'cover' &&
        (album.coverImageStoragePath ?? '').trim().isNotEmpty) {
      try {
        await storage.remove([album.coverImageStoragePath!]);
      } catch (_) {}
    }

    if (kind == 'banner' &&
        (album.bannerImageStoragePath ?? '').trim().isNotEmpty) {
      try {
        await storage.remove([album.bannerImageStoragePath!]);
      } catch (_) {}
    }

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Could not read file bytes.');
      await storage.uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: false),
      );
    } else {
      throw Exception('Image uploads are only supported on web for now.');
    }

    final url = storage.getPublicUrl(storagePath);

    final updated = await _albumService.updateAlbum(
      albumId: album.id,
      patch: kind == 'cover'
          ? {'cover_image_url': url, 'cover_image_storage_path': storagePath}
          : {'banner_image_url': url, 'banner_image_storage_path': storagePath},
    );

    if (!mounted) return;
    setState(() => _album = updated);
    context.showTopRightSnackBar(
      '${kind == 'cover' ? 'Cover' : 'Banner'} updated.',
      type: ToastType.success,
    );
  }

  Future<void> _removeAlbumImage(String kind) async {
    final album = _album;
    if (album == null) return;

    final storage = Supabase.instance.client.storage.from(
      AppConfig.albumMediaBucket,
    );

    final path = kind == 'cover'
        ? album.coverImageStoragePath
        : album.bannerImageStoragePath;
    if ((path ?? '').trim().isNotEmpty) {
      try {
        await storage.remove([path!]);
      } catch (_) {}
    }

    final updated = await _albumService.updateAlbum(
      albumId: album.id,
      patch: kind == 'cover'
          ? {'cover_image_url': null, 'cover_image_storage_path': null}
          : {'banner_image_url': null, 'banner_image_storage_path': null},
    );

    if (!mounted) return;
    setState(() => _album = updated);
    context.showTopRightSnackBar(
      '${kind == 'cover' ? 'Cover' : 'Banner'} removed.',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final album = _album;
    if (album == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Album not found.')),
      );
    }

    final uploadUrl = '${AppConfig.appPublicBaseUrl}/a/${album.slug}/upload';
    final guestPageUrl = '${AppConfig.appPublicBaseUrl}/a/${album.slug}';
    final slideshowUrl =
        '${AppConfig.appPublicBaseUrl}/slideshow/${album.slug}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final padL = compact ? 16.0 : 20.0;
        final padR = compact ? 16.0 : 24.0;
        final padT = compact ? 16.0 : 20.0;

        final listView = ListView(
          padding: EdgeInsets.fromLTRB(padL, padT, padR, 30),
          children: [
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final narrow = headerConstraints.maxWidth < 520;

                final title = const Text(
                  'Album settings',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF15151A),
                  ),
                );

                final saveButton = SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveAll,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Save changes'),
                  ),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: saveButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: title),
                    saveButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              album.title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 18),

            SaasSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Look & branding'),
                  const SizedBox(height: 10),
                  _LabeledField(
                    label: 'Album name',
                    child: TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex. Ana & Luis Wedding',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Custom event type label (optional)',
                    child: TextField(
                      controller: _eventTypeLabelCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex. Civil wedding, Sweet 15, Baptism...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Theme emoji (optional)',
                    child: TextField(
                      controller: _themeEmojiCtrl,
                      decoration: const InputDecoration(hintText: 'Ex. 💍'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Theme color (hex)',
                    child: _ColorFillTile(
                      value: _themeColorFill,
                      onEdit: () async {
                        final result = await showColorFillPickerDialog(
                          context,
                          title: 'Theme color',
                          initialValue: _themeColorFill,
                        );
                        if (result == null || !context.mounted) return;
                        setState(() => _themeColorFill = result);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Background color (hex)',
                    child: _ColorFillTile(
                      value: _backgroundFill,
                      onEdit: () async {
                        final result = await showColorFillPickerDialog(
                          context,
                          title: 'Background',
                          initialValue: _backgroundFill,
                        );
                        if (result == null || !context.mounted) return;
                        setState(() => _backgroundFill = result);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Status',
                    child: DropdownButtonFormField<String>(
                      value: _status.trim().isEmpty ? 'draft' : _status,
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                          value: 'paused',
                          child: Text('Paused'),
                        ),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('Archived'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
                      decoration: const InputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ImageTile(
                    title: 'Profile image',
                    url: album.coverImageUrl,
                    onPick: () => _pickAndUploadAlbumImage(kind: 'cover'),
                    onRemove: album.coverImageUrl == null
                        ? null
                        : () => _removeAlbumImage('cover'),
                  ),
                  const SizedBox(height: 10),
                  _ImageTile(
                    title: 'Cover image',
                    url: album.bannerImageUrl,
                    onPick: () => _pickAndUploadAlbumImage(kind: 'banner'),
                    onRemove: album.bannerImageUrl == null
                        ? null
                        : () => _removeAlbumImage('banner'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            SaasSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Visibility & access'),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Protect with access code'),
                    subtitle: const Text(
                      'Guests must enter a code to upload and view.',
                    ),
                    value: _codeProtected,
                    onChanged: (v) => setState(() => _codeProtected = v),
                  ),
                  if (_codeProtected) ...[
                    const SizedBox(height: 10),
                    _LabeledField(
                      label: 'New access code (leave blank to keep current)',
                      child: TextField(
                        controller: _accessCodeCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Min 4 characters',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LabeledField(
                      label: 'Access code hint (optional)',
                      child: TextField(
                        controller: _accessCodeHintCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex. “The couple’s initials”…',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),
            SaasSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Guest uploads'),
                  const SizedBox(height: 8),
                  Wrap(
                    runSpacing: 8,
                    spacing: 12,
                    children: [
                      _ToggleChip(
                        label: 'Photos',
                        selected: _allowPhotos,
                        onChanged: (v) => setState(() => _allowPhotos = v),
                      ),
                      _ToggleChip(
                        label: 'Videos',
                        selected: _allowVideos,
                        onChanged: (v) => setState(() => _allowVideos = v),
                      ),
                      _ToggleChip(
                        label: 'Audio',
                        selected: _allowAudio,
                        onChanged: (v) => setState(() => _allowAudio = v),
                      ),
                      _ToggleChip(
                        label: 'Notes',
                        selected: _allowNotes,
                        onChanged: (v) => setState(() => _allowNotes = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _LabeledField(
                    label: 'Max file size (MB)',
                    child: TextField(
                      controller: _maxFileSizeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '500'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Max video duration (seconds, optional)',
                    child: TextField(
                      controller: _maxVideoDurationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Ex. 60'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Max audio duration (seconds, optional)',
                    child: TextField(
                      controller: _maxAudioDurationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Ex. 30'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Require guest name'),
                    value: _requireGuestName,
                    onChanged: (v) => setState(() => _requireGuestName = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Require guest email'),
                    value: _requireGuestEmail,
                    onChanged: (v) => setState(() => _requireGuestEmail = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow guests to view gallery'),
                    value: _allowGuestViewGallery,
                    onChanged: (v) =>
                        setState(() => _allowGuestViewGallery = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow guest downloads'),
                    value: _allowGuestDownloads,
                    onChanged: (v) => setState(() => _allowGuestDownloads = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show guest names'),
                    value: _showGuestNames,
                    onChanged: (v) => setState(() => _showGuestNames = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show upload date'),
                    value: _showUploadDate,
                    onChanged: (v) => setState(() => _showUploadDate = v),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable live gallery'),
                    value: _enableLiveGallery,
                    onChanged: (v) => setState(() => _enableLiveGallery = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable live slideshow'),
                    value: _enableLiveSlideshow,
                    onChanged: (v) => setState(() => _enableLiveSlideshow = v),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 24),
                  const _SectionTitle('Moderation'),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable moderation'),
                    subtitle: const Text(
                      'When enabled, uploads/notes can be pending approval.',
                    ),
                    value: _moderationEnabled,
                    onChanged: (v) => setState(() => _moderationEnabled = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-approve uploads'),
                    value: _autoApproveUploads,
                    onChanged: (v) => setState(() => _autoApproveUploads = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-approve notes'),
                    value: _autoApproveNotes,
                    onChanged: (v) => setState(() => _autoApproveNotes = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            SaasSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Slideshow'),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enabled'),
                    value: _slideshowEnabled,
                    onChanged: (v) => setState(() => _slideshowEnabled = v),
                  ),
                  const SizedBox(height: 10),
                  _LabeledField(
                    label: 'Interval (seconds)',
                    child: TextField(
                      controller: _slideshowIntervalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '5'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Transition style',
                    child: DropdownButtonFormField<String>(
                      value:
                          (_slideshowTransitionCtrl.text.trim().isEmpty
                                  ? 'fade'
                                  : _slideshowTransitionCtrl.text.trim())
                              .toLowerCase(),
                      items: const [
                        DropdownMenuItem(value: 'fade', child: Text('Fade')),
                        DropdownMenuItem(value: 'slide', child: Text('Slide')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _slideshowTransitionCtrl.text = value;
                        setState(() {});
                      },
                      decoration: const InputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    runSpacing: 8,
                    spacing: 12,
                    children: [
                      _ToggleChip(
                        label: 'Photos',
                        selected: _slideshowShowPhotos,
                        onChanged: (v) =>
                            setState(() => _slideshowShowPhotos = v),
                      ),
                      _ToggleChip(
                        label: 'Videos',
                        selected: _slideshowShowVideos,
                        onChanged: (v) =>
                            setState(() => _slideshowShowVideos = v),
                      ),
                      _ToggleChip(
                        label: 'Notes',
                        selected: _slideshowShowNotes,
                        onChanged: (v) =>
                            setState(() => _slideshowShowNotes = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show guest names'),
                    value: _slideshowShowGuestNames,
                    onChanged: (v) =>
                        setState(() => _slideshowShowGuestNames = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show captions'),
                    value: _slideshowShowCaptions,
                    onChanged: (v) =>
                        setState(() => _slideshowShowCaptions = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only approved media'),
                    value: _slideshowOnlyApproved,
                    onChanged: (v) =>
                        setState(() => _slideshowOnlyApproved = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only featured media'),
                    value: _slideshowOnlyFeatured,
                    onChanged: (v) =>
                        setState(() => _slideshowOnlyFeatured = v),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Background color',
                    child: _ColorFillTile(
                      value: _slideshowBackgroundFill,
                      onEdit: () async {
                        final result = await showColorFillPickerDialog(
                          context,
                          title: 'Slideshow background',
                          initialValue: _slideshowBackgroundFill,
                        );
                        if (result == null || !context.mounted) return;
                        setState(() {
                          _slideshowBackgroundFill = ColorFillValue.solid(
                            result.primaryColor,
                          );
                          _slideshowBgColorCtrl.text =
                              _slideshowBackgroundFill.primaryHex;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Text color',
                    child: _ColorFillTile(
                      value: _slideshowTextFill,
                      onEdit: () async {
                        final result = await showColorFillPickerDialog(
                          context,
                          title: 'Slideshow text',
                          initialValue: _slideshowTextFill,
                        );
                        if (result == null || !context.mounted) return;
                        setState(() {
                          _slideshowTextFill = ColorFillValue.solid(
                            result.primaryColor,
                          );
                          _slideshowTextColorCtrl.text =
                              _slideshowTextFill.primaryHex;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Background music URL (optional)',
                    child: TextField(
                      controller: _slideshowMusicUrlCtrl,
                      decoration: const InputDecoration(
                        hintText: 'https://...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LinkRow(label: 'Guest page', value: guestPageUrl),
                  _LinkRow(label: 'Upload page', value: uploadUrl),
                  _LinkRow(label: 'Slideshow', value: slideshowUrl),
                ],
              ),
            ),

            const SizedBox(height: 14),
            SaasSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Danger zone'),
                  const SizedBox(height: 10),
                  Text(
                    'Delete this album and all related data.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      onPressed: (_saving || _deleting)
                          ? null
                          : () => _confirmDeleteAlbum(album),
                      label: Text(_deleting ? 'Deleting...' : 'Delete album'),
                    ),
                  ),
                ],
              ),
            ),

            // Share links/tokens + QR removed (requested).
          ],
        );

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: compact
              ? AppBar(
                  title: const Text('Album settings'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go('/album/${album.id}'),
                    tooltip: 'Back',
                  ),
                  actions: [
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'guest') context.go('/a/${album.slug}');
                        if (value == 'slideshow') {
                          context.push(
                            '/slideshow/${album.slug}?next=/album/${album.id}/settings',
                          );
                        }
                      },
                      itemBuilder: (context) {
                        return const [
                          PopupMenuItem(
                            value: 'guest',
                            child: Text('Open guest page'),
                          ),
                          PopupMenuItem(
                            value: 'slideshow',
                            child: Text('Open slideshow'),
                          ),
                        ];
                      },
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            child: compact
                ? listView
                : Row(
                    children: [
                      _Sidebar(
                        onBack: () => context.go('/album/${album.id}'),
                        onGuestPage: () => context.go('/a/${album.slug}'),
                        onSlideshow: () => context.push(
                          '/slideshow/${album.slug}?next=/album/${album.id}/settings',
                        ),
                      ),
                      Expanded(child: listView),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.onBack,
    required this.onGuestPage,
    required this.onSlideshow,
  });

  final VoidCallback onBack;
  final VoidCallback onGuestPage;
  final VoidCallback onSlideshow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 2),
          LogoMark(size: 44, onTap: onBack),
          const SizedBox(height: 26),
          _NavButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            label: 'Back',
            onTap: onBack,
          ),
          const SizedBox(height: 12),
          _NavButton(
            icon: Icons.public_rounded,
            tooltip: 'Guest page',
            label: 'Guest page',
            onTap: onGuestPage,
          ),
          const SizedBox(height: 12),
          _NavButton(
            icon: Icons.slideshow_rounded,
            tooltip: 'Slideshow',
            label: 'Slideshow',
            onTap: onSlideshow,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(icon, size: 22, color: const Color(0xFF15151A)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15151A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.55,
        color: Colors.black.withOpacity(0.46),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.black.withOpacity(0.58),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ColorFillTile extends StatelessWidget {
  const _ColorFillTile({required this.value, required this.onEdit});

  final ColorFillValue value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final preview = value.mode == ColorFillMode.solid
        ? BoxDecoration(
            color: value.primaryColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            gradient: LinearGradient(
              begin: _angleToBeginEnd(value.gradient!.angleDegrees).$1,
              end: _angleToBeginEnd(value.gradient!.angleDegrees).$2,
              colors: value.gradient!.colors,
            ),
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECECF0)),
          ),
          child: Row(
            children: [
              Container(width: 44, height: 34, decoration: preview),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.mode == ColorFillMode.solid
                      ? value.primaryHex
                      : 'Gradient: ${value.gradient!.colors.map(_colorToHex).join(' → ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.palette_outlined, size: 18),
                label: const Text('Pick'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _colorToHex(Color color) {
  final value = color.value & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

(Alignment, Alignment) _angleToBeginEnd(double angleDegrees) {
  final a = (angleDegrees % 360) * (math.pi / 180.0);
  final dx = math.cos(a);
  final dy = math.sin(a);

  final begin = Alignment(-dx, -dy);
  final end = Alignment(dx, dy);
  return (begin, end);
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: onChanged,
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          final labelWidget = Text(
            label,
            style: TextStyle(color: Colors.black.withOpacity(0.6)),
          );
          final valueWidget = SelectableText(
            value,
            maxLines: compact ? 2 : 1,
            style: const TextStyle(fontWeight: FontWeight.w600),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget],
            );
          }

          return Row(
            children: [
              SizedBox(width: 110, child: labelWidget),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.title,
    required this.url,
    required this.onPick,
    required this.onRemove,
  });

  final String title;
  final String? url;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = (url ?? '').trim().isNotEmpty;

    final preview = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) {
                return const Center(child: Icon(Icons.broken_image_outlined));
              },
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                );
              },
            )
          : const Center(
              child: Icon(Icons.image_outlined, color: Color(0xFF6A6A74)),
            ),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          hasImage ? 'Selected' : 'Not set',
          style: TextStyle(color: Colors.black.withOpacity(0.55)),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton(
          onPressed: onPick,
          child: Text(hasImage ? 'Replace' : 'Upload'),
        ),
        OutlinedButton(onPressed: onRemove, child: const Text('Remove')),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECF0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    preview,
                    const SizedBox(width: 12),
                    Expanded(child: titleBlock),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Row(
            children: [
              preview,
              const SizedBox(width: 12),
              Expanded(child: titleBlock),
              actions,
            ],
          );
        },
      ),
    );
  }
}
