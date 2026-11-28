import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:lapak8new/core/storage/storage_config.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';

/// Sumber pemilihan berkas dokumentasi.
enum MediaSource {
  /// Kamera perangkat (foto) atau perekaman video langsung.
  camera,

  /// Galeri foto / penyimpanan berkas.
  gallery,
}

/// Hasil pemilihan yang perlu dilaporkan ke pengguna.
class MediaPickOutcome {
  const MediaPickOutcome({this.files = const [], this.message});

  final List<PendingDocumentationFile> files;
  final String? message;
}

/// Pemilih foto & video terdokumentasi untuk form Cek Kondisi, profil, dan item.
///
/// Memakai `image_picker` sehingga mendukung:
/// - foto dari kamera maupun galeri dengan format gambar apapun
/// - video direkam dari kamera atau dipilih dari penyimpanan
class MediaPickerService {
  MediaPickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int _maxPhotoWidth = 1920;
  static const int _maxPhotoQuality = 85;
  static const Duration _maxVideoDuration = Duration(minutes: 2);

  /// Ambil foto. Mendukung format gambar apapun.
  Future<MediaPickOutcome> pickPhotos({
    required MediaSource source,
    required int remainingSlots,
  }) async {
    if (remainingSlots <= 0) {
      return const MediaPickOutcome(
        message: 'Jumlah foto sudah mencapai maksimal 6.',
      );
    }

    if (source == MediaSource.camera) {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxPhotoWidth.toDouble(),
        imageQuality: _maxPhotoQuality,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (shot == null) return const MediaPickOutcome();
      return _toOutcome([shot], maxAccepted: remainingSlots);
    }

    if (remainingSlots == 1) {
      final single = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxPhotoWidth.toDouble(),
        imageQuality: _maxPhotoQuality,
      );
      if (single == null) return const MediaPickOutcome();
      return _toOutcome([single], maxAccepted: 1);
    }

    final picks = await _picker.pickMultiImage(
      maxWidth: _maxPhotoWidth.toDouble(),
      imageQuality: _maxPhotoQuality,
      limit: remainingSlots,
    );
    if (picks.isEmpty) return const MediaPickOutcome();
    return _toOutcome(picks, maxAccepted: remainingSlots);
  }

  /// Ambil satu video (maksimal 1 per pemeriksaan).
  Future<MediaPickOutcome> pickVideo({required MediaSource source}) async {
    final picked = await _picker.pickVideo(
      source: source == MediaSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxDuration: _maxVideoDuration,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return const MediaPickOutcome();
    return _toOutcome([picked], isPhoto: false, maxAccepted: _maxVideos);
  }

  Future<MediaPickOutcome> _toOutcome(
    List<XFile> files, {
    bool isPhoto = true,
    required int maxAccepted,
  }) async {
    final accepted = <PendingDocumentationFile>[];
    final rejected = <String>[];

    for (final file in files) {
      if (accepted.length >= maxAccepted) {
        rejected.add(
          isPhoto
              ? 'melebihi sisa slot ${maxAccepted > 0 ? maxAccepted : 0}'
              : 'hanya 1 video per pemeriksaan',
        );
        break;
      }

      final name = file.name.isEmpty ? 'dokumentasi' : file.name;
      final ext = _extensionOf(name);
      if (!isPhoto && !_videoExt.contains(ext)) {
        rejected.add('$name (format .$ext tidak didukung)');
        continue;
      }

      final bytes = await file.readAsBytes();
      final size = bytes.length;
      final path = file.path;

      final maxBytes = isPhoto ? _photoLimit : _videoLimit;
      if (size > maxBytes) {
        rejected.add('$name (melebihi ${maxBytes ~/ (1024 * 1024)} MB)');
        continue;
      }
      if (size == 0) {
        rejected.add('$name (berkas kosong)');
        continue;
      }

      accepted.add(
        PendingDocumentationFile(
          id: '${DateTime.now().microsecondsSinceEpoch}_${accepted.length}',
          kind: isPhoto ? DocumentationKind.photo : DocumentationKind.video,
          localPath: kIsWeb ? '' : path,
          fileName: name,
          bytes: bytes,
          size: size,
        ),
      );
    }

    return MediaPickOutcome(
      files: accepted,
      message: rejected.isEmpty
          ? null
          : 'Berkas dilewati: ${rejected.join(', ')}.',
    );
  }

  static const List<String> _videoExt = ['mp4', 'mov', 'webm'];
  static const int _photoLimit = Lapak8StorageConfig.maxPhotoBytes;
  static const int _videoLimit = 100 * 1024 * 1024;
  static const int _maxVideos = 1;

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }
}
