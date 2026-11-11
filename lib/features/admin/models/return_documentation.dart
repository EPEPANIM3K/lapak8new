/// Model dokumentasi kondisi barang yang tersimpan di server penyimpanan.
///
/// Semua field berasal dari respons API `/api/v1/inspections/:returnId/docs`,
/// tidak ada data dummy.
library;

enum DocumentationKind { photo, video }

class DocumentationFile {
  const DocumentationFile({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.mime,
    required this.size,
    required this.path,
    required this.uploadedAt,
    this.uploadedBy,
  });

  final String id;
  final DocumentationKind kind;
  final String fileName;
  final String mime;
  final int size;

  /// Path relatif di server (mis. `/api/v1/inspections/KM-1/file/<uuid>`).
  final String path;
  final DateTime uploadedAt;
  final String? uploadedBy;

  bool get isPhoto => kind == DocumentationKind.photo;
  bool get isVideo => kind == DocumentationKind.video;

  static DocumentationFile? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final path = json['url'];
    if (id is! String || path is! String) return null;
    final kindRaw = (json['kind'] as String?)?.toLowerCase();
    return DocumentationFile(
      id: id,
      kind: kindRaw == 'video'
          ? DocumentationKind.video
          : DocumentationKind.photo,
      fileName: (json['fileName'] as String?) ?? 'dokumentasi',
      mime: (json['mime'] as String?) ?? 'application/octet-stream',
      size: (json['size'] as num?)?.toInt() ?? 0,
      path: path,
      uploadedAt:
          DateTime.tryParse((json['uploadedAt'] as String?) ?? '')?.toLocal() ??
              DateTime.now(),
      uploadedBy: json['uploadedBy'] as String?,
    );
  }

  static List<DocumentationFile> parseList(Object? json) {
    if (json is! List) return const [];
    return json
        .map(DocumentationFile.tryParse)
        .whereType<DocumentationFile>()
        .toList(growable: false);
  }
}

/// Kumpulan dokumentasi untuk satu pemeriksaan pengembalian.
class ReturnDocumentation {
  const ReturnDocumentation({
    required this.returnId,
    required this.borrowingId,
    required this.itemId,
    required this.photos,
    required this.video,
    this.updatedAt,
  });

  final String? returnId;
  final String? borrowingId;
  final String? itemId;
  final List<DocumentationFile> photos;
  final DocumentationFile? video;
  final DateTime? updatedAt;

  static const ReturnDocumentation empty = ReturnDocumentation(
    returnId: null,
    borrowingId: null,
    itemId: null,
    photos: [],
    video: null,
  );

  bool get isEmpty => photos.isEmpty && video == null;
  bool get isNotEmpty => !isEmpty;
  int get photoCount => photos.length;
  int get videoCount => video == null ? 0 : 1;
  int get totalFiles => photoCount + videoCount;

  static ReturnDocumentation fromJson(Map<String, dynamic> json) {
    return ReturnDocumentation(
      returnId: json['returnId'] as String?,
      borrowingId: json['borrowingId'] as String?,
      itemId: json['itemId'] as String?,
      photos: DocumentationFile.parseList(json['photos']),
      video: DocumentationFile.tryParse(json['video']),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '')
          ?.toLocal(),
    );
  }
}

/// Berkas lokal yang sudah dipilih tetapi belum diunggah.
class PendingDocumentationFile {
  const PendingDocumentationFile({
    required this.id,
    required this.kind,
    required this.localPath,
    required this.fileName,
    this.bytes,
    required this.size,
  });

  final String id;
  final DocumentationKind kind;

  /// Path file sementara dari image_picker (kosong pada web).
  final String localPath;
  final String fileName;

  /// Isi berkas bila tersedia (web / hasil readAsBytes).
  final List<int>? bytes;
  final int size;

  bool get isPhoto => kind == DocumentationKind.photo;

  String get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }
}

/// Status unggah satu berkas di UI.
enum UploadState { idle, uploading, uploaded, failed }

class DocumentationUploadItem {
  const DocumentationUploadItem({
    required this.file,
    required this.state,
    this.progress,
    this.error,
    this.remote,
  });

  final PendingDocumentationFile file;
  final UploadState state;

  /// 0.0 - 1.0 selama proses unggah.
  final double? progress;
  final String? error;
  final DocumentationFile? remote;

  DocumentationUploadItem copyWith({
    UploadState? state,
    double? progress,
    String? error,
    DocumentationFile? remote,
    bool clearError = false,
  }) {
    return DocumentationUploadItem(
      file: file,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
      remote: remote ?? this.remote,
    );
  }
}

/// Hasil unggah dokumentasi pada satu pemeriksaan pengembalian.
class DocumentationResult {
  const DocumentationResult({
    required this.returnId,
    required this.borrowingId,
    required this.itemId,
    required this.photos,
    required this.video,
    this.warnings = const [],
  });

  final String returnId;
  final String borrowingId;
  final String itemId;
  final List<DocumentationFile> photos;
  final DocumentationFile? video;

  /// Pesan yang tidak menggagalkan penyimpanan pemeriksaan
  /// (mis. satu foto gagal diunggah).
  final List<String> warnings;

  bool get hasFiles => photos.isNotEmpty || video != null;
  int get photoCount => photos.length;
  int get videoCount => video == null ? 0 : 1;

  ReturnDocumentation toDocumentation() => ReturnDocumentation(
        returnId: returnId,
        borrowingId: borrowingId,
        itemId: itemId,
        photos: photos,
        video: video,
        updatedAt: DateTime.now(),
      );
}