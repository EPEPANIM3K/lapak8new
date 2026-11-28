/// Konfigurasi bucket Supabase untuk bukti pemeriksaan pengembalian.
class Lapak8StorageConfig {
  Lapak8StorageConfig._();

  static const String bucket = 'return-documentation';

  // ---- Batas unggah (selaras dengan validasi server) ----------------------
  static const int maxPhotos = 6;
  static const int maxVideos = 1;
  static const int maxPhotoBytes = 8 * 1024 * 1024; // 8 MB
  static const int maxVideoBytes = 100 * 1024 * 1024; // 100 MB

  static const List<String> photoExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'tif',
    'tiff',
    'heic',
    'heif',
    'avif',
    'ico',
    'jxl',
  ];

  static const Map<String, String> mediaMimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'tif': 'image/tiff',
    'tiff': 'image/tiff',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'avif': 'image/avif',
    'ico': 'image/vnd.microsoft.icon',
    'jxl': 'image/jxl',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
  };

  static const List<String> videoExtensions = ['mp4', 'mov', 'webm'];

  static const Duration uploadTimeout = Duration(seconds: 90);
}
