import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ToastType { success, error, info }

extension AppSnackbars on BuildContext {
  void showTopRightSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    bool clearPrevious = true,
    ToastType type = ToastType.info,
  }) {
    // Keep signature compatibility; actions are not supported in the toast UI.
    // (Ignored) `action`

    _TopRightToastController.show(
      this,
      message: message,
      duration: duration,
      clearPrevious: clearPrevious,
      type: type,
    );
  }
}

class _TopRightToastController {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    required Duration duration,
    required bool clearPrevious,
    required ToastType type,
  }) {
    if (clearPrevious) {
      _timer?.cancel();
      _timer = null;
      _entry?.remove();
      _entry = null;
    }

    late final OverlayState overlay;
    try {
      overlay = Overlay.of(context, rootOverlay: true);
    } catch (_) {
      // Fallback (rare): if we can't access an Overlay, use a normal SnackBar.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final media = MediaQuery.of(context);
    const edge = 12.0;
    const topOffset = 12.0;

    final width =
        math.min(360.0, math.max(0.0, media.size.width - (edge * 2))).toDouble();
    final left = math.max(edge, media.size.width - width - edge);

    _entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: media.padding.top + topOffset,
          left: left,
          right: edge,
          child: _TopRightToast(
            width: width,
            message: message,
            type: type,
            onClose: () {
              _timer?.cancel();
              _timer = null;
              _entry?.remove();
              _entry = null;
            },
          ),
        );
      },
    );

    overlay.insert(_entry!);

    _timer = Timer(duration, () {
      _entry?.remove();
      _entry = null;
      _timer = null;
    });
  }
}

class _TopRightToast extends StatelessWidget {
  const _TopRightToast({
    required this.width,
    required this.message,
    required this.type,
    required this.onClose,
  });

  final double width;
  final String message;
  final ToastType type;
  final VoidCallback onClose;

  Color get _accent {
    switch (type) {
      case ToastType.success:
        return const Color(0xFF12B76A);
      case ToastType.error:
        return const Color(0xFFF04438);
      case ToastType.info:
        return const Color(0xFF111827);
    }
  }

  IconData get _icon {
    switch (type) {
      case ToastType.success:
        return Icons.check_rounded;
      case ToastType.error:
        return Icons.close_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 18, end: 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(offset: Offset(value, 0), child: child);
        },
        child: Container(
          width: width,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: _accent, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17171C),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF333333),
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
