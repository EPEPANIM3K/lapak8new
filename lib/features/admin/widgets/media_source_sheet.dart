import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/services/media_picker_service.dart';
import 'package:lapak8new/shared/widgets/ms_icon.dart';

/// Bottom sheet pemilihan sumber berkas dokumentasi (kamera atau galeri).
Future<MediaSource?> showMediaSourceSheet(
  BuildContext context, {
  required bool isPhoto,
  String? title,
  String? subtitle,
}) {
  return showModalBottomSheet<MediaSource>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => _MediaSourceSheet(
      isPhoto: isPhoto,
      title: title,
      subtitle: subtitle,
    ),
  );
}

class _MediaSourceSheet extends StatelessWidget {
  const _MediaSourceSheet({
    required this.isPhoto,
    this.title,
    this.subtitle,
  });

  final bool isPhoto;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final media = isPhoto ? 'foto' : 'video';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? 'Tambah $media',
              style: AppTextStyles.headlineSm(color: AppColors.onSurface),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: AppTextStyles.bodySm(
                  weight: FontWeight.w500,
                  color: AppColors.slate600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SourceTile(
              icon: isPhoto ? Symbols.photo_camera : Symbols.videocam,
              title: isPhoto ? 'Ambil Foto' : 'Rekam Video',
              subtitle: isPhoto
                  ? 'Gunakan kamera perangkat untuk memotret kondisi barang.'
                  : 'Rekam video langsung dari kamera (maks. 2 menit).',
              onTap: () => Navigator.of(context).pop(MediaSource.camera),
            ),
            const SizedBox(height: 10),
            _SourceTile(
              icon: isPhoto ? Symbols.photo_library : Symbols.video_library,
              title: isPhoto ? 'Pilih dari Galeri' : 'Pilih dari Penyimpanan',
              subtitle: isPhoto
                  ? 'Ambil foto yang sudah tersimpan di galeri.'
                  : 'Pilih berkas video yang sudah ada di penyimpanan.',
              onTap: () => Navigator.of(context).pop(MediaSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.base),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: MsIcon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.labelLg(
                        weight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySm(
                        weight: FontWeight.w500,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              const MsIcon(Symbols.chevron_right,
                  size: 20, color: AppColors.slate500),
            ],
          ),
        ),
      ),
    );
  }
}