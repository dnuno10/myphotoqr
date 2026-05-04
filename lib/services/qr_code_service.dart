import '../core/app_config.dart';
import '../core/supabase_client.dart';
import '../models/qr_code.dart';

class QrCodeService {
  Future<QrCode> getOrCreate({
    required String albumId,
    required String albumSlug,
  }) async {
    final row = await supabase
        .from('qr_codes')
        .select()
        .eq('album_id', albumId)
        .maybeSingle();

    if (row != null) {
      return QrCode.fromJson(row);
    }

    final qrUrl = '${AppConfig.appPublicBaseUrl}/a/$albumSlug/upload';

    final inserted = await supabase
        .from('qr_codes')
        .insert({
          'album_id': albumId,
          'qr_url': qrUrl,
        })
        .select()
        .single();

    return QrCode.fromJson(inserted);
  }

  Future<void> update({
    required String albumId,
    required QrCode qrCode,
  }) async {
    await supabase
        .from('qr_codes')
        .update({
          ...qrCode.toUpdateJson(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('album_id', albumId);
  }
}

