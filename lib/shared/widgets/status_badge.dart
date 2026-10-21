import 'package:flutter/material.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';

enum BorrowStatus { waiting, borrowed, approved }

/// Label status berbentuk pil dengan titik warna: Menunggu / Dipinjam / Disetujui.
class StatusBadge extends StatelessWidget {
  final BorrowStatus status;
  const StatusBadge({super.key, required this.status});

  // Kuning/amber tidak ada di AppColors, jadi didefinisikan lokal.
  // Kalau nanti dipakai di layar lain, pindahkan ke AppColors.
  static const Color _amberBg = Color(0xFFFFE7A8);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberText = Color(0xFF5B3A00);

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color dot;
    late final Color text;

    switch (status) {
      case BorrowStatus.waiting:
        label = 'Menunggu';
        bg = _amberBg;
        dot = _amber;
        text = _amberText;
        break;
      case BorrowStatus.borrowed:
        label = 'Dipinjam';
        bg = AppColors.primaryFixed;
        dot = AppColors.primary;
        text = AppColors.primary;
        break;
      case BorrowStatus.approved:
        label = 'Disetujui';
        bg = AppColors.tertiaryFixed.fade(0.55);
        dot = AppColors.emerald500;
        text = AppColors.onTertiaryFixedVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.labelSm(color: text)),
        ],
      ),
    );
  }
}