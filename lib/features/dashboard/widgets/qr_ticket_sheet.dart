import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';

/// Kode QR contoh (mock) dari HTML. Ganti dengan paket `qr_flutter`
/// saat data tiket sungguhan sudah tersedia dari backend.
const _mockQrSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><path fill="#131B2E" d="M0,0 h30 v30 h-30 z M5,5 v20 h20 v-20 z M10,10 h10 v10 h-10 z M70,0 h30 v30 h-30 z M75,5 v20 h20 v-20 z M80,10 h10 v10 h-10 z M0,70 h30 v30 h-30 z M5,75 v20 h20 v-20 z M10,80 h10 v10 h-10 z M40,10 h10 v10 h-10 z M55,10 h10 v10 h-10 z M40,30 h10 v10 h-10 z M60,40 h15 v15 h-15 z M40,60 h10 v20 h-10 z M60,70 h20 v10 h-20 z M80,60 h10 v20 h-10 z M40,90 h30 v10 h-30 z"/></svg>
''';

/// Modal tiket QR dari bawah (overlay on-surface 40% + blur 4, durasi 300ms).
/// Pakai: `QrTicketSheet.show(context, title: ..., code: ...)`.
class QrTicketSheet extends StatelessWidget {
  const QrTicketSheet({super.key, required this.title, required this.code});

  final String title;
  final String code;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String code,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false, // tap di luar ditangani overlay sendiri
      barrierLabel: 'Tutup tiket',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => QrTicketSheet(title: title, code: code),
      transitionBuilder: (ctx, animation, _, child) {
        // cubic-bezier(.4,0,.2,1) = Curves.fastOutSlowIn
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
          reverseCurve: Curves.fastOutSlowIn,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: AnimatedBuilder(
                  animation: curved,
                  builder: (_, __) => BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: 4 * curved.value, sigmaY: 4 * curved.value),
                    child: ColoredBox(
                      color: AppColors.onSurface.fade(0.4 * curved.value),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448), // max-w-md
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + bottomInset,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            boxShadow: AppShadows.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // handle
              Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text('Tiket Akses Valid',
                    style: AppTextStyles.labelSm(
                        weight: FontWeight.w700,
                        color: AppColors.onTertiaryFixed)),
              ),
              const SizedBox(height: AppSpacing.xxs), // mt-1
              Text(title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMd(color: AppColors.onSurface)),
              Text(
                'Tunjukkan kode QR ini kepada PIC Lab saat memasuki ruangan',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.string(_mockQrSvg, width: 176, height: 176),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      code,
                      // font-mono font-bold, label-md
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New'],
                        fontSize: 12,
                        height: 16 / 12,
                        letterSpacing: 0.24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: Center(
                      child: Text('Tutup Tiket',
                          style: AppTextStyles.labelLg(
                              weight: FontWeight.w600,
                              color: AppColors.onSurface)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
