import '../core/supabase_client.dart';

class AlbumExportException implements Exception {
  const AlbumExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AlbumExportService {
  static const List<String> _functionCandidates = [
    'album-export-myphotoqr',
    'album-export',
  ];

  Future<Uri> exportAlbumZip({
    required String albumId,
    String? guestCode,
  }) async {
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
          throw const AlbumExportException(
            'We could not prepare the ZIP export. Please try again in a moment.',
          );
        }

        if (data is! Map || data['url'] == null) {
          throw const AlbumExportException(
            'We could not prepare the ZIP export. Please try again in a moment.',
          );
        }

        final url = data['url'].toString();
        final uri = Uri.tryParse(url);
        if (uri == null) {
          throw const AlbumExportException(
            'We could not prepare the ZIP export. Please try again in a moment.',
          );
        }
        return uri;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final isNotFound =
            msg.contains('status: 404') ||
            msg.contains('not_found') ||
            msg.contains('requested function was not found');
        if (!isNotFound) rethrow;
      }
    }

    throw const AlbumExportException(
      'ZIP export is not available right now. Please try again later.',
    );
  }
}
