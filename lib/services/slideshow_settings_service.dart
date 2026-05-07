import '../core/supabase_client.dart';
import '../models/slideshow_settings.dart';

class SlideshowSettingsService {
  Future<SlideshowSettings?> get(String albumId) async {
    final row = await supabase
        .from('slideshow_settings')
        .select()
        .eq('album_id', albumId)
        .maybeSingle();

    if (row == null) return null;
    return SlideshowSettings.fromJson(row);
  }

  Future<SlideshowSettings> getOrCreate(String albumId) async {
    final row = await supabase
        .from('slideshow_settings')
        .select()
        .eq('album_id', albumId)
        .maybeSingle();

    if (row != null) {
      return SlideshowSettings.fromJson(row);
    }

    final inserted = await supabase
        .from('slideshow_settings')
        .insert({'album_id': albumId})
        .select()
        .single();

    return SlideshowSettings.fromJson(inserted);
  }

  Future<void> update({
    required String albumId,
    required SlideshowSettings settings,
  }) async {
    await supabase
        .from('slideshow_settings')
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
