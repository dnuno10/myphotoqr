import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Cargando...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 12),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}
