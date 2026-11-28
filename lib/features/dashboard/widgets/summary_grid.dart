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
    required this.isLoading,
  });

  final int? activeCount;
  final int? pendingCount;
  final bool isLoading;

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
              value: isLoading ? '…' : activeCount?.toString() ?? '—',
              title: 'Pinjaman Aktif',
              subtitle: 'Status pinjaman aktif',
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
              value: isLoading ? '…' : pendingCount?.toString() ?? '—',
              title: 'Menunggu Review',
              subtitle: 'Belum disetujui',
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
