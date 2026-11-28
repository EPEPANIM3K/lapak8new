import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final typed = data is Uint8List ? data : Uint8List.fromList(data);
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

/// Gambar privat dari Supabase Storage menggunakan signed URL sementara.
class RemoteMediaImage extends StatefulWidget {
  const RemoteMediaImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  final String url;
  final BoxFit fit;
  final VoidCallback? onTap;

  @override
  State<RemoteMediaImage> createState() => _RemoteMediaImageState();
}

class _RemoteMediaImageState extends State<RemoteMediaImage> {
  late Future<String> _signedUrl;

  @override
  void initState() {
    super.initState();
    _signedUrl = _createSignedUrl();
  }

  @override
  void didUpdateWidget(covariant RemoteMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _signedUrl = _createSignedUrl();
    }
  }

  Future<String> _createSignedUrl() => Supabase.instance.client.storage
      .from(Lapak8StorageConfig.bucket)
      .createSignedUrl(widget.url, 60 * 60);

  @override
  Widget build(BuildContext context) {
    final image = FutureBuilder<String>(
      future: _signedUrl,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _BrokenImage();
        final signedUrl = snapshot.data;
        if (signedUrl == null) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Image.network(
          signedUrl,
          fit: widget.fit,
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
      },
    );
    if (widget.onTap == null) return image;
    return GestureDetector(onTap: widget.onTap, child: image);
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
