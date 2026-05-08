import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

Future<Duration?> readPickedMediaDuration(PlatformFile file) async {
  final path = file.path;
  if (path == null || path.trim().isEmpty) return null;

  final controller = VideoPlayerController.file(File(path));
  try {
    await controller.initialize();
    return controller.value.duration;
  } finally {
    await controller.dispose();
  }
}
