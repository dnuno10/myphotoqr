import 'dart:math' as math;

import 'package:flutter/material.dart';

extension AppSnackbars on BuildContext {
  void showTopRightSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    bool clearPrevious = true,
  }) {
    final messenger = ScaffoldMessenger.of(this);
    if (clearPrevious) {
      messenger.clearSnackBars();
    }

    final media = MediaQuery.of(this);
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;

    const double edge = 12;
    const double topOffset = 12;

    final screenWidth = media.size.width;
    final screenHeight = media.size.height;

    final width =
        math.min(360.0, math.max(0.0, screenWidth - (edge * 2))).toDouble();
    final left = math.max(edge, screenWidth - width - edge);
    final right = edge;

    // SnackBars are anchored to the bottom; we push them up by using a large
    // bottom margin so they land near the top-right corner.
    const estimatedSnackHeight = 72.0;
    final top = safeTop + topOffset;
    final bottom = math.max(
      edge + safeBottom,
      screenHeight - top - estimatedSnackHeight,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
        width: width,
        margin: EdgeInsets.only(
          left: left,
          right: right,
          bottom: bottom,
        ),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
