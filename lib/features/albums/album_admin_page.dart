// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../models/album.dart';
import '../../models/note.dart';
import '../../services/album_export_service.dart';
import '../../services/album_service.dart';
import '../../shared/ui/app_snackbars.dart';
import '../../shared/ui/color_utils.dart';
import '../../shared/ui/event_icons.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/logo_mark.dart';

class AlbumAdminPage extends StatefulWidget {
  const AlbumAdminPage({super.key, required this.albumId});

  final String albumId;

  @override
  State<AlbumAdminPage> createState() => _AlbumAdminPageState();
}

class _AlbumAdminPageState extends State<AlbumAdminPage> {
  final _albumService = AlbumService();
  final _exportService = AlbumExportService();
  final _mediaRepository = _AdminMediaRepository();
  GlobalKey<_AdminMemoriesManagerState> _memoriesManagerKey =
      GlobalKey<_AdminMemoriesManagerState>();
  GlobalKey _qrKey = GlobalKey();

  late Future<Album> _albumFuture;
  late Future<List<Album>> _albumsFuture;

  bool _mediaBusy = false;
  bool _qrBusy = false;
  bool _exportBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AlbumAdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.albumId != widget.albumId) {
      _memoriesManagerKey = GlobalKey<_AdminMemoriesManagerState>();
      _qrKey = GlobalKey();
      _mediaBusy = false;
      _qrBusy = false;
      setState(_load);
    }
  }

  void _load() {
    _albumFuture = _albumService.getAlbumById(widget.albumId);
    _albumsFuture = _albumService.getMyAlbums();
  }

  void _reload() {
    setState(_load);
    _memoriesManagerKey.currentState?.reload();
  }

  Future<void> _pickAndUploadMedia(Album album) async {
    if (_mediaBusy) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _AdminMediaRepository.allowedExtensions,
      withData: true,
    );

    if (result == null) return;

    final validFiles = result.files
        .where(_mediaRepository.isAllowedMediaFile)
        .toList();

    final invalidFiles = result.files
        .where((file) => !_mediaRepository.isAllowedMediaFile(file))
        .map((file) => file.name)
        .toList();

    if (invalidFiles.isNotEmpty && mounted) {
      _showSnack(
        'Only image and video files are allowed. Rejected: ${invalidFiles.join(', ')}',
        type: ToastType.error,
      );
    }

    if (validFiles.isEmpty) return;

    setState(() => _mediaBusy = true);

    try {
      for (final file in validFiles) {
        await _mediaRepository.uploadAdminMedia(
          albumId: album.id,
          pickedFile: file,
        );
      }

      await _mediaRepository.refreshAlbumCounters(album.id);

      if (!mounted) return;

      _showSnack(
        validFiles.length == 1
            ? 'Media uploaded successfully.'
            : '${validFiles.length} files uploaded successfully.',
        type: ToastType.success,
      );

      _reload();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Upload failed: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _editAlbumTitle(Album album) async {
    final ctrl = TextEditingController(text: album.title);

    final nextTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit album name'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Album name'),
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
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    ctrl.dispose();

    final value = (nextTitle ?? '').trim();
    if (value.isEmpty || value == album.title) return;

    if (value.length > 150) {
      _showSnack(
        'Album name must be 150 characters or less.',
        type: ToastType.error,
      );
      return;
    }

    try {
      await _albumService.updateAlbum(
        albumId: album.id,
        patch: {'title': value},
      );
      if (!mounted) return;
      _showSnack('Album name updated.', type: ToastType.success);
      _reload();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not update album name: $e', type: ToastType.error);
    }
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    _showSnack('Upload link copied.', type: ToastType.success);
  }

  Future<void> _downloadQrPng(Album album) async {
    if (_qrBusy) return;

    setState(() => _qrBusy = true);

    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('QR image is not ready yet.');
      }

      final image = await boundary.toImage(pixelRatio: 4);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Could not generate QR image.');
      }

      final bytes = byteData.buffer.asUint8List();
      final fileName = _safeFileName('${album.slug}-upload-qr.png');

      _downloadBytesAsFile(bytes, fileName, 'image/png');

      if (!mounted) return;
      _showSnack('QR downloaded.', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not download QR: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _qrBusy = false);
    }
  }

  void _downloadBytesAsFile(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  void _showSnack(String message, {ToastType type = ToastType.info}) {
    context.showTopRightSnackBar(message, type: type);
  }

  Future<void> _exportZip(Album album) async {
    if (_exportBusy) return;
    setState(() => _exportBusy = true);

    try {
      _showSnack('Preparing ZIP export...', type: ToastType.info);
      final uri = await _exportService.exportAlbumZip(albumId: album.id);
      await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!mounted) return;
      _showSnack('Export started.', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not export album: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Album>(
        future: _albumFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          if (snapshot.hasError) {
            return ErrorView(message: snapshot.error.toString());
          }

          final album = snapshot.data!;
          final uploadUrl = _albumService.publicUploadUrl(album.slug);

          return LayoutBuilder(
            builder: (context, constraints) {
              final compactOuter = constraints.maxWidth < 900;
              final padL = compactOuter ? 16.0 : 20.0;
              final padR = compactOuter ? 16.0 : 24.0;

              final scrollView = CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padL, 20, padR, 0),
                      child: FutureBuilder<List<Album>>(
                        future: _albumsFuture,
                        builder: (context, albumsSnapshot) {
                          final albums = albumsSnapshot.data ?? const <Album>[];

                          return _AdminTopBar(
                            album: album,
                            albums: albums,
                            onAlbumChanged: (nextAlbumId) {
                              if (nextAlbumId == null ||
                                  nextAlbumId == album.id) {
                                return;
                              }

                              context.go('/album/$nextAlbumId');
                            },
                            onDashboard: () => context.go('/'),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padL, 18, padR, 0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 980;

                          if (compact) {
                            return Column(
                              children: [
                                _AlbumMainPanel(
                                  album: album,
                                  mediaBusy: _mediaBusy,
                                  exportBusy: _exportBusy,
                                  onAddMedia: () => _pickAndUploadMedia(album),
                                  onEditTitle: () => _editAlbumTitle(album),
                                  onOpenSettings: () =>
                                      context.go('/album/${album.id}/settings'),
                                  onCopyLink: () => _copyLink(uploadUrl),
                                  onShareLink: () => Share.share(uploadUrl),
                                  onExportZip: () => _exportZip(album),
                                  onOpenSlideshow: () {
                                    context.go('/slideshow/${album.slug}');
                                  },
                                ),
                                const SizedBox(height: 18),
                                _QrSharePanel(
                                  qrKey: _qrKey,
                                  uploadUrl: uploadUrl,
                                  qrBusy: _qrBusy,
                                  onCopyLink: () => _copyLink(uploadUrl),
                                  onShareLink: () => Share.share(uploadUrl),
                                  onDownloadQr: () => _downloadQrPng(album),
                                  onOpenGuestPage: () {
                                    context.go('/a/${album.slug}');
                                  },
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _AlbumMainPanel(
                                  album: album,
                                  mediaBusy: _mediaBusy,
                                  exportBusy: _exportBusy,
                                  onAddMedia: () => _pickAndUploadMedia(album),
                                  onEditTitle: () => _editAlbumTitle(album),
                                  onOpenSettings: () =>
                                      context.go('/album/${album.id}/settings'),
                                  onCopyLink: () => _copyLink(uploadUrl),
                                  onShareLink: () => Share.share(uploadUrl),
                                  onExportZip: () => _exportZip(album),
                                  onOpenSlideshow: () {
                                    context.go('/slideshow/${album.slug}');
                                  },
                                ),
                              ),
                              const SizedBox(width: 18),
                              SizedBox(
                                width: 308,
                                child: _QrSharePanel(
                                  qrKey: _qrKey,
                                  uploadUrl: uploadUrl,
                                  qrBusy: _qrBusy,
                                  onCopyLink: () => _copyLink(uploadUrl),
                                  onShareLink: () => Share.share(uploadUrl),
                                  onDownloadQr: () => _downloadQrPng(album),
                                  onOpenGuestPage: () {
                                    context.go('/a/${album.slug}');
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padL, 26, padR, 12),
                      child: _ContentHeader(
                        subtitle:
                            'Review and manage photos, videos, audios, and notes from this album.',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padL, 0, padR, 32),
                      child: _AdminMemoriesManager(
                        key: _memoriesManagerKey,
                        albumId: album.id,
                        onChanged: _reload,
                      ),
                    ),
                  ),
                ],
              );

              return SafeArea(
                child: compactOuter
                    ? scrollView
                    : Row(
                        children: [
                          _AlbumSidebar(
                            onDashboard: () => context.go('/'),
                            onPublicAlbum: () => context.go('/a/${album.slug}'),
                            onSlideshow: () =>
                                context.go('/slideshow/${album.slug}'),
                            onSettings: () =>
                                context.go('/album/${album.id}/settings'),
                          ),
                          Expanded(child: scrollView),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AlbumSidebar extends StatelessWidget {
  const _AlbumSidebar({
    required this.onDashboard,
    required this.onPublicAlbum,
    required this.onSlideshow,
    required this.onSettings,
  });

  final VoidCallback onDashboard;
  final VoidCallback onPublicAlbum;
  final VoidCallback onSlideshow;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 2),
          const LogoMark(size: 44),
          const SizedBox(height: 26),
          _NavButton(
            icon: Icons.dashboard_rounded,
            tooltip: 'Dashboard',
            onTap: onDashboard,
          ),
          const SizedBox(height: 12),
          _NavButton(
            icon: Icons.public_rounded,
            tooltip: 'Guest page',
            onTap: onPublicAlbum,
          ),
          const SizedBox(height: 12),
          _NavButton(
            icon: Icons.slideshow_rounded,
            tooltip: 'Slideshow',
            onTap: onSlideshow,
          ),
          const SizedBox(height: 12),
          _NavButton(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            onTap: onSettings,
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
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 44,
          child: Center(
            child: Icon(icon, size: 22, color: const Color(0xFF15151A)),
          ),
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.album,
    required this.albums,
    required this.onAlbumChanged,
    required this.onDashboard,
  });

  final Album album;
  final List<Album> albums;
  final ValueChanged<String?> onAlbumChanged;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    final hasCurrentAlbum = albums.any((item) => item.id == album.id);

    final safeAlbums = hasCurrentAlbum
        ? albums
        : [album, ...albums.where((item) => item.id != album.id)];

    final showSwitcher = safeAlbums.length > 1;

    return _Surface(
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SoftLabel(
                  icon: Icons.admin_panel_settings_outlined,
                  text: 'ADMIN PANEL',
                ),
                const SizedBox(height: 12),
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF15151A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (showSwitcher)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: _AlbumSwitcher(
                            currentAlbumId: album.id,
                            albums: safeAlbums,
                            onChanged: onAlbumChanged,
                          ),
                        ),
                      )
                    else
                      const _SingleAlbumPill(),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 136,
                      height: 44,
                      child: _DashboardButton(onPressed: onDashboard),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              const _SoftLabel(
                icon: Icons.admin_panel_settings_outlined,
                text: 'ADMIN PANEL',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF15151A),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              if (showSwitcher)
                SizedBox(
                  width: 260,
                  height: 44,
                  child: _AlbumSwitcher(
                    currentAlbumId: album.id,
                    albums: safeAlbums,
                    onChanged: onAlbumChanged,
                  ),
                )
              else
                const _SingleAlbumPill(),
              const SizedBox(width: 12),
              SizedBox(
                width: 136,
                height: 44,
                child: _DashboardButton(onPressed: onDashboard),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  const _DashboardButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('Dashboard', overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF15151A),
        side: const BorderSide(color: Color(0xFFE5E5EA)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 44),
        fixedSize: const Size(136, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _AlbumSwitcher extends StatelessWidget {
  const _AlbumSwitcher({
    required this.currentAlbumId,
    required this.albums,
    required this.onChanged,
  });

  final String currentAlbumId;
  final List<Album> albums;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = albums.any((item) => item.id == currentAlbumId)
        ? currentAlbumId
        : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFF111111), width: 1.2),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      hint: const Text('Select album', overflow: TextOverflow.ellipsis),
      items: albums.map((item) {
        return DropdownMenuItem<String>(
          value: item.id,
          child: Text(
            item.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF15151A),
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _SingleAlbumPill extends StatelessWidget {
  const _SingleAlbumPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: const Text(
        'Single album',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF15151A),
        ),
      ),
    );
  }
}

class _AlbumMainPanel extends StatelessWidget {
  const _AlbumMainPanel({
    required this.album,
    required this.mediaBusy,
    required this.exportBusy,
    required this.onAddMedia,
    required this.onEditTitle,
    required this.onOpenSettings,
    required this.onCopyLink,
    required this.onShareLink,
    required this.onExportZip,
    required this.onOpenSlideshow,
  });

  final Album album;
  final bool mediaBusy;
  final bool exportBusy;
  final VoidCallback onAddMedia;
  final VoidCallback onEditTitle;
  final VoidCallback onOpenSettings;
  final VoidCallback onCopyLink;
  final VoidCallback onShareLink;
  final VoidCallback onExportZip;
  final VoidCallback onOpenSlideshow;

  @override
  Widget build(BuildContext context) {
    final description = album.description?.trim();
    final accent = (album.themeColor).toColorOr(
      Theme.of(context).colorScheme.primary,
    );

    return _Surface(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SoftLabel(
            icon: Icons.photo_album_outlined,
            text: 'ALBUM OVERVIEW',
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                iconForEventType(album.eventType),
                size: 36,
                color: accent.mix(const Color(0xFF111116), 0.08),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            album.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 31,
                              height: 1.02,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: Color(0xFF15151A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: OutlinedButton(
                            onPressed: onEditTitle,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Icon(Icons.edit_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: OutlinedButton(
                            onPressed: onOpenSettings,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Icon(
                              Icons.settings_outlined,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description == null || description.isEmpty
                          ? 'Your album is ready to receive guest memories.'
                          : description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.48),
                        fontSize: 14.5,
                        height: 1.38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isCompact = width < 520;
              final itemWidth = isCompact ? (width - 10) / 2 : (width - 30) / 4;

              Widget box(_CompactStat stat) =>
                  SizedBox(width: itemWidth, child: stat);

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  box(
                    _CompactStat(
                      label: 'Photos',
                      value: '${album.totalPhotos}',
                      icon: Icons.photo_outlined,
                    ),
                  ),
                  box(
                    _CompactStat(
                      label: 'Videos',
                      value: '${album.totalVideos}',
                      icon: Icons.videocam_outlined,
                    ),
                  ),
                  box(
                    _CompactStat(
                      label: 'Audios',
                      value: '${album.totalAudios}',
                      icon: Icons.audiotrack_outlined,
                    ),
                  ),
                  box(
                    _CompactStat(
                      label: 'Notes',
                      value: '${album.totalNotes}',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: _PrimaryActionButton(
              text: mediaBusy ? 'Uploading...' : 'Add photos or videos',
              icon: Icons.add_photo_alternate_outlined,
              onPressed: mediaBusy ? null : onAddMedia,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final children = [
                _MiniActionButton(
                  icon: Icons.content_copy_rounded,
                  label: 'Copy link',
                  onPressed: onCopyLink,
                ),
                _MiniActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share link',
                  onPressed: onShareLink,
                ),
                _MiniActionButton(
                  icon: Icons.archive_outlined,
                  label: exportBusy ? 'Exporting...' : 'Export ZIP',
                  onPressed: exportBusy ? null : onExportZip,
                ),
                _MiniActionButton(
                  icon: Icons.slideshow_rounded,
                  label: 'Slideshow',
                  onPressed: onOpenSlideshow,
                ),
              ];

              if (compact) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final child in children)
                      SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: child,
                      ),
                  ],
                );
              }

              return Row(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    Expanded(child: children[i]),
                    if (i != children.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QrSharePanel extends StatelessWidget {
  const _QrSharePanel({
    required this.qrKey,
    required this.uploadUrl,
    required this.qrBusy,
    required this.onCopyLink,
    required this.onShareLink,
    required this.onDownloadQr,
    required this.onOpenGuestPage,
  });

  final GlobalKey qrKey;
  final String uploadUrl;
  final bool qrBusy;
  final VoidCallback onCopyLink;
  final VoidCallback onShareLink;
  final VoidCallback onDownloadQr;
  final VoidCallback onOpenGuestPage;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          const _SoftLabel(icon: Icons.qr_code_2_rounded, text: 'UPLOAD QR'),
          const SizedBox(height: 14),
          RepaintBoundary(
            key: qrKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: uploadUrl,
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Guests scan this QR to upload memories.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.50),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: _PrimaryActionButton(
              text: qrBusy ? 'Downloading...' : 'Download QR',
              icon: Icons.download_rounded,
              onPressed: qrBusy ? null : onDownloadQr,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: _SecondaryActionButton(
              text: 'Copy upload link',
              icon: Icons.content_copy_rounded,
              onPressed: onCopyLink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: _SecondaryActionButton(
                    text: 'Share link',
                    icon: Icons.share_rounded,
                    onPressed: onShareLink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: _SecondaryActionButton(
                    text: 'Guest page',
                    icon: Icons.public_rounded,
                    onPressed: onOpenGuestPage,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF15151A)),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF15151A),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.44),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SoftLabel(
          icon: Icons.photo_library_outlined,
          text: 'ALBUM CONTENT',
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black.withOpacity(0.46),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

enum _AdminMemoriesTab { photos, videos, audios, notes }

class _AdminMemoriesManager extends StatefulWidget {
  const _AdminMemoriesManager({
    super.key,
    required this.albumId,
    required this.onChanged,
  });

  final String albumId;
  final VoidCallback onChanged;

  @override
  State<_AdminMemoriesManager> createState() => _AdminMemoriesManagerState();
}

class _AdminMemoriesManagerState extends State<_AdminMemoriesManager> {
  final _mediaRepository = _AdminMediaRepository();
  final _notesRepository = _AdminNotesRepository();

  _AdminMemoriesTab _tab = _AdminMemoriesTab.photos;

  late Future<List<_AdminMediaItem>> _mediaFuture;
  late Future<List<MemoryNote>> _notesFuture;

  bool _deleting = false;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _mediaFuture = _mediaRepository.getAlbumMedia(widget.albumId);
    _notesFuture = _notesRepository.getAlbumNotes(widget.albumId);
  }

  void reload() {
    if (!mounted) return;
    setState(() {
      _mediaFuture = _mediaRepository.getAlbumMedia(widget.albumId);
      _notesFuture = _notesRepository.getAlbumNotes(widget.albumId);
    });
  }

  List<_AdminMediaItem> _filterMedia(List<_AdminMediaItem> items) {
    return switch (_tab) {
      _AdminMemoriesTab.photos =>
        items.where((e) => e.type == 'photo').toList(),
      _AdminMemoriesTab.videos =>
        items.where((e) => e.type == 'video').toList(),
      _AdminMemoriesTab.audios =>
        items.where((e) => e.type == 'audio').toList(),
      _AdminMemoriesTab.notes => const <_AdminMediaItem>[],
    };
  }

  Future<void> _deleteMedia(_AdminMediaItem item) async {
    if (_deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _DeleteMediaDialog(
          fileName: item.originalFileName ?? 'this file',
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await _mediaRepository.deleteMedia(item);
      await _mediaRepository.refreshAlbumCounters(widget.albumId);
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Media deleted successfully.',
        type: ToastType.success,
      );
      widget.onChanged();
      reload();
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not delete media: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _approveMedia(_AdminMediaItem item) async {
    if (_updating || item.status.toLowerCase() == 'approved') return;
    setState(() => _updating = true);
    try {
      await _mediaRepository.updateMedia(
        id: item.id,
        patch: {
          'status': 'approved',
          'approved_at': DateTime.now().toIso8601String(),
        },
      );
      await _mediaRepository.refreshAlbumCounters(widget.albumId);
      if (!mounted) return;
      context.showTopRightSnackBar('Media approved.', type: ToastType.success);
      widget.onChanged();
      reload();
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not approve media: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _toggleMediaHidden(_AdminMediaItem item) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await _mediaRepository.updateMedia(
        id: item.id,
        patch: {'is_hidden': !item.isHidden},
      );
      await _mediaRepository.refreshAlbumCounters(widget.albumId);
      if (!mounted) return;
      widget.onChanged();
      reload();
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not update media: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _toggleMediaFeatured(_AdminMediaItem item) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await _mediaRepository.updateMedia(
        id: item.id,
        patch: {'is_featured': !item.isFeatured},
      );
      if (!mounted) return;
      reload();
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not update media: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _deleteNote(MemoryNote note) async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _DeleteNoteDialog(message: note.message);
      },
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await _notesRepository.deleteNote(note.id);
      await _mediaRepository.refreshAlbumCounters(widget.albumId);
      if (!mounted) return;
      context.showTopRightSnackBar('Note deleted.', type: ToastType.success);
      widget.onChanged();
      reload();
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not delete note: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _approveNote(MemoryNote note) async {
    if (_updating || note.status.toLowerCase() == 'approved') return;
    setState(() => _updating = true);
    try {
      await _notesRepository.updateNote(
        id: note.id,
        patch: {
          'status': 'approved',
          'approved_at': DateTime.now().toIso8601String(),
        },
      );
      await _mediaRepository.refreshAlbumCounters(widget.albumId);
      if (!mounted) return;
      context.showTopRightSnackBar('Note approved.', type: ToastType.success);
      widget.onChanged();
      reload();
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not approve note: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _toggleNoteHidden(MemoryNote note) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await _notesRepository.updateNote(
        id: note.id,
        patch: {'is_hidden': !note.isHidden},
      );
      await _mediaRepository.refreshAlbumCounters(widget.albumId);
      if (!mounted) return;
      widget.onChanged();
      reload();
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not update note: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _toggleNoteFeatured(MemoryNote note) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await _notesRepository.updateNote(
        id: note.id,
        patch: {'is_featured': !note.isFeatured},
      );
      if (!mounted) return;
      reload();
    } catch (e) {
      if (!mounted) return;
      context.showTopRightSnackBar(
        'Could not update note: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AdminMemoriesTabs(
            selected: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          if (_tab == _AdminMemoriesTab.notes)
            FutureBuilder<List<MemoryNote>>(
              future: _notesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 220, child: LoadingView());
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(18),
                    child: ErrorView(message: snapshot.error.toString()),
                  );
                }

                final notes = snapshot.data ?? const <MemoryNote>[];
                if (notes.isEmpty) {
                  return const _EmptyNotesState();
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notes.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return _AdminNoteCard(
                      note: note,
                      busy: _deleting || _updating,
                      onDelete: () => _deleteNote(note),
                      onApprove: note.status.toLowerCase() == 'approved'
                          ? null
                          : () => _approveNote(note),
                      onToggleHidden: () => _toggleNoteHidden(note),
                      onToggleFeatured: () => _toggleNoteFeatured(note),
                    );
                  },
                );
              },
            )
          else
            FutureBuilder<List<_AdminMediaItem>>(
              future: _mediaFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 220, child: LoadingView());
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(18),
                    child: ErrorView(message: snapshot.error.toString()),
                  );
                }

                final items = _filterMedia(
                  snapshot.data ?? const <_AdminMediaItem>[],
                );
                if (items.isEmpty) {
                  return const _EmptyMediaState();
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 230,
                    mainAxisExtent: 246,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _AdminMediaCard(
                      item: item,
                      busy: _deleting || _updating,
                      onDelete: () => _deleteMedia(item),
                      onApprove: item.status.toLowerCase() == 'approved'
                          ? null
                          : () => _approveMedia(item),
                      onToggleHidden: () => _toggleMediaHidden(item),
                      onToggleFeatured: () => _toggleMediaFeatured(item),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DeleteMediaDialog extends StatelessWidget {
  const _DeleteMediaDialog({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete media?'),
      content: Text(
        'This will remove "$fileName" from the album. This action cannot be undone.',
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF15151A),
                  side: const BorderSide(color: Color(0xFFE5E5EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD92D20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminMemoriesTabs extends StatelessWidget {
  const _AdminMemoriesTabs({required this.selected, required this.onChanged});

  final _AdminMemoriesTab selected;
  final ValueChanged<_AdminMemoriesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final specs = const [
      (_AdminMemoriesTab.photos, Icons.photo_outlined, 'Photos'),
      (_AdminMemoriesTab.videos, Icons.videocam_outlined, 'Videos'),
      (_AdminMemoriesTab.audios, Icons.mic_none_outlined, 'Audios'),
      (_AdminMemoriesTab.notes, Icons.sticky_note_2_outlined, 'Notes'),
    ];

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < specs.length; i++)
            Expanded(
              child: _AdminTabButton(
                selected: selected == specs[i].$1,
                icon: specs[i].$2,
                label: specs[i].$3,
                onTap: () => onChanged(specs[i].$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminTabButton extends StatelessWidget {
  const _AdminTabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: double.infinity,
        color: selected ? Colors.black : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10),
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

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sticky_note_2_outlined, size: 34),
          const SizedBox(height: 10),
          const Text(
            'No notes yet.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Guest notes will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.50),
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteNoteDialog extends StatelessWidget {
  const _DeleteNoteDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final trimmed = message.trim();
    final preview = trimmed.length > 90
        ? '${trimmed.substring(0, 90)}…'
        : trimmed;

    return AlertDialog(
      title: const Text('Delete note?'),
      content: Text(
        'This will remove the note from the album. This action cannot be undone.\n\n“$preview”',
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF15151A),
                  side: const BorderSide(color: Color(0xFFE5E5EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD92D20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminNoteCard extends StatelessWidget {
  const _AdminNoteCard({
    required this.note,
    required this.busy,
    required this.onDelete,
    required this.onApprove,
    required this.onToggleHidden,
    required this.onToggleFeatured,
  });

  final MemoryNote note;
  final bool busy;
  final VoidCallback onDelete;
  final VoidCallback? onApprove;
  final VoidCallback onToggleHidden;
  final VoidCallback onToggleFeatured;

  @override
  Widget build(BuildContext context) {
    final isApproved = note.status.toLowerCase() == 'approved';
    final title = note.message.trim().isEmpty ? 'Note' : note.message.trim();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB).withOpacity(.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showDialog<void>(
              context: context,
              barrierColor: Colors.black.withOpacity(0.82),
              builder: (context) => _AdminNoteViewerDialog(note: note),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypePill(type: 'note'),
                    const Spacer(),
                    if (!isApproved)
                      _StatusPillSmall(
                        text: note.status,
                        color: const Color(0xFFB42318),
                      )
                    else
                      const _StatusPillSmall(
                        text: 'approved',
                        color: Color(0xFF12B76A),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15151A),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: busy ? null : onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    IconButton(
                      tooltip: note.isHidden ? 'Unhide' : 'Hide',
                      onPressed: busy ? null : onToggleHidden,
                      icon: Icon(
                        note.isHidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                    IconButton(
                      tooltip: note.isFeatured ? 'Unfeature' : 'Feature',
                      onPressed: busy ? null : onToggleFeatured,
                      icon: Icon(
                        note.isFeatured
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                    ),
                    const Spacer(),
                    if (onApprove != null)
                      FilledButton.icon(
                        onPressed: busy ? null : onApprove,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNoteViewerDialog extends StatelessWidget {
  const _AdminNoteViewerDialog({required this.note});

  final MemoryNote note;

  Future<_AdminGuestInfo?> _loadGuestInfo() async {
    final guestId = note.guestId;
    if (guestId == null || guestId.trim().isEmpty) return null;

    final row = await Supabase.instance.client
        .from('guests')
        .select('name, email')
        .eq('id', guestId)
        .maybeSingle();

    if (row == null) return null;
    return _AdminGuestInfo(
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
              child: FutureBuilder<_AdminGuestInfo?>(
                future: _loadGuestInfo(),
                builder: (context, snapshot) {
                  final uploadedBy = (note.guestId == null)
                      ? 'Admin'
                      : (snapshot.data?.displayName ?? 'Guest');

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
                          'Uploaded by $uploadedBy',
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

class _AdminMediaCard extends StatelessWidget {
  const _AdminMediaCard({
    required this.item,
    required this.busy,
    required this.onDelete,
    required this.onApprove,
    required this.onToggleHidden,
    required this.onToggleFeatured,
  });

  final _AdminMediaItem item;
  final bool busy;
  final VoidCallback onDelete;
  final VoidCallback? onApprove;
  final VoidCallback onToggleHidden;
  final VoidCallback onToggleFeatured;

  @override
  Widget build(BuildContext context) {
    final isPhoto = item.type == 'photo';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.82),
                          builder: (context) {
                            return _AdminMediaViewerDialog(item: item);
                          },
                        );
                      },
                      child: isPhoto
                          ? Image.network(
                              item.fileUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _MediaFallback(type: item.type);
                              },
                            )
                          : _VideoPreview(
                              type: item.type,
                              fileName: item.originalFileName,
                            ),
                    ),
                  ),
                ),
                Positioned(top: 9, left: 9, child: _TypePill(type: item.type)),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: busy ? null : onDelete,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Color(0xFFD92D20),
                        ),
                      ),
                    ),
                  ),
                ),
                if (item.isHidden)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.35),
                      alignment: Alignment.center,
                      child: const Text(
                        'HIDDEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 62,
            padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
            alignment: Alignment.centerLeft,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.originalFileName ?? 'Untitled file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF15151A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (onApprove != null) ...[
                      _StatusPillSmall(
                        text: item.status.toUpperCase(),
                        color: const Color(0xFFB42318),
                      ),
                      const SizedBox(width: 8),
                      _MiniIconButton(
                        tooltip: 'Approve',
                        icon: Icons.check_rounded,
                        color: const Color(0xFF12B76A),
                        onTap: busy ? null : onApprove,
                      ),
                    ] else
                      _StatusPillSmall(
                        text: item.status.toUpperCase(),
                        color: const Color(0xFF12B76A),
                      ),
                    const Spacer(),
                    _MiniIconButton(
                      tooltip: item.isFeatured ? 'Unfeature' : 'Feature',
                      icon: item.isFeatured
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFFDB022),
                      onTap: busy ? null : onToggleFeatured,
                    ),
                    const SizedBox(width: 6),
                    _MiniIconButton(
                      tooltip: item.isHidden ? 'Unhide' : 'Hide',
                      icon: item.isHidden
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: const Color(0xFF667085),
                      onTap: busy ? null : onToggleHidden,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 30,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _StatusPillSmall extends StatelessWidget {
  const _StatusPillSmall({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.type, required this.fileName});

  final String type;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF15151A),
      child: Center(
        child: Icon(
          type == 'audio'
              ? Icons.audiotrack_rounded
              : Icons.play_circle_outline_rounded,
          color: Colors.white.withOpacity(0.9),
          size: 54,
        ),
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F4F7),
      child: Center(
        child: Icon(
          type == 'video'
              ? Icons.videocam_outlined
              : type == 'audio'
              ? Icons.mic_none_outlined
              : Icons.broken_image_outlined,
          size: 42,
          color: const Color(0xFF667085),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (type) {
      'video' => (Icons.videocam_outlined, 'Video'),
      'audio' => (Icons.mic_none_outlined, 'Audio'),
      'note' => (Icons.sticky_note_2_outlined, 'Note'),
      _ => (Icons.photo_outlined, 'Photo'),
    };

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF15151A)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF15151A),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMediaViewerDialog extends StatefulWidget {
  const _AdminMediaViewerDialog({required this.item});

  final _AdminMediaItem item;

  @override
  State<_AdminMediaViewerDialog> createState() =>
      _AdminMediaViewerDialogState();
}

class _AdminMediaViewerDialogState extends State<_AdminMediaViewerDialog> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late final Future<_AdminGuestInfo?> _guestFuture;

  @override
  void initState() {
    super.initState();
    _guestFuture = _loadGuest();

    if (widget.item.type == 'video') {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.item.fileUrl),
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

  Future<_AdminGuestInfo?> _loadGuest() async {
    final guestId = widget.item.guestId;
    if (guestId == null || guestId.trim().isEmpty) return null;

    final row = await Supabase.instance.client
        .from('guests')
        .select('name, email')
        .eq('id', guestId)
        .maybeSingle();

    if (row == null) return null;

    return _AdminGuestInfo(
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
    final uri = Uri.tryParse(widget.item.fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  @override
  Widget build(BuildContext context) {
    final isPhoto = widget.item.type == 'photo';
    final isVideo = widget.item.type == 'video';
    final isAudio = widget.item.type == 'audio';

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
                      widget.item.originalFileName ?? 'Memory',
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
              constraints: const BoxConstraints(maxHeight: 640),
              color: Colors.black,
              child: Builder(
                builder: (context) {
                  if (isPhoto) {
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          widget.item.fileUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return _MediaFallback(type: widget.item.type);
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
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
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
              child: FutureBuilder<_AdminGuestInfo?>(
                future: _guestFuture,
                builder: (context, snapshot) {
                  final guest = snapshot.data;
                  final uploadedBy = (widget.item.guestId == null)
                      ? 'Admin'
                      : (guest?.displayName ?? 'Guest');

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
                          'Uploaded by $uploadedBy',
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

class _AdminGuestInfo {
  const _AdminGuestInfo({required this.name, required this.email});

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

class _EmptyMediaState extends StatelessWidget {
  const _EmptyMediaState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 38,
            color: Color(0xFF15151A),
          ),
          const SizedBox(height: 10),
          const Text(
            'No album content yet',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF15151A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Use Add photos or videos to upload content.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.46),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftLabel extends StatelessWidget {
  const _SoftLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF15151A)),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.45,
            color: Color(0xFF15151A),
          ),
        ),
      ],
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF15151A),
          side: const BorderSide(color: Color(0xFFE5E5EA)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(
            fontSize: 12.8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      clipBehavior: Clip.antiAlias,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black.withOpacity(0.55),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF15151A),
        side: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AdminMediaRepository {
  _AdminMediaRepository();

  static const String bucketName = 'album-media';

  static const List<String> photoExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
  ];

  static const List<String> videoExtensions = ['mp4', 'mov', 'm4v', 'webm'];

  static const List<String> allowedExtensions = [
    ...photoExtensions,
    ...videoExtensions,
  ];

  final SupabaseClient _supabase = Supabase.instance.client;

  bool isAllowedMediaFile(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase().trim();
    final fileName = file.name.toLowerCase().trim();
    final mimeType = lookupMimeType(file.name, headerBytes: file.bytes);

    if (fileName.endsWith('.keystore')) return false;

    final isPhoto =
        photoExtensions.contains(extension) ||
        mimeType?.startsWith('image/') == true;

    final isVideo =
        videoExtensions.contains(extension) ||
        mimeType?.startsWith('video/') == true;

    return isPhoto || isVideo;
  }

  Future<void> uploadAdminMedia({
    required String albumId,
    required PlatformFile pickedFile,
  }) async {
    if (!isAllowedMediaFile(pickedFile)) {
      throw Exception('Only image and video files are allowed.');
    }

    final bytes = pickedFile.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw Exception('The selected file is empty or could not be read.');
    }

    final extension = (pickedFile.extension ?? '').toLowerCase().trim();
    final mimeType =
        lookupMimeType(pickedFile.name, headerBytes: bytes) ??
        _fallbackMimeType(extension);

    final mediaType = _mediaTypeFromMimeOrExtension(
      mimeType: mimeType,
      extension: extension,
    );

    final safeExtension = extension.isEmpty
        ? _extensionFromMime(mimeType)
        : extension;

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final safeName = pickedFile.name.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final storagePath = '$albumId/admin_$timestamp.$safeExtension';

    await _supabase.storage
        .from(bucketName)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final publicUrl = _supabase.storage
        .from(bucketName)
        .getPublicUrl(storagePath);
    final now = DateTime.now().toIso8601String();

    await _supabase.from('media_uploads').insert({
      'album_id': albumId,
      'guest_id': null,
      'type': mediaType,
      'file_url': publicUrl,
      'storage_path': storagePath,
      'thumbnail_url': null,
      'thumbnail_storage_path': null,
      'original_file_name': safeName,
      'file_extension': safeExtension,
      'mime_type': mimeType,
      'file_size_bytes': pickedFile.size,
      'status': 'approved',
      'caption': null,
      'is_featured': false,
      'is_hidden': false,
      'processed_at': now,
      'approved_at': now,
    });
  }

  Future<List<_AdminMediaItem>> getAlbumMedia(String albumId) async {
    final rows = await _supabase
        .from('media_uploads')
        .select(
          'id, album_id, guest_id, type, file_url, storage_path, thumbnail_url, thumbnail_storage_path, original_file_name, file_extension, mime_type, file_size_bytes, status, is_hidden, is_featured, deleted_at, created_at',
        )
        .eq('album_id', albumId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => _AdminMediaItem.fromJson(row as Map<String, dynamic>))
        .where((item) => item.deletedAt == null)
        .where((item) => !_isBlockedStoragePath(item.storagePath))
        .toList();
  }

  Future<void> updateMedia({
    required String id,
    required Map<String, dynamic> patch,
  }) async {
    await _supabase
        .from('media_uploads')
        .update({...patch, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<void> deleteMedia(_AdminMediaItem item) async {
    final paths = <String>[
      if (item.storagePath.trim().isNotEmpty) item.storagePath,
      if ((item.thumbnailStoragePath ?? '').trim().isNotEmpty)
        item.thumbnailStoragePath!,
    ];

    if (paths.isNotEmpty) {
      try {
        await _supabase.storage.from(bucketName).remove(paths);
      } catch (_) {}
    }

    await _supabase.from('media_uploads').delete().eq('id', item.id);
  }

  Future<void> refreshAlbumCounters(String albumId) async {
    final mediaRows = await _supabase
        .from('media_uploads')
        .select('type')
        .eq('album_id', albumId)
        .eq('status', 'approved')
        .eq('is_hidden', false);

    final noteRows = await _supabase
        .from('notes')
        .select('id')
        .eq('album_id', albumId)
        .eq('status', 'approved')
        .eq('is_hidden', false);

    final media = mediaRows as List<dynamic>;
    final notes = noteRows as List<dynamic>;

    final photos = media.where((row) {
      return (row as Map<String, dynamic>)['type'] == 'photo';
    }).length;

    final videos = media.where((row) {
      return (row as Map<String, dynamic>)['type'] == 'video';
    }).length;

    final audios = media.where((row) {
      return (row as Map<String, dynamic>)['type'] == 'audio';
    }).length;

    await _supabase
        .from('albums')
        .update({
          'total_uploads': media.length,
          'total_photos': photos,
          'total_videos': videos,
          'total_audios': audios,
          'total_notes': notes.length,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', albumId);
  }

  static bool _isBlockedStoragePath(String path) {
    final value = path.toLowerCase().trim();

    return value.endsWith('.keystore') ||
        value.endsWith('.json') ||
        value.endsWith('.txt') ||
        value.endsWith('.pdf') ||
        value.endsWith('.zip');
  }

  String _mediaTypeFromMimeOrExtension({
    required String mimeType,
    required String extension,
  }) {
    if (mimeType.startsWith('video/') || videoExtensions.contains(extension)) {
      return 'video';
    }

    return 'photo';
  }

  String _fallbackMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }

  String _extensionFromMime(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      case 'video/mp4':
        return 'mp4';
      case 'video/quicktime':
        return 'mov';
      case 'video/x-m4v':
        return 'm4v';
      case 'video/webm':
        return 'webm';
      default:
        return 'bin';
    }
  }
}

class _AdminNotesRepository {
  _AdminNotesRepository();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<MemoryNote>> getAlbumNotes(String albumId) async {
    final rows = await _supabase
        .from('notes')
        .select(
          'id, album_id, guest_id, message, status, is_featured, is_hidden, created_at',
        )
        .eq('album_id', albumId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => MemoryNote.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateNote({
    required String id,
    required Map<String, dynamic> patch,
  }) async {
    await _supabase.from('notes').update(patch).eq('id', id);
  }

  Future<void> deleteNote(String id) async {
    await _supabase.from('notes').delete().eq('id', id);
  }
}

class _AdminMediaItem {
  const _AdminMediaItem({
    required this.id,
    required this.albumId,
    this.guestId,
    required this.type,
    required this.fileUrl,
    required this.storagePath,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.status,
    required this.isHidden,
    required this.isFeatured,
    required this.createdAt,
    this.thumbnailUrl,
    this.thumbnailStoragePath,
    this.originalFileName,
    this.fileExtension,
    this.deletedAt,
  });

  final String id;
  final String albumId;
  final String? guestId;
  final String type;
  final String fileUrl;
  final String storagePath;
  final String? thumbnailUrl;
  final String? thumbnailStoragePath;
  final String? originalFileName;
  final String? fileExtension;
  final String mimeType;
  final int fileSizeBytes;
  final String status;
  final bool isHidden;
  final bool isFeatured;
  final String? deletedAt;
  final String createdAt;

  factory _AdminMediaItem.fromJson(Map<String, dynamic> json) {
    return _AdminMediaItem(
      id: json['id'] as String,
      albumId: json['album_id'] as String,
      guestId: json['guest_id'] as String?,
      type: json['type'] as String,
      fileUrl: json['file_url'] as String,
      storagePath: json['storage_path'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      thumbnailStoragePath: json['thumbnail_storage_path'] as String?,
      originalFileName: json['original_file_name'] as String?,
      fileExtension: json['file_extension'] as String?,
      mimeType: json['mime_type'] as String? ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'approved',
      isHidden: json['is_hidden'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      deletedAt: json['deleted_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
