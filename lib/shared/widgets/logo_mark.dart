import 'package:flutter/material.dart';

class LogoMark extends StatelessWidget {
  const LogoMark({
    super.key,
    this.size = 42,
    this.onTap,
    this.tooltip = 'Dashboard',
  });

  final double size;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .18),
        child: Image.asset('assets/img/logo.png', fit: BoxFit.cover),
      ),
    );

    if (onTap == null) return content;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size * .18),
        child: content,
      ),
    );
  }
}
