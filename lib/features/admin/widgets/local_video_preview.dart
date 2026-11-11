import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:lapak8new/features/admin/services/local_media_url.dart';

/// Pemutar video dokumentasi dari berkas lokal (path) atau memori (web).
///
/// - Mobile/desktop : memakai `VideoPlayerController.file`.
/// - Web            : memakai blob URL dari [createLocalMediaUrl] lalu
///                    `VideoPlayerController.network`, dan URL dicabut saat
///                    widget dilepas agar tidak terjadi memory leak.
class LocalVideoPreview extends StatefulWidget {
  const LocalVideoPreview({
    super.key,
    required this.path,
    this.bytes,
    this.onRevokeUrl,
  });

  /// Path berkas lokal (kosong pada web).
  final String path;

  /// Isi berkas bila tersedia (web / hasil readAsBytes).
  final List<int>? bytes;

  /// Dipanggil saat widget dilepas agar pemilik URL bisa mencabut blob URL.
  final void Function(String url)? onRevokeUrl;

  @override
  State<LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<LocalVideoPreview> {
  VideoPlayerController? _controller;
  String? _blobUrl;
  bool _initialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    VideoPlayerController controller;
    final bytes = widget.bytes;
    if (kIsWeb) {
      final url = createLocalMediaUrl(bytes ?? const <int>[]);
      if (url == null) {
        setState(() => _failed = true);
        return;
      }
      _blobUrl = url;
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    } else if (!kIsWeb && widget.path.isNotEmpty) {
      controller = VideoPlayerController.file(File(widget.path));
    } else {
      setState(() => _failed = true);
      return;
    }

    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initialized = true;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_blobUrl != null) widget.onRevokeUrl?.call(_blobUrl!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const ColoredBox(
        color: Color(0xFFE2E7FF),
        child: Center(
          child: Icon(
            Icons.videocam_off_outlined,
            size: 28,
            color: Color(0xFF747686),
          ),
        ),
      );
    }
    if (!_initialized) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    final controller = _controller!;
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
            });
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: controller.value.isPlaying ? 0.0 : 1.0,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xCC131B2E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: VideoControls(controller: controller),
        ),
      ],
    );
  }
}

/// Baris kontrol sederhana: tombol play/pause, slider seek, posisi & durasi.
class VideoControls extends StatelessWidget {
  const VideoControls({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final position = controller.value.position;
        final duration = controller.value.duration;
        final max = duration.inMilliseconds.toDouble();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xB3131B2E),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                },
                child: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: max == 0
                        ? 0
                        : position.inMilliseconds.toDouble().clamp(0, max),
                    max: max == 0 ? 1 : max,
                    onChanged: (v) {
                      controller.seekTo(Duration(milliseconds: v.round()));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_fmt(position)} / ${_fmt(duration)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

