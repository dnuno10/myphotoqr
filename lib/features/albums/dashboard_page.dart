import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/plans.dart';
import '../../models/album.dart';
import '../../services/album_service.dart';
import '../../shared/ui/safe_user_messages.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import 'album_card.dart';

const _ink = Color(0xFF15151A);
const _pink = Color(0xFFE11D48);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _albumService = AlbumService();
  final _howItWorksKey = GlobalKey();
  late Future<List<Album>> _future;

  @override
  void initState() {
    super.initState();
    _future = _albumService.getMyAlbums();
  }

  void _scrollToHowItWorks() {
    final ctx = _howItWorksKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      current: ShellSection.dashboard,
      child: FutureBuilder<List<Album>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          if (snapshot.hasError) {
            return ErrorView(
              message: safeUserErrorMessage(
                snapshot.error,
                fallback: 'We could not load your albums. Please try again.',
              ),
            );
          }

          final albums = snapshot.data ?? [];

          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final wide = constraints.maxWidth >= 1080;
              final gutter = compact ? 16.0 : 32.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Hero(
                          compact: compact,
                          hasAlbums: albums.isNotEmpty,
                          onCreate: () => context.go('/create'),
                          onWatch: _scrollToHowItWorks,
                        ),
                        const SizedBox(height: 20),
                        _StatsRow(albums: albums, compact: compact),
                        const SizedBox(height: 20),
                        if (albums.isNotEmpty) ...[
                          _RecentAlbums(albums: albums),
                          const SizedBox(height: 20),
                        ],
                        _twoColumn(
                          wide: wide,
                          flex: const [11, 10],
                          children: const [_PromoCard(), _WhyChoose()],
                        ),
                        const SizedBox(height: 20),
                        _twoColumn(
                          wide: wide,
                          flex: const [11, 10],
                          children: [
                            const _PopularEvents(),
                            _HowItWorks(key: _howItWorksKey),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Widget _twoColumn({
  required bool wide,
  required List<int> flex,
  required List<Widget> children,
}) {
  if (!wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [children[0], const SizedBox(height: 20), children[1]],
    );
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: flex[0], child: children[0]),
      const SizedBox(width: 20),
      Expanded(flex: flex[1], child: children[1]),
    ],
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.compact,
    required this.hasAlbums,
    required this.onCreate,
    required this.onWatch,
  });

  final bool compact;
  final bool hasAlbums;
  final VoidCallback onCreate;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final title = hasAlbums
        ? 'Manage every event\nfrom one place.'
        : 'Create your first QR album\nand start collecting memories.';

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WELCOME TO MYPHOTOQR 👋',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFF6A6A74),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 28 : 40,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const Text(
            'Turn any event into a shared photo experience. Create your album, '
            'get a QR code, share it with your guests, and collect photos, '
            'videos and messages — all in one place.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6A6A74),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create album'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B0B10),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: onWatch,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Watch how it works'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.only(top: 8), child: copy),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset('assets/img/dashboard.png', fit: BoxFit.cover),
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 380),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.62,
                heightFactor: 1,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Colors.transparent, Colors.black],
                    stops: [0.0, 0.32],
                  ).createShader(rect),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/img/dashboard.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 58,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: copy,
                ),
              ),
              const Expanded(flex: 42, child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.albums, required this.compact});

  final List<Album> albums;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final uploads = albums.fold<int>(0, (s, a) => s + a.totalUploads);
    final media = albums.fold<int>(
      0,
      (s, a) => s + a.totalPhotos + a.totalVideos,
    );
    final active = albums.where((a) => a.status == 'active').length;

    final cards = [
      _StatCard(
        icon: Icons.image_outlined,
        tint: const Color(0xFFE8F0FE),
        iconColor: const Color(0xFF3B82F6),
        title: 'Active albums',
        value: '$active',
        caption: active == 0 ? 'Create your first album' : 'Ready for guests',
      ),
      _StatCard(
        icon: Icons.cloud_upload_rounded,
        tint: const Color(0xFFE7F7EC),
        iconColor: const Color(0xFF22C55E),
        title: 'Total uploads',
        value: '$uploads',
        caption: 'Photos, videos and messages',
      ),
      _StatCard(
        icon: Icons.perm_media_outlined,
        tint: const Color(0xFFF1EAFE),
        iconColor: const Color(0xFF8B5CF6),
        title: 'Photos & videos',
        value: '$media',
        caption: 'Your memories are safe',
      ),
      _StatCard(
        icon: Icons.workspace_premium_outlined,
        tint: const Color(0xFFFDE8EE),
        iconColor: const Color(0xFFE11D48),
        title: 'Plan',
        value: 'Pay per album',
        caption: 'From ${Plans.basic.priceLabel} per album',
        smallValue: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in cards) SizedBox(width: width, child: c)],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.caption,
    this.smallValue = false,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String value;
  final String caption;
  final bool smallValue;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF52525B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: smallValue ? 22 : 30,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8A8A94),
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

class _RecentAlbums extends StatelessWidget {
  const _RecentAlbums({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    final shown = albums.take(3).toList();

    return DashCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your albums',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/albums'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return AlbumGrid(albums: shown);
            },
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard();

  @override
  Widget build(BuildContext context) {
    const bullets = [
      'Full access to all features',
      'Cloud storage after your event',
      'Perfect for any occasion',
      'One-time payment',
    ];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFBCFDB)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF5F7), Color(0xFFFFE7EE)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: _pink),
              SizedBox(width: 6),
              Text(
                'LIMITED TIME OFFER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: _pink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Create a '),
                const TextSpan(
                  text: 'QR album',
                  style: TextStyle(color: Color(0xFF9F1239)),
                ),
                const TextSpan(text: ' for just '),
                TextSpan(
                  text: Plans.basic.priceLabel,
                  style: const TextStyle(color: _pink),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.9,
              color: Color(0xFF1B1B1F),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '\$25',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDD5E0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '60% OFF',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _pink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'One-time payment. No subscription. No hidden fees.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3F3F46),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              for (final b in bullets)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: _pink,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        b,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3F3F46),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: () => context.go('/create'),
              icon: const Icon(Icons.diamond_outlined, size: 20),
              label: Text('Create album now for ${Plans.basic.priceLabel}'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B0B10),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyChoose extends StatelessWidget {
  const _WhyChoose();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.qr_code_2_rounded,
        Color(0xFFFDE8EE),
        Color(0xFFE11D48),
        'QR code sharing',
        'Easy for guests to join',
      ),
      (
        Icons.shield_outlined,
        Color(0xFFE0F2FE),
        Color(0xFF0284C7),
        'Moderation tools',
        'Approve, hide or auto-approve',
      ),
      (
        Icons.cloud_upload_rounded,
        Color(0xFFE7F7EC),
        Color(0xFF22C55E),
        'Guest uploads',
        'Photos, videos and messages',
      ),
      (
        Icons.download_rounded,
        Color(0xFFFFF1DB),
        Color(0xFFF59E0B),
        'ZIP export',
        'Download all photos and videos',
      ),
      (
        Icons.slideshow_rounded,
        Color(0xFFF1EAFE),
        Color(0xFF8B5CF6),
        'Live slideshow',
        'View on any screen',
      ),
      (
        Icons.palette_outlined,
        Color(0xFFFDE8EE),
        Color(0xFFE11D48),
        'Customizable album',
        'Personalize with your own style',
      ),
      (
        Icons.lock_outline_rounded,
        Color(0xFFFFF1DB),
        Color(0xFFF59E0B),
        'Privacy controls',
        'Keep your memories safe',
      ),
      (
        Icons.headset_mic_outlined,
        Color(0xFFE0F2FE),
        Color(0xFF0284C7),
        'Email support',
        'Get help within 24–48 hours',
      ),
    ];

    return DashCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why choose MyPhotoQR?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Everything you need for a seamless photo sharing experience.',
            style: TextStyle(fontSize: 14.5, color: Color(0xFF6A6A74)),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 460;
              final width = twoCols
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final it in items)
                    SizedBox(
                      width: width,
                      child: Row(
                        children: [
                          Icon(it.$1, color: it.$3, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.$4,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  it.$5,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6A6A74),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PopularEvents extends StatelessWidget {
  const _PopularEvents();

  @override
  Widget build(BuildContext context) {
    const events = [
      ('wedding', 'Wedding', Icons.favorite_outline_rounded, Color(0xFF3B5BDB)),
      ('birthday', 'Birthday', Icons.card_giftcard_rounded, Color(0xFFE11D48)),
      (
        'baby_shower',
        'Baby Shower',
        Icons.child_friendly_outlined,
        Color(0xFF8B5CF6),
      ),
      (
        'anniversary',
        'Anniversary',
        Icons.favorite_border_rounded,
        Color(0xFFE11D48),
      ),
      ('graduation', 'Graduation', Icons.school_rounded, Color(0xFF2563EB)),
      (
        'corporate',
        'Corporate Event',
        Icons.business_center_rounded,
        Color(0xFF92400E),
      ),
    ];

    return DashCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Popular event types',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/create'),
                child: const Text('View all'),
              ),
            ],
          ),
          const Text(
            'Start with a template designed for your special occasion.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6A6A74)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in events)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go('/create?type=${e.$1}'),
                  child: Container(
                    width: 112,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEDEDF1)),
                    ),
                    child: Column(
                      children: [
                        Icon(e.$3, color: e.$4, size: 30),
                        const SizedBox(height: 10),
                        Text(
                          e.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ],
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

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        Color(0xFFE11D48),
        'Create your album',
        'Add event details and customize',
      ),
      (Color(0xFF8B5CF6), 'Get your QR code', 'Share it with your guests'),
      (
        Color(0xFF2563EB),
        'Collect memories',
        'Guests upload photos, videos and messages',
      ),
      (Color(0xFF22C55E), 'Download & keep', 'Export everything anytime'),
    ];

    return DashCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const Text(
            'Create. Share. Collect. Cherish.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6A6A74)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var i = 0; i < steps.length; i++)
                SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: steps[i].$1,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        steps[i].$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i].$3,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: Color(0xFF8A8A94),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
