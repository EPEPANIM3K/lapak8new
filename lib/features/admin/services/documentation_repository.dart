import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lapak8new/core/storage/storage_config.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';

/// Kegagalan pemanggilan penyimpanan dokumentasi pemeriksaan.
class StorageApiException implements Exception {
  const StorageApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Repository metadata dan berkas bukti yang tersimpan di Supabase.
class DocumentationRepository {
  DocumentationRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  static const int maxPhotos = Lapak8StorageConfig.maxPhotos;
  static const int maxVideos = Lapak8StorageConfig.maxVideos;
  static const int maxPhotoBytes = Lapak8StorageConfig.maxPhotoBytes;
  static const int maxVideoBytes = Lapak8StorageConfig.maxVideoBytes;

  Future<ReturnDocumentation> fetchDocumentation(String returnId) async {
    try {
      final rows = await _db
          .from('return_documentation')
          .select(
            'borrowing_id, item_id, file_id, jenis, file_name, file_path, '
            'mime_type, ukuran_byte, diunggah_oleh, diunggah_pada',
          )
          .eq('return_inspection_id', returnId)
          .order('diunggah_pada', ascending: false);
      final files = (rows as List<dynamic>)
          .map((row) => _fileFromRow(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
      final records = rows as List<dynamic>;
      final firstRow = files.isEmpty
          ? null
          : Map<String, dynamic>.from(records.first as Map);
      final videos = files.where((file) => file.isVideo).toList();
      return ReturnDocumentation(
        returnId: returnId,
        borrowingId: firstRow?['borrowing_id'] as String?,
        itemId: firstRow?['item_id'] as String?,
        photos: files.where((file) => file.isPhoto).toList(growable: false),
        video: videos.isEmpty ? null : videos.first,
        updatedAt: files.isEmpty ? null : files.first.uploadedAt,
      );
    } on PostgrestException catch (error) {
      throw StorageApiException(
        'Gagal memuat metadata bukti dari Supabase: ${error.message}',
        code: error.code,
      );
    }
  }

  Future<DocumentationFile> uploadFile({
    required String returnId,
    required String borrowingId,
    required String itemId,
    required PendingDocumentationFile file,
    void Function(double progress)? onProgress,
  }) async {
    _assertUploadable(file);
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StorageApiException(
        'Isi berkas "${file.fileName}" tidak tersedia. Pilih ulang berkas tersebut.',
        code: 'missing_file_bytes',
      );
    }
    if (bytes.length != file.size) {
      throw StorageApiException(
        'Ukuran berkas "${file.fileName}" berubah sebelum diunggah.',
        code: 'file_size_mismatch',
      );
    }

    final mime = Lapak8StorageConfig.mediaMimeTypes[file.extension];
    if (mime == null) {
      throw StorageApiException(
        'Tipe berkas "${file.fileName}" tidak didukung.',
        code: 'unsupported_format',
      );
    }
    final objectPath =
        '${_safePathSegment(returnId)}/${_safePathSegment(file.id)}';

    onProgress?.call(0);
    try {
      await _db.storage
          .from(Lapak8StorageConfig.bucket)
          .uploadBinary(
            objectPath,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
    } on StorageException catch (error) {
      throw StorageApiException(
        'Gagal mengunggah bukti ke Supabase Storage: ${error.message}',
        code: 'storage_upload_failed',
      );
    }
    onProgress?.call(1);

    return DocumentationFile(
      id: file.id,
      kind: file.kind,
      fileName: file.fileName,
      mime: mime,
      size: bytes.length,
      path: objectPath,
      uploadedAt: DateTime.now(),
      uploadedBy: _db.auth.currentUser?.id,
    );
  }

  /// Unggah semua berkas terpilih; kegagalan per berkas dilaporkan sebagai
  /// peringatan agar alur pemeriksaan dapat menampilkan hasilnya dengan jelas.
  Future<DocumentationResult> uploadAll({
    required String returnId,
    required String borrowingId,
    required String itemId,
    required List<PendingDocumentationFile> photos,
    PendingDocumentationFile? video,
    void Function(String fileId, double progress)? onProgress,
    void Function(String fileId, DocumentationFile remote)? onUploaded,
    void Function(String fileId, String message)? onFailed,
  }) async {
    final uploadedPhotos = <DocumentationFile>[];
    final warnings = <String>[];
    DocumentationFile? uploadedVideo;

    for (final photo in photos) {
      try {
        final remote = await uploadFile(
          returnId: returnId,
          borrowingId: borrowingId,
          itemId: itemId,
          file: photo,
          onProgress: (progress) => onProgress?.call(photo.id, progress),
        );
        uploadedPhotos.add(remote);
        onUploaded?.call(photo.id, remote);
      } on StorageApiException catch (error) {
        warnings.add(
          'Foto "${photo.fileName}" gagal diunggah: ${error.message}',
        );
        onFailed?.call(photo.id, error.message);
      }
    }

    if (video != null) {
      try {
        uploadedVideo = await uploadFile(
          returnId: returnId,
          borrowingId: borrowingId,
          itemId: itemId,
          file: video,
          onProgress: (progress) => onProgress?.call(video.id, progress),
        );
        onUploaded?.call(video.id, uploadedVideo);
      } on StorageApiException catch (error) {
        warnings.add(
          'Video "${video.fileName}" gagal diunggah: ${error.message}',
        );
        onFailed?.call(video.id, error.message);
      }
    }

    return DocumentationResult(
      returnId: returnId,
      borrowingId: borrowingId,
      itemId: itemId,
      photos: uploadedPhotos,
      video: uploadedVideo,
      warnings: warnings,
    );
  }

  Future<ReturnDocumentation> deleteFile({
    required String returnId,
    required String fileId,
  }) async {
    final row = await _db
        .from('return_documentation')
        .select('file_path')
        .eq('return_inspection_id', returnId)
        .eq('file_id', fileId)
        .maybeSingle();
    if (row == null) {
      throw const StorageApiException(
        'Bukti pemeriksaan yang akan dihapus tidak ditemukan.',
        code: 'file_not_found',
      );
    }

    try {
      await _db.storage.from(Lapak8StorageConfig.bucket).remove([
        row['file_path'] as String,
      ]);
    } on StorageException catch (error) {
      throw StorageApiException(
        'Gagal menghapus bukti dari Supabase Storage: ${error.message}',
        code: 'storage_delete_failed',
      );
    }

    try {
      await _db
          .from('return_documentation')
          .delete()
          .eq('return_inspection_id', returnId)
          .eq('file_id', fileId);
    } on PostgrestException catch (error) {
      throw StorageApiException(
        'Berkas terhapus, tetapi metadata bukti gagal diperbarui: '
        '${error.message}',
        code: error.code,
      );
    }
    return fetchDocumentation(returnId);
  }

  void _assertUploadable(PendingDocumentationFile file) {
    final allowed = file.isPhoto
        ? Lapak8StorageConfig.photoExtensions
        : Lapak8StorageConfig.videoExtensions;
    if (!allowed.contains(file.extension)) {
      throw StorageApiException(
        file.isPhoto
            ? 'Format foto yang didukung: JPG, PNG, WEBP, GIF, BMP, TIFF, '
                  'HEIC/HEIF, AVIF, ICO, dan JXL.'
            : 'Format video harus MP4, MOV, atau WEBM.',
        code: 'unsupported_format',
      );
    }
    final limit = file.isPhoto ? maxPhotoBytes : maxVideoBytes;
    if (file.size > limit) {
      throw StorageApiException(
        '${file.isPhoto ? 'Foto' : 'Video'} "${file.fileName}" melebihi batas '
        '${file.isPhoto ? '8' : '100'} MB.',
        code: 'file_too_large',
      );
    }
    if (file.size == 0) {
      throw StorageApiException(
        'Berkas "${file.fileName}" kosong.',
        code: 'empty_file',
      );
    }
  }

  DocumentationFile _fileFromRow(Map<String, dynamic> row) {
    final id = row['file_id'];
    final path = row['file_path'];
    final kind = row['jenis'];
    final uploadedAt = row['diunggah_pada'];
    if (id is! String ||
        path is! String ||
        (kind != 'photo' && kind != 'video') ||
        uploadedAt is! String) {
      throw const StorageApiException(
        'Metadata bukti pemeriksaan dari database tidak valid.',
        code: 'invalid_metadata',
      );
    }
    final date = DateTime.tryParse(uploadedAt);
    if (date == null) {
      throw const StorageApiException(
        'Waktu unggah bukti pemeriksaan tidak valid.',
        code: 'invalid_metadata',
      );
    }

    return DocumentationFile(
      id: id,
      kind: kind == 'video' ? DocumentationKind.video : DocumentationKind.photo,
      fileName: row['file_name'] as String? ?? 'Bukti pemeriksaan',
      mime: row['mime_type'] as String? ?? 'application/octet-stream',
      size: (row['ukuran_byte'] as num?)?.toInt() ?? 0,
      path: path,
      uploadedAt: date.toLocal(),
      uploadedBy: row['diunggah_oleh'] as String?,
    );
  }

  String _safePathSegment(String value) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(value)) {
      throw const StorageApiException(
        'Identitas berkas pemeriksaan tidak valid.',
        code: 'invalid_path',
      );
    }
    return value;
  }
}
