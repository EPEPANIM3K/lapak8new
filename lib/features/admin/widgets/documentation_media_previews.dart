import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lapak8new/core/storage/storage_config.dart';

/// Gambar dari berkas lokal (mobile/desktop) atau memori (web).
class LocalImagePreview extends StatelessWidget {
  const LocalImagePreview({
    super.key,
    required this.path,
    this.bytes,
    this.fit = BoxFit.cover,
  });

  final String path;
  final List<int>? bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (data != null) {
      final typed =
          data is Uint8List ? data : Uint8List.fromList(data);
      return Image.memory(typed, fit: fit, gaplessPlayback: true);
    }
    if (path.isEmpty) return const _BrokenImage();
    if (kIsWeb) return const _BrokenImage();
    return Image.file(
      File(path),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const _BrokenImage(),
    );
  }
}

/// Gambar dari server penyimpanan (butuh header otorisasi).
class RemoteMediaImage extends StatelessWidget {
  const RemoteMediaImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.token,
    this.onTap,
  });

  final String url;
  final BoxFit fit;

  /// Token opsional; default memakai konfigurasi penyimpanan.
  final String? token;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final headers = token == null
        ? Lapak8StorageConfig.mediaHeaders
        : {'authorization': 'Bearer $token'};
    final image = Image.network(
      Lapak8StorageConfig.absoluteUrl(url),
      fit: fit,
      headers: headers,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => const _BrokenImage(),
    );
    if (onTap == null) return image;
    return GestureDetector(onTap: onTap, child: image);
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE2E7FF),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: Color(0xFF747686),
        ),
      ),
    );
  }
}