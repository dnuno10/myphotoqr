import '../core/supabase_client.dart';

class AlbumExportService {
  static const List<String> _functionCandidates = [
    'album-export-myphotoqr',
    'album-export',
  ];

  Future<Uri> exportAlbumZip({
    required String albumId,
    String? guestCode,
  }) async {
    Object? lastError;
    for (final functionName in _functionCandidates) {
      try {
        final response = await supabase.functions.invoke(
          functionName,
          body: {
            'mode': 'create_export',
            'album_id': albumId,
            if ((guestCode ?? '').trim().isNotEmpty)
              'guest_code': guestCode!.trim(),
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
      } catch (e) {
        lastError = e;
        final msg = e.toString().toLowerCase();
        final isNotFound =
            msg.contains('status: 404') ||
            msg.contains('not_found') ||
            msg.contains('requested function was not found');
        if (!isNotFound) rethrow;
      }
    }

    throw Exception(lastError?.toString() ?? 'Could not export album.');
  }
}
