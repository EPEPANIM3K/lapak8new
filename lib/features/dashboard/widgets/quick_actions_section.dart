import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/ms_icon.dart';

class QuickActionItem {
  const QuickActionItem({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.strongShadow = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  /// true → shadow-md, false → shadow-sm
  final bool strongShadow;
  final VoidCallback? onTap;
}

/// Bagian "Aksi Cepat" (4 tombol bulat).
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key, required this.items});

  final List<QuickActionItem> items;

  /// Empat aksi sesuai desain.
  static List<QuickActionItem> defaults({
    VoidCallback? onQuickBorrow,
    VoidCallback? onSchedule,
    VoidCallback? onRules,
    VoidCallback? onHelp,
  }) =>
      [
        QuickActionItem(
          label: 'Pinjam Cepat',
          icon: Symbols.add_box,
          background: AppColors.primaryContainer,
          foreground: AppColors.onPrimary,
          strongShadow: true,
          onTap: onQuickBorrow,
        ),
        QuickActionItem(
          label: 'Jadwal Aula',
          icon: Symbols.calendar_month,
          background: AppColors.secondaryContainer,
          foreground: AppColors.onSecondaryContainer,
          onTap: onSchedule,
        ),
        QuickActionItem(
          label: 'Peraturan',
          icon: Symbols.gavel,
          background: AppColors.surfaceContainerHigh,
          foreground: AppColors.onSurface,
          onTap: onRules,
        ),
        QuickActionItem(
          label: 'Bantuan PIC',
          icon: Symbols.contact_support,
          background: AppColors.tertiaryFixed,
          foreground: AppColors.onTertiaryFixed,
          onTap: onHelp,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mobileGutter,
        AppSpacing.md,
        AppSpacing.mobileGutter,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Aksi Cepat',
                  style: AppTextStyles.headlineSm(color: AppColors.onSurface)),
              Text('Shortcut Edukasi',
                  style: AppTextStyles.labelSm(
                      color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(child: _QuickAction(item: items[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.item});

  final QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.background,
                  shape: BoxShape.circle,
                  boxShadow:
                      item.strongShadow ? AppShadows.md : AppShadows.sm,
                ),
                child: MsIcon(item.icon, size: 22, color: item.foreground),
              ),
              const SizedBox(height: 6), // gap-1.5
              Text(
                item.label,
                textAlign: TextAlign.center,
                // font-medium + leading-tight (1.25)
                style: AppTextStyles.labelSm(
                        weight: FontWeight.w500, color: AppColors.onSurface)
                    .copyWith(height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
