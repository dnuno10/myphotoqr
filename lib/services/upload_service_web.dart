// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:typed_data';

import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/app_config.dart';
import '../core/supabase_client.dart';

class UploadService {
  static const _photoExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };
  static const _videoExtensions = {'mp4', 'mov', 'm4v', 'webm', 'avi'};
  static const _audioExtensions = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'webm'};
  static final _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  final _uuid = const Uuid();

  Future<bool> hasAlbumAccess({required String albumId}) async {
    final result = await supabase.rpc(
      'has_album_access',
      params: {'album_uuid': albumId},
    );
    return result == true;
  }

  Future<Map<String, dynamic>> getOrCreateGuest({
    required String albumId,
    String? name,
    String? email,
    bool accessCodeUsed = false,
  }) async {
    final guestId = _uuid.v4();
    final deviceId =
        'guest-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4()}';

    final normalizedName = _normalizeNullable(name);
    final normalizedEmail = _normalizeEmail(email);

    await supabase.from('guests').insert({
      'id': guestId,
      'album_id': albumId,
      'name': normalizedName,
      'email': normalizedEmail,
      'device_id': deviceId,
      'access_code_used': accessCodeUsed,
      'last_seen_at': DateTime.now().toIso8601String(),
    });

    return {'id': guestId};
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
    final originalName = pickedFile.name;
    var extension = p.extension(originalName).replaceAll('.', '').toLowerCase();
    final bytes = pickedFile.bytes;
    if (bytes == null) {
      throw Exception('Could not read the selected file in this browser.');
    }

    var mimeType =
        lookupMimeType(originalName, headerBytes: bytes) ??
        _fallbackMimeType(extension);
    final mediaType = _mediaTypeFromFile(
      fileName: originalName,
      extension: extension,
      mimeType: mimeType,
    );

    Uint8List uploadBytes = bytes;

    if (_isHeic(extension, mimeType)) {
      final converted = await _convertHeicToJpeg(bytes, mimeType);
      uploadBytes = converted;
      extension = 'jpg';
      mimeType = 'image/jpeg';
    }

    final storagePath = '$albumId/${_uuid.v4()}.$extension';

    await supabase.storage
        .from(AppConfig.albumMediaBucket)
        .uploadBinary(
          storagePath,
          uploadBytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final publicUrl = supabase.storage
        .from(AppConfig.albumMediaBucket)
        .getPublicUrl(storagePath);

    await supabase.from('media_uploads').insert({
      'album_id': albumId,
      'guest_id': guestId,
      'type': mediaType,
      'file_url': publicUrl,
      'storage_path': storagePath,
      'original_file_name': originalName,
      'file_extension': extension,
      'mime_type': mimeType,
      'file_size_bytes': uploadBytes.lengthInBytes,
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

  bool _isHeic(String extension, String mimeType) {
    if (extension == 'heic' || extension == 'heif') return true;
    return mimeType.toLowerCase() == 'image/heic' ||
        mimeType.toLowerCase() == 'image/heif';
  }

  String _fallbackMimeType(String extension) {
    if (extension == 'heic') return 'image/heic';
    if (extension == 'heif') return 'image/heif';
    return 'application/octet-stream';
  }

  Future<Uint8List> _convertHeicToJpeg(
    Uint8List heicBytes,
    String sourceMimeType,
  ) async {
    // Uses `heic2any` injected in `web/index.html`.
    final blob = html.Blob([heicBytes], sourceMimeType);

    final promise = js_util.callMethod(html.window, 'heic2any', [
      {'blob': blob, 'toType': 'image/jpeg', 'quality': 0.9},
    ]);

    final result = await js_util.promiseToFuture<dynamic>(promise);
    final outBlob = (result is List && result.isNotEmpty)
        ? result.first
        : result;
    if (outBlob is! html.Blob) {
      throw Exception('Could not convert HEIC to JPG in this browser.');
    }

    return await _readBlobBytes(outBlob);
  }

  Future<Uint8List> _readBlobBytes(html.Blob blob) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();

    reader.onError.listen((_) {
      if (completer.isCompleted) return;
      completer.completeError(Exception('Could not read converted image.'));
    });

    reader.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;
      final data = reader.result;
      if (data is ByteBuffer) {
        completer.complete(Uint8List.view(data));
      } else {
        completer.completeError(Exception('Could not read converted image.'));
      }
    });

    reader.readAsArrayBuffer(blob);
    return completer.future;
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
      'File not allowed: $fileName. Only images, videos, or audio are accepted.',
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
