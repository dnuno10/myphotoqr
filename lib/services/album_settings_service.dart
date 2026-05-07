import '../core/supabase_client.dart';
import '../models/album_settings.dart';

class AlbumSettingsService {
  Future<AlbumSettings?> get(String albumId) async {
    final row = await supabase
        .from('album_settings')
        .select()
        .eq('album_id', albumId)
        .maybeSingle();

    if (row == null) return null;
    return AlbumSettings.fromJson(row);
  }

  Future<AlbumSettings> getOrCreate(String albumId) async {
    final row = await supabase
        .from('album_settings')
        .select()
        .eq('album_id', albumId)
        .maybeSingle();

    if (row != null) {
      return AlbumSettings.fromJson(row);
    }

    final inserted = await supabase
        .from('album_settings')
        .insert({'album_id': albumId})
        .select()
        .single();

    return AlbumSettings.fromJson(inserted);
  }

  Future<void> update({
    required String albumId,
    required AlbumSettings settings,
  }) async {
    await supabase
        .from('album_settings')
        .upsert(
          {
            'album_id': albumId,
            ...settings.toUpdateJson(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'album_id',
        );
  }
}
