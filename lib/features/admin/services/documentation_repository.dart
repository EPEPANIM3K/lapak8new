import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:lapak8new/core/storage/storage_config.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';

/// Kegagalan pemanggilan API penyimpanan dokumentasi.
class StorageApiException implements Exception {
  StorageApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Klien HTTP untuk layanan penyimpanan dokumentasi kondisi barang.
///
/// Endpoint yang dipakai:
/// - `GET    /api/v1/inspections/:returnId/docs`
/// - `POST   /api/v1/inspections/:returnId/upload`  (multipart, 1 berkas/request)
/// - `DELETE /api/v1/inspections/:returnId/files/:fileId`
/// - `GET    /api/v1/inspections/:returnId/file/:fileId` (stream, dukung Range)
class DocumentationRepository {
  DocumentationRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Batas unggah sinkron dengan validasi server.
  static const int maxPhotos = Lapak8StorageConfig.maxPhotos;
  static const int maxVideos = Lapak8StorageConfig.maxVideos;
  static const int maxPhotoBytes = Lapak8StorageConfig.maxPhotoBytes;
  static const int maxVideoBytes = Lapak8StorageConfig.maxVideoBytes;

  void dispose() => _client.close();

  // -------------------------------------------------------------------------
  // Metadata
  // -------------------------------------------------------------------------
  Future<ReturnDocumentation> fetchDocumentation(String returnId) async {
    final uri = Lapak8StorageConfig.uri(_docsPath(returnId));
    final res = await _send(
      () => _client.get(uri, headers: _headers()),
    );
    final data = _decode(res);
    final payload = data['data'];
    if (payload is! Map<String, dynamic>) {
      throw StorageApiException('Respons dokumentasi tidak valid.',
          statusCode: res.statusCode);
    }
    return ReturnDocumentation.fromJson(payload);
  }

  // -------------------------------------------------------------------------
  // Unggah satu berkas
  // -------------------------------------------------------------------------
  Future<DocumentationFile> uploadFile({
    required String returnId,
    required String borrowingId,
    required String itemId,
    required PendingDocumentationFile file,
    void Function(double progress)? onProgress,
  }) async {
    _assertUploadable(file);

    final uri = Lapak8StorageConfig.uri(
      _uploadPath(returnId),
      {'borrowingId': borrowingId, 'itemId': itemId},
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        ..._headers(),
        'x-borrowing-id': borrowingId,
        'x-item-id': itemId,
      })
      ..fields['kind'] = file.isPhoto ? 'photo' : 'video'
      ..fields['fileName'] = file.fileName;

    final bytes = file.bytes;
    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.fileName),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath('file', file.localPath,
            filename: file.fileName),
      );
    }

    final totalBytes = request.contentLength;
    onProgress?.call(0);

    final streamed = await _withTimeout(() => _client.send(request));
    final chunks = <int>[];
    var received = 0;

    await for (final chunk in streamed.stream) {
      received += chunk.length;
      chunks.addAll(chunk);
      if (totalBytes > 0) {
        onProgress?.call((received / totalBytes).clamp(0.0, 1.0));
      }
    }

    final res = http.Response.bytes(chunks, streamed.statusCode,
        headers: streamed.headers);
    final data = _decode(res);
    final payload = data['data'];
    if (payload is Map) {
      final remote = DocumentationFile.tryParse(payload['file']);
      onProgress?.call(1);
      if (remote != null) return remote;
    }
    throw StorageApiException('Respons unggah tidak valid.',
        statusCode: res.statusCode);
  }

  /// Unggah seluruh dokumentasi yang dipilih. Berkas yang gagal tidak
  /// membatalkan yang lain; kegagalannya dilaporkan via [DocumentationResult.warnings].
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
          onProgress: (p) => onProgress?.call(photo.id, p),
        );
        uploadedPhotos.add(remote);
        onUploaded?.call(photo.id, remote);
      } on StorageApiException catch (e) {
        warnings.add('Foto "${photo.fileName}" gagal diunggah: ${e.message}');
        onFailed?.call(photo.id, e.message);
      }
    }

    if (video != null) {
      try {
        uploadedVideo = await uploadFile(
          returnId: returnId,
          borrowingId: borrowingId,
          itemId: itemId,
          file: video,
          onProgress: (p) => onProgress?.call(video.id, p),
        );
        onUploaded?.call(video.id, uploadedVideo);
      } on StorageApiException catch (e) {
        warnings.add('Video "${video.fileName}" gagal diunggah: ${e.message}');
        onFailed?.call(video.id, e.message);
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

  // -------------------------------------------------------------------------
  // Hapus
  // -------------------------------------------------------------------------
  Future<ReturnDocumentation> deleteFile({
    required String returnId,
    required String fileId,
  }) async {
    final uri = Lapak8StorageConfig.uri(_deletePath(returnId, fileId));
    final res = await _send(
      () => _client.delete(uri, headers: _headers()),
    );
    final data = _decode(res);
    final payload = data['data'];
    if (payload is Map<String, dynamic>) {
      return ReturnDocumentation.fromJson(payload);
    }
    throw StorageApiException('Respons hapus dokumentasi tidak valid.',
        statusCode: res.statusCode);
  }

  // -------------------------------------------------------------------------
  // Validasi lokal sebelum unggah
  // -------------------------------------------------------------------------
  void _assertUploadable(PendingDocumentationFile file) {
    final ext = file.extension;
    final allowed = file.isPhoto
        ? Lapak8StorageConfig.photoExtensions
        : Lapak8StorageConfig.videoExtensions;
    if (!allowed.contains(ext)) {
      throw StorageApiException(
        file.isPhoto
            ? 'Format foto harus JPG, JPEG, PNG, atau WEBP.'
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
      throw StorageApiException('Berkas "${file.fileName}" kosong.',
          code: 'empty_file');
    }
  }

  /// Baca header gambar untuk memastikan isi berkas benar, bukan sekadar nama.
  Future<bool> isRealImage(List<int> bytes) async {
    if (bytes.length < 12) return false;
    final head = bytes.sublist(0, 12);
    final isJpeg = head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF;
    final isPng = head[0] == 0x89 &&
        head[1] == 0x50 &&
        head[2] == 0x4E &&
        head[3] == 0x47;
    final isWebp = head[0] == 0x52 &&
        head[1] == 0x49 &&
        head[2] == 0x46 &&
        head[3] == 0x46 &&
        head[8] == 0x57 &&
        head[9] == 0x45 &&
        head[10] == 0x42 &&
        head[11] == 0x50;
    return isJpeg || isPng || isWebp;
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------
  Map<String, String> _headers() => {
        'authorization': 'Bearer ${Lapak8StorageConfig.authToken}',
        'accept': 'application/json',
      };

  String _docsPath(String returnId) =>
      '/api/v1/inspections/${Uri.encodeComponent(returnId)}/docs';

  String _uploadPath(String returnId) =>
      '/api/v1/inspections/${Uri.encodeComponent(returnId)}/upload';

  String _deletePath(String returnId, String fileId) =>
      '/api/v1/inspections/${Uri.encodeComponent(returnId)}/files/'
      '${Uri.encodeComponent(fileId)}';

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      final res = await _withTimeout(call);
      return res;
    } on StorageApiException {
      rethrow;
    } catch (e) {
      throw StorageApiException(
        'Tidak dapat menghubungi penyimpanan dokumentasi. '
        'Periksa koneksi atau server storage. ($e)',
      );
    }
  }

  Future<T> _withTimeout<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(Lapak8StorageConfig.uploadTimeout);
    } on TimeoutException {
      throw StorageApiException(
        'Unggahan melebihi batas waktu. Coba lagi dengan berkas lebih kecil.',
        code: 'timeout',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      json = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json ?? const <String, dynamic>{'ok': false};
    }

    final error = json?['error'];
    final message = error is Map ? error['message'] as String? : null;
    final code = error is Map ? error['code'] as String? : null;
    throw StorageApiException(
      message ?? _defaultMessage(res.statusCode),
      code: code,
      statusCode: res.statusCode,
    );
  }

  String _defaultMessage(int status) {
    switch (status) {
      case 401:
        return 'Sesi penyimpanan tidak valid. Silakan login kembali.';
      case 403:
        return 'Anda tidak memiliki akses untuk mengubah dokumentasi.';
      case 409:
        return 'Batas jumlah dokumentasi tercapai.';
      case 413:
        return 'Ukuran berkas terlalu besar.';
      case 415:
        return 'Format berkas tidak didukung.';
      default:
        return 'Penyimpanan dokumentasi gagal (kode $status).';
    }
  }
}