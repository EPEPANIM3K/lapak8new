import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaUploadException implements Exception {
  const MediaUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Helper untuk mengunggah gambar (format apapun) ke Supabase Storage.
class SupabaseMediaService {
  SupabaseClient get _db => Supabase.instance.client;

  /// Mengunggah [bytes] ke bucket utama [primaryBucket] pada sub-folder [folder].
  /// Jika bucket utama belum tersedia di project Supabase, mencoba bucket
  /// cadangan ('media', 'images', 'public') sebelum melempar error.
  Future<String> uploadImage({
    required String primaryBucket,
    required String folder,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final mimeType =
        lookupMimeType(fileName, headerBytes: bytes) ?? 'image/png';
    final ext = _resolveExtension(fileName, mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final objectPath = '$folder/$timestamp.$ext';

    final bucketsToTry = <String>{
      primaryBucket,
      'media',
      'images',
      'public',
    }.toList();

    StorageException? lastError;
    for (final bucket in bucketsToTry) {
      try {
        await _db.storage.from(bucket).uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(
                contentType: mimeType,
                upsert: true,
              ),
            );
        return _db.storage.from(bucket).getPublicUrl(objectPath);
      } on StorageException catch (e) {
        lastError = e;
        final msg = e.message.toLowerCase();
        // Lanjut coba bucket cadangan hanya jika bucket tidak ditemukan.
        if (msg.contains('not found') || msg.contains('bucket')) {
          continue;
        }
        throw MediaUploadException(
          'Gagal mengunggah foto ke penyimpanan ($bucket): ${e.message}',
        );
      }
    }

    throw MediaUploadException(
      'Bucket penyimpanan "$primaryBucket" belum tersedia di Supabase Storage. '
      'Buat bucket publik "$primaryBucket" di Dashboard Supabase. '
      '(${lastError?.message ?? 'unknown error'})',
    );
  }

  static String _resolveExtension(String fileName, String mimeType) {
    final dot = fileName.lastIndexOf('.');
    if (dot != -1 && dot < fileName.length - 1) {
      final raw = fileName.substring(dot + 1).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (raw.isNotEmpty) return raw;
    }
    final fromMime = extensionFromMime(mimeType);
    if (fromMime != null && fromMime.isNotEmpty) return fromMime;
    return 'png';
  }
}

final supabaseMediaService = SupabaseMediaService();
