import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/album.dart';
import '../../shared/ui/color_utils.dart';
import '../../shared/ui/event_icons.dart';

class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
    this.borderColor = const Color(0xFFEDEDF1),
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, required this.onTap});

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
      child: DashCard(
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

class AlbumGrid extends StatelessWidget {
  const AlbumGrid({super.key, required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 236,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return AlbumCard(
          album: album,
          onTap: () => context.go('/album/${album.id}'),
        );
      },
    );
  }
}
