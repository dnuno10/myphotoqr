import 'package:flutter/material.dart';

import 'saas_surface.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SaasSurface(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 46),
            const SizedBox(height: 10),
            const Text(
              'Algo no salió bien',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Intentar de nuevo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
