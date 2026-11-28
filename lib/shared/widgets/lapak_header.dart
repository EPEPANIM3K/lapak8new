import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';

/// Header tetap di atas (logo LAPAK8 + avatar).
/// Latar: surface 85%; blur 24 dipakai native, web tanpa backdrop filter.
/// Letakkan di `Positioned(top: 0, ...)` di dalam Stack.
class LapakHeader extends StatelessWidget {
  const LapakHeader({super.key, required this.avatarUrl, this.onAvatarTap});

  final String avatarUrl;
  final VoidCallback? onAvatarTap;

  /// Tinggi konten header (h-16), belum termasuk safe area atas.
  static const double contentHeight = 64;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final headerContent = Container(
      color: AppColors.surface.fade(0.85),
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: contentHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.mobileGutter,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Brand(),
              _Avatar(url: avatarUrl, onTap: onAvatarTap),
            ],
          ),
        ),
      ),
    );
    return ClipRect(
      child: kIsWeb
          ? headerContent
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: headerContent,
            ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // w-8 h-8 rounded-lg (2rem) → praktis lingkaran
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.sm,
          ),
          child: const Icon(Icons.school, size: 20, color: AppColors.onPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LAPAK8',
              // tracking-tight = -0.025em
              style: AppTextStyles.headlineSm(
                color: AppColors.primary,
              ).copyWith(letterSpacing: -0.45),
            ),
            Text(
              'SMK NEGERI 8 MALANG',
              style: AppTextStyles.labelSm(
                weight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, this.onTap});

  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: AppSpacing.touchTargetMin,
        height: AppSpacing.touchTargetMin,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              // ring-1 ring-primary-fixed
              boxShadow: [
                BoxShadow(color: AppColors.primaryFixed, spreadRadius: 1),
              ],
            ),
            child: ClipOval(
              child: url.trim().isEmpty
                  ? const ColoredBox(
                      color: AppColors.surfaceContainerHigh,
                      child: Icon(
                        Icons.person,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    )
                  : Image.network(
                      url,
                      width: 32,
                      height: 32,
                      cacheWidth: 64,
                      cacheHeight: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.surfaceContainerHigh,
                        child: Icon(
                          Icons.person,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
