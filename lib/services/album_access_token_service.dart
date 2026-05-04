import 'package:uuid/uuid.dart';

import '../core/supabase_client.dart';
import '../models/album_access_token.dart';

class AlbumAccessTokenService {
  final _uuid = const Uuid();

  Future<List<AlbumAccessToken>> listTokens(String albumId) async {
    final rows = await supabase
        .from('album_access_tokens')
        .select()
        .eq('album_id', albumId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((e) => AlbumAccessToken.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AlbumAccessToken> createToken({
    required String albumId,
    required String type,
    DateTime? expiresAt,
    bool isActive = true,
  }) async {
    final token = _uuid.v4();

    final inserted = await supabase
        .from('album_access_tokens')
        .insert({
          'album_id': albumId,
          'token': token,
          'type': type,
          'is_active': isActive,
          'expires_at': expiresAt?.toIso8601String(),
        })
        .select()
        .single();

    return AlbumAccessToken.fromJson(inserted);
  }

  Future<void> updateToken(AlbumAccessToken token) async {
    await supabase
        .from('album_access_tokens')
        .update(token.toUpdateJson())
        .eq('id', token.id);
  }

  Future<void> deleteToken(String tokenId) async {
    await supabase.from('album_access_tokens').delete().eq('id', tokenId);
  }
}

