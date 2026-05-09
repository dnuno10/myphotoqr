import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/album.dart';
import '../../services/album_service.dart';
import '../../services/auth_service.dart';
import '../../shared/ui/color_utils.dart';
import '../../shared/ui/event_icons.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/logo_mark.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _albumService = AlbumService();
  late Future<List<Album>> _future;

  @override
  void initState() {
    super.initState();
    _future = _albumService.getMyAlbums();
  }

  Future<void> _signOut() async {
    await AuthService().signOut();

    if (mounted) {
      context.go('/login');
    }
  }

  Widget _buildDashboardContent({required bool compact}) {
    final left = compact ? 16.0 : 22.0;
    final right = compact ? 16.0 : 34.0;
    final top = compact ? 18.0 : 26.0;

    return FutureBuilder<List<Album>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }

        if (snapshot.hasError) {
          return ErrorView(message: snapshot.error.toString());
        }

        final albums = snapshot.data ?? [];

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(left, top, right, 0),
                child: _DashboardHeader(
                  albums: albums,
                  onCreateAlbum: () => context.go('/create'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(left, 18, right, 0),
                child: _DashboardMetrics(albums: albums),
              ),
            ),
            if (albums.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 22, bottom: 24),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: const _EmptyAlbumsCard(),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(left, 24, right, 12),
                  child: _SectionTitle(
                    subtitle:
                        'Open an album to manage uploads, QR access and guest memories.',
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(left, 0, right, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 222,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: albums.length,
                  itemBuilder: (context, index) {
                    final album = albums[index];

                    return _AlbumCard(
                      album: album,
                      onTap: () => context.go('/album/${album.id}'),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: compact ? AppBar(title: const Text('Dashboard')) : null,
          drawer: compact
              ? Drawer(
                  child: _DashboardMobileDrawer(
                    onDashboard: () => context.go('/'),
                    onCreateAlbum: () => context.go('/create'),
                    onSignOut: _signOut,
                  ),
                )
              : null,
          body: SafeArea(
            child: compact
                ? _buildDashboardContent(compact: true)
                : Row(
                    children: [
                      _DashboardSidebar(
                        onDashboard: () => context.go('/'),
                        onCreateAlbum: () => context.go('/create'),
                        onSignOut: _signOut,
                      ),
                      Expanded(child: _buildDashboardContent(compact: false)),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _DashboardMobileDrawer extends StatelessWidget {
  const _DashboardMobileDrawer({
    required this.onDashboard,
    required this.onCreateAlbum,
    required this.onSignOut,
  });

  final VoidCallback onDashboard;
  final VoidCallback onCreateAlbum;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                LogoMark(size: 44, onTap: onDashboard),
                SizedBox(width: 12),
                Text(
                  'MyPhotoQR',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.dashboard_rounded),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.of(context).pop();
              onDashboard();
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('Create album'),
            onTap: () {
              Navigator.of(context).pop();
              onCreateAlbum();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () async {
              Navigator.of(context).pop();
              await onSignOut();
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.onDashboard,
    required this.onCreateAlbum,
    required this.onSignOut,
  });

  final VoidCallback onDashboard;
  final VoidCallback onCreateAlbum;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
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
          LogoMark(size: 44, onTap: onDashboard),
          const SizedBox(height: 26),
          _SidebarButton(
            icon: Icons.dashboard_rounded,
            tooltip: 'Dashboard',
            label: 'Dashboard',
            active: true,
            onTap: onDashboard,
          ),
          const SizedBox(height: 12),
          _SidebarButton(
            icon: Icons.add_rounded,
            tooltip: 'Create album',
            label: 'Create album',
            onTap: onCreateAlbum,
          ),
          const Spacer(),
          _SidebarButton(
            icon: Icons.logout_rounded,
            tooltip: 'Sign out',
            label: 'Sign out',
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final String label;
  final VoidCallback onTap;
  final bool active;

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
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3,
                height: active ? 22 : 0,
                margin: const EdgeInsets.only(left: 4, right: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(
                icon,
                size: 22,
                color: active ? Colors.black : const Color(0xFF6A6A74),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.black : const Color(0xFF6A6A74),
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

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.albums, required this.onCreateAlbum});

  final List<Album> albums;
  final VoidCallback onCreateAlbum;

  @override
  Widget build(BuildContext context) {
    final hasAlbums = albums.isNotEmpty;

    return _Surface(
      padding: const EdgeInsets.fromLTRB(24, 22, 22, 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SoftLabel(
                icon: Icons.auto_awesome_rounded,
                text: 'QR ALBUM DASHBOARD',
              ),
              const SizedBox(height: 14),
              Text(
                hasAlbums
                    ? 'Manage every event from one place.'
                    : 'Create your first QR album.',
                style: const TextStyle(
                  color: Color(0xFF15151A),
                  fontSize: 31,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasAlbums
                    ? 'Review albums, uploads and guest memories without extra steps.'
                    : 'Fill in your album details, pay once and start collecting memories.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.38,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.48),
                ),
              ),
            ],
          );

          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 176,
                height: 48,
                child: _PrimaryButton(
                  text: 'Create album',
                  icon: Icons.add_rounded,
                  onPressed: onCreateAlbum,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [content, const SizedBox(height: 18), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 22),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    final totalUploads = albums.fold<int>(
      0,
      (previous, album) => previous + album.totalUploads,
    );

    final totalPhotos = albums.fold<int>(
      0,
      (previous, album) => previous + album.totalPhotos,
    );

    final totalVideos = albums.fold<int>(
      0,
      (previous, album) => previous + album.totalVideos,
    );

    final totalAudios = albums.fold<int>(
      0,
      (previous, album) => previous + album.totalAudios,
    );

    final totalNotes = albums.fold<int>(
      0,
      (previous, album) => previous + album.totalNotes,
    );

    final metrics = [
      _MetricData(
        title: 'Albums',
        value: albums.length.toString(),
        icon: Icons.photo_library_outlined,
      ),
      _MetricData(
        title: 'Uploads',
        value: totalUploads.toString(),
        icon: Icons.cloud_upload_outlined,
      ),
      _MetricData(
        title: 'Photos',
        value: totalPhotos.toString(),
        icon: Icons.photo_outlined,
      ),
      _MetricData(
        title: 'Videos',
        value: totalVideos.toString(),
        icon: Icons.videocam_outlined,
      ),
      _MetricData(
        title: 'Audios',
        value: totalAudios.toString(),
        icon: Icons.audiotrack_outlined,
      ),
      _MetricData(
        title: 'Notes',
        value: totalNotes.toString(),
        icon: Icons.notes_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 940) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: metrics.map((metric) {
              return SizedBox(width: 180, child: _MetricCard(metric: metric));
            }).toList(),
          );
        }

        return Row(
          children: [
            for (int index = 0; index < metrics.length; index++) ...[
              Expanded(child: _MetricCard(metric: metrics[index])),
              if (index != metrics.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 82,
        child: Row(
          children: [
            Icon(metric.icon, color: const Color(0xFF15151A), size: 21),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF15151A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metric.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SoftLabel(icon: Icons.folder_open_rounded, text: 'ALBUMS'),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.46),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyAlbumsCard extends StatelessWidget {
  const _EmptyAlbumsCard();

  @override
  Widget build(BuildContext context) {
    const price = '19.99';
    const features = <String>[
      '1 event album',
      'QR code and share links for guests',
      'Guest uploads from the browser',
      'Photos, videos, notes and audio memories',
      'Live gallery for viewing content',
      'Privacy and visibility controls',
      'Album configuration: name, description, type, date, location, cover, banner and theme',
      'Moderation: approve, hide, feature or auto-approve',
      'Live slideshow for TV or projector',
      'ZIP export with photos and videos',
      '1 year active album and storage',
      'Email support within 24–48 business hours',
    ];

    return _Surface(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 840;
            final splitAt = (features.length / 2).ceil();
            final leftFeatures = features.take(splitAt).toList();
            final rightFeatures = features.skip(splitAt).toList();

            final left = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SoftLabel(
                  icon: Icons.auto_awesome_rounded,
                  text: 'QR ALBUM — ONE-TIME PAYMENT',
                  accent: Color(0xFFFF4D6D),
                ),
                const SizedBox(height: 14),
                Text(
                  '\$$price',
                  style: TextStyle(
                    fontSize: horizontal ? 76 : 72,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.5,
                    color: const Color(0xFF0B0F14),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'One-time payment',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  width: horizontal ? 260 : double.infinity,
                  child: _PrimaryButton(
                    text: 'Create album',
                    icon: Icons.add_rounded,
                    onPressed: () => context.go('/create'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ideal for a single event album with quick setup and easy sharing.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),
              ],
            );

            final included = Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What's included",
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF15151A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!horizontal)
                    Column(
                      children: [
                        for (final item in features)
                          _FeatureRow(
                            text: item,
                            textColor: Colors.black.withOpacity(0.78),
                          ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              for (final item in leftFeatures)
                                _FeatureRow(
                                  text: item,
                                  textColor: Colors.black.withOpacity(0.78),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            children: [
                              for (final item in rightFeatures)
                                _FeatureRow(
                                  text: item,
                                  textColor: Colors.black.withOpacity(0.78),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );

            if (!horizontal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 18), included],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 330,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: left,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(child: included),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text, this.textColor});

  final String text;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.check_circle_rounded,
            size: 22,
            color: Color(0xFF12B76A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: textColor ?? Colors.black.withOpacity(0.78),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isProtected = album.guestAccessCodeEnabled;
    final accent = (album.themeColor).toColorOr(const Color(0xFF6D28D9));
    final description = album.description?.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: _Surface(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  iconForEventType(album.eventType),
                  size: 27,
                  color: accent.mix(const Color(0xFF111116), 0.12),
                ),
                const Spacer(),
                _StatusPill(
                  text: _formatStatus(album.status),
                  color: album.status == 'active'
                      ? const Color(0xFF12B76A)
                      : const Color(0xFF111827),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              album.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 23,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                color: Color(0xFF15151A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description == null || description.isEmpty
                  ? 'Ready to share with guests.'
                  : description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.45),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFECECF0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _AlbumMiniStat(
                      label: 'Photos',
                      value: album.totalPhotos.toString(),
                    ),
                  ),
                  Expanded(
                    child: _AlbumMiniStat(
                      label: 'Videos',
                      value: album.totalVideos.toString(),
                    ),
                  ),
                  Expanded(
                    child: _AlbumMiniStat(
                      label: 'Audios',
                      value: album.totalAudios.toString(),
                    ),
                  ),
                  Expanded(
                    child: _AlbumMiniStat(
                      label: 'Notes',
                      value: album.totalNotes.toString(),
                    ),
                  ),
                  if (isProtected)
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Color(0xFF15151A),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty) return 'Draft';
    if (normalized == 'active') return 'Active';
    if (normalized == 'draft') return 'Draft';
    if (normalized == 'paused') return 'Paused';
    if (normalized == 'archived') return 'Archived';

    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class _AlbumMiniStat extends StatelessWidget {
  const _AlbumMiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            height: 1,
            fontWeight: FontWeight.w900,
            color: Color(0xFF15151A),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.42),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SoftLabel extends StatelessWidget {
  const _SoftLabel({
    required this.icon,
    required this.text,
    this.accent = const Color(0xFF15151A),
  });

  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.45,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.onPressed,
    this.icon,
  });

  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: icon == null
          ? Text(text)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(text),
              ],
            ),
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
            color: Color(0x02000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
