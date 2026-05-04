import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/app_config.dart';
import '../core/supabase_client.dart';

class UploadService {
  static const _photoExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
  static const _videoExtensions = {'mp4', 'mov', 'm4v', 'webm', 'avi'};
  static const _audioExtensions = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'webm'};
  static final _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  final _uuid = const Uuid();

  Future<Map<String, dynamic>> getOrCreateGuest({
    required String albumId,
    String? name,
    String? email,
    bool accessCodeUsed = false,
  }) async {
    final deviceId =
        'guest-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4()}';

    final normalizedName = _normalizeNullable(name);
    final normalizedEmail = _normalizeEmail(email);

    return await supabase
        .from('guests')
        .insert({
          'album_id': albumId,
          'name': normalizedName,
          'email': normalizedEmail,
          'device_id': deviceId,
          'access_code_used': accessCodeUsed,
          'last_seen_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
  }

  Future<bool> verifyAccessCode({
    required String albumId,
    required String code,
  }) async {
    final result = await supabase.rpc(
      'verify_guest_access_code',
      params: {'album_uuid': albumId, 'code': code},
    );

    return result == true;
  }

  Future<void> uploadMedia({
    required String albumId,
    required String guestId,
    required PlatformFile pickedFile,
    String? caption,
    String status = 'approved',
  }) async {
    final fileName = pickedFile.name;
    final extension = p.extension(fileName).replaceAll('.', '').toLowerCase();
    final storagePath = '$albumId/${_uuid.v4()}.$extension';
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    final mediaType = _mediaTypeFromFile(
      fileName: fileName,
      extension: extension,
      mimeType: mimeType,
    );

    int fileSize = pickedFile.size;

    if (kIsWeb) {
      final bytes = pickedFile.bytes;
      if (bytes == null) throw Exception('No se pudo leer el archivo en web.');
      await supabase.storage
          .from(AppConfig.albumMediaBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );
    } else {
      if (pickedFile.path == null) {
        throw Exception('No se encontró la ruta del archivo.');
      }
      final file = File(pickedFile.path!);
      fileSize = await file.length();
      await supabase.storage
          .from(AppConfig.albumMediaBucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );
    }

    final publicUrl = supabase.storage
        .from(AppConfig.albumMediaBucket)
        .getPublicUrl(storagePath);

    await supabase.from('media_uploads').insert({
      'album_id': albumId,
      'guest_id': guestId,
      'type': mediaType,
      'file_url': publicUrl,
      'storage_path': storagePath,
      'original_file_name': fileName,
      'file_extension': extension,
      'mime_type': mimeType,
      'file_size_bytes': fileSize,
      'caption': caption?.trim(),
      'status': status,
    });
  }

  Future<void> createNote({
    required String albumId,
    required String guestId,
    required String message,
    String status = 'approved',
  }) async {
    await supabase.from('notes').insert({
      'album_id': albumId,
      'guest_id': guestId,
      'message': message.trim(),
      'status': status,
    });
  }

  String _mediaTypeFromFile({
    required String fileName,
    required String extension,
    required String mimeType,
  }) {
    if (mimeType.startsWith('image/') || _photoExtensions.contains(extension)) {
      return 'photo';
    }
    if (mimeType.startsWith('video/') || _videoExtensions.contains(extension)) {
      return 'video';
    }
    if (mimeType.startsWith('audio/') || _audioExtensions.contains(extension)) {
      return 'audio';
    }

    throw Exception(
      'Archivo no permitido: $fileName. Solo se aceptan imágenes, videos o audio.',
    );
  }

  String? _normalizeNullable(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _normalizeEmail(String? value) {
    final trimmed = _normalizeNullable(value);
    if (trimmed == null) return null;
    if (!_emailRegex.hasMatch(trimmed)) {
      throw Exception('Please enter a valid email (or leave it blank).');
    }
    return trimmed;
  }
}
