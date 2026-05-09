import 'dart:math';

import '../core/app_config.dart';
import '../core/supabase_client.dart';
import '../models/album.dart';

class AlbumService {
  String _slugify(String value) {
    final cleaned = value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');

    final suffix = Random().nextInt(99999).toString().padLeft(5, '0');
    return '${cleaned.isEmpty ? 'album' : cleaned}-$suffix';
  }

  Future<Map<String, dynamic>> getOrCreateCurrentUser() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) throw Exception('Not authenticated.');

    final existing = await supabase
        .from('users')
        .select()
        .eq('auth_user_id', authUser.id)
        .maybeSingle();

    if (existing != null) return existing;

    return await supabase
        .from('users')
        .insert({'auth_user_id': authUser.id, 'email': authUser.email})
        .select()
        .single();
  }

  Future<List<Album>> getMyAlbums() async {
    final profile = await getOrCreateCurrentUser();

    final rows = await supabase
        .from('albums')
        .select()
        .eq('user_id', profile['id'])
        .order('created_at', ascending: false);

    return rows.map<Album>((row) => Album.fromJson(row)).toList();
  }

  Future<Album> createAlbum({
    required String title,
    required String eventType,
    String? description,
    DateTime? eventDate,
    String? eventLocation,
    String? themeColor,
    bool codeProtected = false,
    String? guestCode,
  }) async {
    final profile = await getOrCreateCurrentUser();
    final slug = _slugify(title);

    String? codeHash;
    if (codeProtected && guestCode != null && guestCode.trim().isNotEmpty) {
      codeHash =
          await supabase.rpc(
                'hash_guest_access_code',
                params: {'code': guestCode.trim()},
              )
              as String;
    }

    final inserted = await supabase
        .from('albums')
        .insert({
          'user_id': profile['id'],
          'title': title.trim(),
          'slug': slug,
          'description': description?.trim(),
          'event_type': eventType,
          'event_date': eventDate?.toIso8601String().substring(0, 10),
          'event_location': eventLocation?.trim(),
          'theme_color': themeColor ?? '#00A63E',
          'visibility': codeProtected ? 'code_protected' : 'public',
          'guest_access_code_enabled': codeProtected,
          'guest_access_code_hash': codeHash,
          'guest_access_code_hint': codeProtected ? 'Code required' : null,
          'status': 'active',
          'upload_enabled': true,
          'gallery_enabled': true,
        })
        .select()
        .single();

    return Album.fromJson(inserted);
  }

  Future<Album> getAlbumById(String id) async {
    final row = await supabase.from('albums').select().eq('id', id).single();
    return Album.fromJson(row);
  }

  Future<Album> updateAlbum({
    required String albumId,
    required Map<String, dynamic> patch,
  }) async {
    final updated = await supabase
        .from('albums')
        .update({...patch, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', albumId)
        .select()
        .single();

    return Album.fromJson(updated);
  }

  Future<void> deleteAlbum({required String albumId}) async {
    await supabase.rpc('delete_album', params: {'album_uuid': albumId});
  }

  Future<String> hashGuestAccessCode(String code) async {
    final hash = await supabase.rpc(
      'hash_guest_access_code',
      params: {'code': code.trim()},
    );
    return hash as String;
  }

  Future<Album> getAlbumBySlug(String slug) async {
    final row = await supabase
        .from('albums')
        .select()
        .eq('slug', slug)
        .single();
    return Album.fromJson(row);
  }

  String publicAlbumUrl(String slug) => '${AppConfig.appPublicBaseUrl}/a/$slug';

  String publicUploadUrl(String slug) =>
      '${AppConfig.appPublicBaseUrl}/a/$slug/upload';

  String slideshowUrl(String slug) =>
      '${AppConfig.appPublicBaseUrl}/slideshow/$slug';
}
