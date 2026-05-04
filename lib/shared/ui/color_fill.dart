import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ColorFillMode { solid, gradient }

class LinearGradientSpec {
  const LinearGradientSpec({
    required this.angleDegrees,
    required this.colors,
  });

  final double angleDegrees;
  final List<Color> colors;

  Map<String, dynamic> toJson() {
    return {
      'type': 'linear',
      'angle': angleDegrees,
      'colors': colors.map(colorToHex).toList(),
    };
  }

  static LinearGradientSpec? fromJson(dynamic value) {
    if (value is! Map) return null;
    final type = value['type']?.toString();
    if (type != 'linear') return null;

    final angle = (value['angle'] as num?)?.toDouble() ?? 90.0;
    final rawColors = value['colors'];
    if (rawColors is! List) return null;

    final colors = rawColors
        .map((e) => hexToColor(e?.toString() ?? ''))
        .whereType<Color>()
        .toList();

    if (colors.length < 2) return null;

    return LinearGradientSpec(angleDegrees: angle, colors: colors.take(2).toList());
  }
}

class ColorFillValue {
  const ColorFillValue.solid(this.solidColor)
      : mode = ColorFillMode.solid,
        gradient = null;

  const ColorFillValue.gradient(this.gradient)
      : mode = ColorFillMode.gradient,
        solidColor = null;

  final ColorFillMode mode;
  final Color? solidColor;
  final LinearGradientSpec? gradient;

  Color get primaryColor {
    if (mode == ColorFillMode.solid) return solidColor!;
    return gradient!.colors.first;
  }

  String get primaryHex => colorToHex(primaryColor);

  Map<String, dynamic>? get gradientJson =>
      mode == ColorFillMode.gradient ? gradient!.toJson() : null;

  static ColorFillValue fromAlbumFields({
    required String solidHexFallback,
    required String? mode,
    required Map<String, dynamic>? gradient,
  }) {
    final normalized = (mode ?? 'solid').trim().toLowerCase();
    final solid = hexToColor(solidHexFallback) ?? const Color(0xFF111827);

    if (normalized == 'gradient') {
      final parsed = LinearGradientSpec.fromJson(gradient);
      if (parsed != null) return ColorFillValue.gradient(parsed);
    }

    return ColorFillValue.solid(solid);
  }
}

(Alignment, Alignment) angleToBeginEnd(double angleDegrees) {
  final a = (angleDegrees % 360) * (math.pi / 180.0);
  final dx = math.cos(a);
  final dy = math.sin(a);

  final begin = Alignment(-dx, -dy);
  final end = Alignment(dx, dy);
  return (begin, end);
}

String colorToHex(Color color) {
  final value = color.value & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color? hexToColor(String value) {
  final v = value.trim();
  final match = RegExp(r'^#?[0-9A-Fa-f]{6}$').firstMatch(v);
  if (match == null) return null;
  final hex = v.startsWith('#') ? v.substring(1) : v;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

