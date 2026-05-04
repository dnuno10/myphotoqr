class QrCode {
  const QrCode({
    required this.albumId,
    required this.qrUrl,
    required this.qrImageUrl,
    required this.qrImageStoragePath,
    required this.scanCount,
  });

  final String albumId;
  final String qrUrl;
  final String? qrImageUrl;
  final String? qrImageStoragePath;
  final int scanCount;

  factory QrCode.fromJson(Map<String, dynamic> json) {
    return QrCode(
      albumId: json['album_id'] as String,
      qrUrl: json['qr_url'] as String,
      qrImageUrl: json['qr_image_url'],
      qrImageStoragePath: json['qr_image_storage_path'],
      scanCount: json['scan_count'] ?? 0,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'qr_url': qrUrl,
      'qr_image_url': qrImageUrl,
      'qr_image_storage_path': qrImageStoragePath,
    };
  }

  QrCode copyWith({
    String? qrUrl,
    String? qrImageUrl,
    String? qrImageStoragePath,
    int? scanCount,
  }) {
    return QrCode(
      albumId: albumId,
      qrUrl: qrUrl ?? this.qrUrl,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
      qrImageStoragePath: qrImageStoragePath ?? this.qrImageStoragePath,
      scanCount: scanCount ?? this.scanCount,
    );
  }
}

