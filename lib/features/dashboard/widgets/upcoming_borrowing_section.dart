import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/animated_indicators.dart';
import '../../../shared/widgets/ms_icon.dart';

/// Bagian "Peminjaman Mendatang" (kartu sorotan + 2 tombol aksi).
class UpcomingBorrowingSection extends StatelessWidget {
  const UpcomingBorrowingSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.scheduleLabel,
    required this.approverName,
    required this.approverRole,
    this.onDetailTap,
    this.onShowQrTap,
    this.onDirectionsTap,
  });

  final String title; // "Lab Komputer 2"
  final String subtitle; // "Praktik Uji Sertifikasi LSP"
  final String statusLabel; // "Disetujui"
  final String scheduleLabel; // "Hari ini • 13:30 - 15:30 WIB"
  final String approverName;
  final String approverRole;
  final VoidCallback? onDetailTap;
  final VoidCallback? onShowQrTap;
  final VoidCallback? onDirectionsTap;

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
              Row(
                children: [
                  const PingDot(
                    pingColor: AppColors.tertiaryFixedDim,
                    dotColor: AppColors.tertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Peminjaman Mendatang',
                      style:
                          AppTextStyles.headlineSm(color: AppColors.onSurface)),
                ],
              ),
              GestureDetector(
                onTap: onDetailTap,
                child: Text('Detail',
                    style: AppTextStyles.labelSm(
                        weight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _Card(
            title: title,
            subtitle: subtitle,
            statusLabel: statusLabel,
            scheduleLabel: scheduleLabel,
            approverName: approverName,
            approverRole: approverRole,
            onShowQrTap: onShowQrTap,
            onDirectionsTap: onDirectionsTap,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.scheduleLabel,
    required this.approverName,
    required this.approverRole,
    this.onShowQrTap,
    this.onDirectionsTap,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final String scheduleLabel;
  final String approverName;
  final String approverRole;
  final VoidCallback? onShowQrTap;
  final VoidCallback? onDirectionsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.md,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hiasan: w-24 h-24, gradient ke kiri-bawah, rounded-bl-full, opacity .6
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.6,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.only(bottomLeft: Radius.circular(96)),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        AppColors.primaryFixed,
                        AppColors.primaryFixed.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopRow(
                  title: title,
                  subtitle: subtitle,
                  statusLabel: statusLabel,
                ),
                const SizedBox(height: AppSpacing.sm),
                _Ribbon(
                  scheduleLabel: scheduleLabel,
                  approverName: approverName,
                  approverRole: approverRole,
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 4), // pt-1
                  child: _PillButton(
                    label: 'Tiket Akses QR',
                    icon: Symbols.qr_code_2,
                    background: AppColors.primary,
                    foreground: AppColors.onPrimary,
                    shadow: AppShadows.sm,
                    onTap: onShowQrTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
  });

  final String title;
  final String subtitle;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              // w-12 h-12 rounded-lg(2rem) → lingkaran
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: const MsIcon(Symbols.computer,
                    size: 28, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.headlineSm(
                            color: AppColors.onSurface)),
                    Text(subtitle,
                        style: AppTextStyles.bodySm(
                            color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: AppColors.tertiaryFixed,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: AppColors.tertiary, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(statusLabel,
                  style: AppTextStyles.labelSm(
                      weight: FontWeight.w600,
                      color: AppColors.onTertiaryFixed)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.scheduleLabel,
    required this.approverName,
    required this.approverRole,
  });

  final String scheduleLabel;
  final String approverName;
  final String approverRole;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.fade(0.7),
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MsIcon(Symbols.schedule, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  scheduleLabel,
                  style: AppTextStyles.labelMd(
                      weight: FontWeight.w600, color: AppColors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6), // gap-1.5
          Row(
            children: [
              const MsIcon(Symbols.verified, size: 18, color: AppColors.tertiary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.bodySm(
                        color: AppColors.onSurfaceVariant),
                    children: [
                      const TextSpan(text: 'Disetujui oleh: '),
                      TextSpan(
                        text: approverName,
                        style: AppTextStyles.bodySm(
                            weight: FontWeight.w500,
                            color: AppColors.onSurface),
                      ),
                      TextSpan(text: ' ($approverRole)'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.shadow,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MsIcon(icon, size: 18, color: foreground),
                const SizedBox(width: 6), // gap-1.5
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMd(
                        weight: FontWeight.w600, color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
