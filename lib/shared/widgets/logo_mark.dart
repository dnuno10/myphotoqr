import 'package:flutter/material.dart';

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .18),
        child: Image.asset('assets/img/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}
