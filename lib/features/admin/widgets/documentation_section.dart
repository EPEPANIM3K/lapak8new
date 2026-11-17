import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';
import 'package:lapak8new/features/admin/services/media_picker_service.dart';
import 'package:lapak8new/features/admin/widgets/documentation_media_previews.dart';
import 'package:lapak8new/features/admin/widgets/local_video_preview.dart';
import 'package:lapak8new/features/admin/widgets/media_source_sheet.dart';
import 'package:lapak8new/shared/widgets/ms_icon.dart';

/// Batas dokumentasi per pemeriksaan.
const int kMaxDocPhotos = 6;
const int kMaxDocVideos = 1;

/// Section "Dokumentasi Kondisi Barang" pada form Cek Kondisi.
///
/// Mengelola pemilihan & preview foto (maks [kMaxDocPhotos]) dan video
/// (maks [kMaxDocVideos]) secara lokal di frontend. Belum ada integrasi
/// backend — berkas hanya disimpan pada state sementara.
class DocumentationSection extends StatefulWidget {
  const DocumentationSection({
    super.key,
    required this.picker,
    required this.onChanged,
  });

  final MediaPickerService picker;

  /// Dipanggil setiap kali daftar foto / video berubah.
  final void Function(
          List<PendingDocumentationFile> photos, PendingDocumentationFile? video)
      onChanged;

  @override
  State<DocumentationSection> createState() => _DocumentationSectionState();
}

class _DocumentationSectionState extends State<DocumentationSection> {
  final List<PendingDocumentationFile> _photos = [];
  PendingDocumentationFile? _video;

  String? _message;
  bool _messageIsError = false;
  bool _busy = false;

  @override
  void dispose() {
    // Tidak ada object URL yang dipelihara di sini: preview foto memakai
    // bytes/file, dan blob URL video dibuat + dicabut oleh LocalVideoPreview.
    super.dispose();
  }

  void _notify() => widget.onChanged(List.of(_photos), _video);

  void _showMessage(String message, {bool isError = true}) {
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  void _clearMessage() {
    if (_message == null) return;
    setState(() => _message = null);
  }

  // -------------------------------------------------------------------------
  // Aksi: foto
  // -------------------------------------------------------------------------
  Future<void> _addPhotos() async {
    if (_busy) return;
    final remaining = kMaxDocPhotos - _photos.length;
    if (remaining <= 0) {
      _showMessage('Foto sudah mencapai batas maksimal $kMaxDocPhotos.');
      return;
    }
    _clearMessage();
    final source = await showMediaSourceSheet(
      context,
      isPhoto: true,
      title: 'Tambah Foto',
      subtitle: 'Pilih sumber foto kondisi barang.',
    );
    if (source == null || !mounted) return;

    setState(() => _busy = true);
    final outcome = await widget.picker
        .pickPhotos(source: source, remainingSlots: remaining);
    if (!mounted) return;
    setState(() => _busy = false);

    if (outcome.files.isNotEmpty) {
      setState(() => _photos.addAll(outcome.files));
      _notify();
    }
    if (outcome.message != null) {
      _showMessage(outcome.message!);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _message = null;
    });
    _notify();
  }

  // -------------------------------------------------------------------------
  // Aksi: video
  // -------------------------------------------------------------------------
  Future<void> _addVideo() async {
    if (_busy) return;
    if (_video != null) {
      _showMessage(
          'Hanya satu video per pemeriksaan. Hapus dulu untuk mengganti.');
      return;
    }
    _clearMessage();
    final source = await showMediaSourceSheet(
      context,
      isPhoto: false,
      title: 'Tambah Video',
      subtitle: 'Pilih sumber video kondisi barang.',
    );
    if (source == null || !mounted) return;

    setState(() => _busy = true);
    final outcome = await widget.picker.pickVideo(source: source);
    if (!mounted) return;
    setState(() => _busy = false);

    if (outcome.files.isNotEmpty) {
      setState(() => _video = outcome.files.first);
      _notify();
    }
    if (outcome.message != null) {
      _showMessage(outcome.message!);
    }
  }

  void _removeVideo() {
    setState(() {
      _video = null;
      _message = null;
    });
    _notify();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildPhotoArea(),
          const SizedBox(height: 16),
          _buildVideoArea(),
          const SizedBox(height: 12),
          _buildNote(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _message == null
                ? const SizedBox.shrink(key: ValueKey('no-msg'))
                : Padding(
                    key: const ValueKey('msg'),
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildMessageBanner(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.primaryFixed,
            shape: BoxShape.circle,
          ),
          child: const MsIcon(Symbols.photo_camera,
              size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dokumentasi Kondisi Barang',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Lampirkan foto (maks. 6) dan video (maks. 1) sebagai '
                'bukti kondisi barang saat dikembalikan.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MsIcon(Symbols.info, size: 14, color: AppColors.slate500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Dokumentasi digunakan sebagai bukti kondisi barang saat '
            'dikembalikan dan bersifat opsional.',
            style: AppTextStyles.bodySm(
              weight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBanner() {
    final color = _messageIsError ? AppColors.error : AppColors.primary;
    final bg =
        _messageIsError ? AppColors.errorContainer : AppColors.primaryFixed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MsIcon(Symbols.info, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _message!,
              style: AppTextStyles.bodySm(
                weight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Area foto
  // -------------------------------------------------------------------------
  Widget _buildPhotoArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Foto',
              style: AppTextStyles.labelMd(
                weight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${_photos.length}/$kMaxDocPhotos',
              style: AppTextStyles.labelSm(
                weight: FontWeight.w700,
                color: _photos.length >= kMaxDocPhotos
                    ? AppColors.error
                    : AppColors.slate600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final width = constraints.maxWidth;
            final columns = width >= 560 ? 5 : (width >= 420 ? 4 : 3);
            final tile =
                ((width - gap * (columns - 1)) / columns).clamp(0.0, 96.0);
            final children = <Widget>[
              for (var i = 0; i < _photos.length; i++)
                _PhotoTile(
                  file: _photos[i],
                  size: tile,
                  onRemove: () => _removePhoto(i),
                ),
              if (_photos.length < kMaxDocPhotos)
                _AddTile(
                  size: tile,
                  busy: _busy,
                  onTap: _addPhotos,
                ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: children,
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Area video
  // -------------------------------------------------------------------------
  Widget _buildVideoArea() {
    final video = _video;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Video',
          style: AppTextStyles.labelMd(
            weight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: video == null
              ? _EmptyVideoTile(
                  key: const ValueKey('empty-video'),
                  busy: _busy,
                  onTap: _addVideo,
                )
              : _VideoTile(
                  key: ValueKey(video.id),
                  file: video,
                  onReplace: _addVideo,
                  onRemove: _removeVideo,
                ),
        ),
      ],
    );
  }

}

// ---------------------------------------------------------------------------
// Tile foto dengan preview + tombol hapus
// ---------------------------------------------------------------------------
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.file,
    required this.size,
    required this.onRemove,
  });

  final PendingDocumentationFile file;
  final double size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LocalImagePreview(path: file.localPath, bytes: file.bytes),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xCC131B2E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile tambah foto (tombol +)
// ---------------------------------------------------------------------------
class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.size,
    required this.busy,
    required this.onTap,
  });

  final double size;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primaryFixed.fade(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.fade(0.35),
            width: 1.4,
          ),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MsIcon(Symbols.add,
                      size: 24, color: AppColors.primary),
                  const SizedBox(height: 2),
                  Text(
                    'Tambah',
                    style: AppTextStyles.labelSm(
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Area video kosong (upload)
// ---------------------------------------------------------------------------
class _EmptyVideoTile extends StatelessWidget {
  const _EmptyVideoTile({
    super.key,
    required this.busy,
    required this.onTap,
  });

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primaryFixed.fade(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.fade(0.35),
            width: 1.4,
          ),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            : Column(
                children: [
                  const MsIcon(Symbols.videocam,
                      size: 30, color: AppColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    'Tambah Video',
                    style: AppTextStyles.labelMd(
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MP4, MOV, atau WEBM • maks. 1 video',
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w500,
                      color: AppColors.slate600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Preview video + tombol ganti & hapus
// ---------------------------------------------------------------------------
class _VideoTile extends StatelessWidget {
  const _VideoTile({
    super.key,
    required this.file,
    required this.onReplace,
    required this.onRemove,
  });

  final PendingDocumentationFile file;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.fade(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: const Color(0xFF131B2E),
            child: LocalVideoPreview(path: file.localPath, bytes: file.bytes),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                const MsIcon(Symbols.videocam,
                    size: 16, color: AppColors.slate600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _VideoAction(
                  label: 'Ganti',
                  icon: Symbols.refresh,
                  foreground: AppColors.primary,
                  background: AppColors.primaryFixed,
                  onTap: onReplace,
                ),
                const SizedBox(width: 8),
                _VideoAction(
                  label: 'Hapus',
                  icon: Symbols.delete,
                  foreground: AppColors.error,
                  background: AppColors.errorContainer,
                  onTap: onRemove,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoAction extends StatelessWidget {
  const _VideoAction({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MsIcon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSm(
                weight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

