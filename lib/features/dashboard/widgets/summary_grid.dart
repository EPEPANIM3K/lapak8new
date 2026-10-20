import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import 'summary_card.dart';

/// Grid 2 kolom: "Pinjaman Aktif" dan "Menunggu Review".
class SummaryGrid extends StatelessWidget {
  const SummaryGrid({
    super.key,
    required this.activeCount,
    required this.pendingCount,
  });

  final int activeCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.mobileGutter,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SummaryCard(
              value: '$activeCount',
              title: 'Pinjaman Aktif',
              subtitle: 'Disetujui hari ini',
              icon: Symbols.task_alt,
              iconFilled: true,
              iconBackground: AppColors.tertiaryFixed,
              iconColor: AppColors.onTertiaryFixed,
              valueColor: AppColors.tertiary,
              subtitleColor: AppColors.tertiary,
              decorationColor: AppColors.tertiaryFixed.fade(0.3),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SummaryCard(
              value: '$pendingCount',
              title: 'Menunggu Review',
              subtitle: 'Verifikasi Sarpras',
              icon: Symbols.pending_actions,
              iconBackground: AppColors.secondaryContainer,
              iconColor: AppColors.onSecondaryContainer,
              valueColor: AppColors.secondary,
              subtitleColor: AppColors.onSurfaceVariant,
              decorationColor: AppColors.secondaryFixed.fade(0.4),
            ),
          ),
        ],
      ),
    );
  }
}
