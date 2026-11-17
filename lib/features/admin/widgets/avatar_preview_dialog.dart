import 'package:flutter/material.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';
import 'package:lapak8new/features/admin/widgets/documentation_media_previews.dart';

/// Dialog preview foto profil sebelum dipakai (dipakai admin & user).
///
/// Menampilkan foto hasil pilihan dalam bentuk lingkaran beserta tombol
/// [Batal] dan [Gunakan Foto]. Frontend only — belum menyimpan permanen.
class AvatarPreviewDialog extends StatelessWidget {
  const AvatarPreviewDialog({super.key, required this.file});

  final PendingDocumentationFile file;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Preview Foto Profil',
              style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Pastikan wajah terlihat jelas.',
              style: AppTextStyles.bodySm(color: AppColors.slate600),
            ),
            const SizedBox(height: 20),
            Container(
              width: 160,
              height: 160,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryFixed,
                border: Border.all(
                    color: AppColors.surfaceContainerLow, width: 4),
              ),
              child: LocalImagePreview(
                  path: file.localPath, bytes: file.bytes),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLow,
                        foregroundColor: AppColors.slate600,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Batal',
                        style: AppTextStyles.labelLg(
                          weight: FontWeight.w700,
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Gunakan Foto',
                        style: AppTextStyles.labelLg(
                          weight: FontWeight.w700,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
