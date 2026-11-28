import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'blurred_bottom_sheet.dart';

/// Bottom sheet konfirmasi logout yang dipakai bersama oleh area User & Admin.
///
/// Tampilannya sengaja identik untuk kedua role. Mekanisme logout tetap
/// dijalankan oleh pemanggil lewat [onConfirm] agar sesi masing-masing role
/// tidak tercampur.
Future<void> showLogoutConfirmationSheet({
  required BuildContext context,
  required Future<void> Function() onConfirm,
}) {
  return showBlurredBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceContainerLowest,
    builder: (modalContext) {
      return _LogoutConfirmationSheet(
        onConfirm: () async {
          Navigator.of(modalContext, rootNavigator: true).pop();
          await onConfirm();
        },
      );
    },
  );
}

class _LogoutConfirmationSheet extends StatelessWidget {
  const _LogoutConfirmationSheet({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            // Icon Warning
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            // Text
            const Text(
              'Yakin Ingin Keluar?',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Anda harus memasukkan kembali NISN dan kata sandi untuk mengajukan atau memeriksa peminjaman sarana.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(
                  'Ya, Keluar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  foregroundColor: AppColors.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
