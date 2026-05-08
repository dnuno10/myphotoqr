import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

Future<Duration?> readPickedMediaDuration(PlatformFile file) async {
  final bytes = file.bytes;
  if (bytes == null) return null;

  final mimeType = lookupMimeType(file.name, headerBytes: bytes) ?? '';
  final blob = html.Blob([bytes], mimeType.isEmpty ? null : mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  try {
    if (mimeType.startsWith('audio/')) {
      final audio = html.AudioElement()
        ..preload = 'metadata'
        ..src = url;
      return await _loadDuration(audio);
    }

    final video = html.VideoElement()
      ..preload = 'metadata'
      ..src = url;
    return await _loadDuration(video);
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

Future<Duration?> _loadDuration(html.MediaElement element) async {
  final completer = Completer<Duration?>();

  void done([Duration? value]) {
    if (!completer.isCompleted) completer.complete(value);
  }

  element.onLoadedMetadata.first.then((_) {
    final seconds = element.duration;
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) {
      done(null);
      return;
    }
    done(Duration(milliseconds: (seconds * 1000).round()));
  });

  element.onError.first.then((_) => done(null));

  // Start loading metadata.
  element.load();

  return completer.future.timeout(
    const Duration(seconds: 8),
    onTimeout: () {
      return null;
    },
  );
}
