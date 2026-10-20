import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/animated_indicators.dart';
import '../../../shared/widgets/ms_icon.dart';

/// Sapaan "Halo, {nama} 👋" + chip peran + NIS + lencana verifikasi.
class GreetingSection extends StatelessWidget {
  const GreetingSection({
    super.key,
    required this.name,
    required this.roleLabel,
    required this.nis,
  });

  final String name;
  final String roleLabel; // contoh: "Siswa • XII RPL 1"
  final String nis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mobileGutter,
        AppSpacing.md,
        AppSpacing.mobileGutter,
        AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Halo, $name',
                        style:
                            AppTextStyles.headlineMd(color: AppColors.onSurface),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    // animate-bounce: tinggi elemen 22px → naik 25% = 5.5px
                    BounceEffect(
                      travel: 5.5,
                      child: Text(
                        '👋',
                        style: const TextStyle(fontSize: 20, height: 1.1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2), // mt-0.5
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MsIcon(Symbols.school,
                              size: 14, color: AppColors.onSecondaryContainer),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            roleLabel,
                            style: AppTextStyles.labelSm(
                                weight: FontWeight.w600,
                                color: AppColors.onSecondaryContainer),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'NIS: $nis',
                        style: AppTextStyles.bodySm(
                            color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              boxShadow: AppShadows.sm,
            ),
            child: const MsIcon(Symbols.verified_user,
                size: 21.6, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
