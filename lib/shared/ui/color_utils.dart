import 'package:flutter/material.dart';

extension HexColorParsing on String {
  Color toColorOr(Color fallback) {
    final value = trim();
    if (value.isEmpty) return fallback;

    final hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length != 6 && hex.length != 8) return fallback;

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return fallback;

    if (hex.length == 6) {
      return Color(0xFF000000 | parsed);
    }
    return Color(parsed);
  }
}

extension ColorMixing on Color {
  Color mix(Color other, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return Color.lerp(this, other, clamped) ?? this;
  }
}
