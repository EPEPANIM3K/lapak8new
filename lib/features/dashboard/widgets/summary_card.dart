import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/ms_icon.dart';

/// Kartu ringkasan kecil (angka + judul + keterangan) dengan lingkaran dekoratif
/// di pojok kanan bawah.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.valueColor,
    required this.subtitleColor,
    required this.decorationColor,
    this.subtitleWeight = FontWeight.w500,
    this.iconFilled = false,
  });

  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool iconFilled;
  final Color iconBackground;
  final Color iconColor;
  final Color valueColor;
  final Color subtitleColor;
  final Color decorationColor;
  final FontWeight subtitleWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // -right-4 -bottom-4 w-16 h-16 rounded-full
          Positioned(
            right: -16,
            bottom: -16,
            child: Container(
              width: 64,
              height: 64,
              decoration:
                  BoxDecoration(color: decorationColor, shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: iconBackground, shape: BoxShape.circle),
                      child: MsIcon(icon,
                          size: 18,
                          color: iconColor,
                          fill: iconFilled ? 1 : 0),
                    ),
                    Text(value,
                        style: AppTextStyles.headlineLg(color: valueColor)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: AppTextStyles.labelMd(
                      weight: FontWeight.w600, color: AppColors.onSurface),
                ),
                // <span> inline di dalam baris 22px (line-height body-md)
                Text(
                  subtitle,
                  style: AppTextStyles.bodySm(
                          weight: subtitleWeight, color: subtitleColor)
                      .copyWith(height: 22 / 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
