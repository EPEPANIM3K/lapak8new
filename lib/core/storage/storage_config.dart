import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Konfigurasi endpoint penyimpanan dokumentasi kondisi barang LAPAK8.
///
/// Base URL dapat dioverride saat build tanpa mengubah kode:
///
///   flutter run --dart-define=LAPAK8_STORAGE_BASE_URL=http://192.168.1.10:8787
///
/// Nilai default menyesuaikan platform emulator:
/// - Android emulator : 10.0.2.2 (loopback host)
/// - lainnya          : 127.0.0.1
class Lapak8StorageConfig {
  Lapak8StorageConfig._();

  static const String _envBaseUrl =
      String.fromEnvironment('LAPAK8_STORAGE_BASE_URL');

  /// Token akses petugas/admin. Produksi: isi dari sesi login.
  static const String _envToken = String.fromEnvironment(
    'LAPAK8_STORAGE_TOKEN',
    defaultValue: 'lapak8-dev-token',
  );

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _stripTrailingSlash(_envBaseUrl);
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8787';
    }
    return 'http://127.0.0.1:8787';
  }

  /// Override runtime (dipakai bila token diambil dari sesi login).
  static String? _runtimeToken;

  static set authToken(String? token) {
    _runtimeToken = (token == null || token.trim().isEmpty) ? null : token.trim();
  }

  static String get authToken => _runtimeToken ?? _envToken;

  static bool get hasToken => authToken.isNotEmpty;

  static Uri uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  /// Path absolut (bukan URL) untuk file dokumentasi.
  /// Server mengembalikan path relatif; endpoint butuh header otorisasi,
  /// jadi pemutaran/preview harus lewat [mediaHeaders].
  static String absoluteUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    return '$baseUrl${pathOrUrl.startsWith('/') ? '' : '/'}$pathOrUrl';
  }

  static Map<String, String> get mediaHeaders => {
        'authorization': 'Bearer $authToken',
      };

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  // ---- Batas unggah (selaras dengan validasi server) ----------------------
  static const int maxPhotos = 6;
  static const int maxVideos = 1;
  static const int maxPhotoBytes = 8 * 1024 * 1024; // 8 MB
  static const int maxVideoBytes = 100 * 1024 * 1024; // 100 MB

  static const List<String> photoExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> videoExtensions = ['mp4', 'mov', 'webm'];

  static const Duration uploadTimeout = Duration(seconds: 90);
}