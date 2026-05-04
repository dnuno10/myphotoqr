import '../core/supabase_client.dart';

class AlbumExportService {
  Future<Uri> exportAlbumZip({
    required String albumId,
    String? guestCode,
  }) async {
    final response = await supabase.functions.invoke(
      'album-export-myphotoqr',
      body: {
        'mode': 'create_export',
        'album_id': albumId,
        if ((guestCode ?? '').trim().isNotEmpty) 'guest_code': guestCode!.trim(),
      },
    );

    final data = response.data;

    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    if (data is! Map || data['url'] == null) {
      throw Exception('Export URL was not returned.');
    }

    final url = data['url'].toString();
    final uri = Uri.tryParse(url);
    if (uri == null) throw Exception('Invalid export URL.');
    return uri;
  }
}
