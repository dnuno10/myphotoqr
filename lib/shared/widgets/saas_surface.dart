import 'package:flutter/material.dart';

import '../ui/app_tokens.dart';

class SaasSurface extends StatelessWidget {
  const SaasSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppTokens.radiusLg,
    this.color,
    this.borderColor,
    this.constraints,
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final BoxConstraints? constraints;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: constraints,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
