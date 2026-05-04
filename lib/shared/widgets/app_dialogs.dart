import 'package:flutter/material.dart';

Future<void> showAppMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonText = 'OK',
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      );
    },
  );
}
