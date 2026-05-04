import 'package:flutter/material.dart';

import '../ui/app_tokens.dart';
import '../ui/color_utils.dart';
import '../ui/event_theme.dart';

class AlbumBackdrop extends StatelessWidget {
  const AlbumBackdrop({
    super.key,
    required this.child,
    this.accentHex,
    this.backgroundHex,
    this.eventType,
    this.showEventDecorations = false,
  });

  final Widget child;
  final String? accentHex;
  final String? backgroundHex;
  final String? eventType;
  final bool showEventDecorations;

  @override
  Widget build(BuildContext context) {
    final accent = (accentHex ?? '').toColorOr(
      Theme.of(context).colorScheme.primary,
    );
    final bg = (backgroundHex ?? '').toColorOr(AppTokens.bg);

    final topTint = accent.mix(Colors.white, 0.92);
    final copy = eventType == null ? null : eventThemeCopy(eventType!);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topTint, Colors.white, bg.mix(Colors.white, 0.96)],
          stops: const [0.0, 0.34, 1.0],
        ),
      ),
      child: Stack(
        children: [
          if (showEventDecorations && copy != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _EventEmojiDecorations(
                  emoji: copy.emoji,
                  accent: accent,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _EventEmojiDecorations extends StatelessWidget {
  const _EventEmojiDecorations({required this.emoji, required this.accent});

  final String emoji;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 86,
          left: 34,
          child: _DecorEmoji(emoji: emoji, size: 42, opacity: 0.10),
        ),
        Positioned(
          top: 118,
          right: 46,
          child: _DecorEmoji(emoji: emoji, size: 54, opacity: 0.08),
        ),
        Positioned(
          bottom: 78,
          left: 58,
          child: _DecorEmoji(emoji: emoji, size: 50, opacity: 0.07),
        ),
        Positioned(
          bottom: 120,
          right: 72,
          child: _DecorEmoji(emoji: emoji, size: 38, opacity: 0.09),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(height: 3, color: accent.withOpacity(0.38)),
        ),
      ],
    );
  }
}

class _DecorEmoji extends StatelessWidget {
  const _DecorEmoji({
    required this.emoji,
    required this.size,
    required this.opacity,
  });

  final String emoji;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}

class SaasBackdrop extends StatelessWidget {
  const SaasBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), AppTokens.bg],
        ),
      ),
      child: child,
    );
  }
}
