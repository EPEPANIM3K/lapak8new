import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';
import '../auth/providers/auth_provider.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: Column(
        children: [
          const _AdminHeader(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authProvider,
      builder: (context, _) {
        final user = authProvider.user;
        final name = user?.namaLengkap.trim() ?? '';
        final initials = name
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();
        final fotoUrl = user?.fotoUrl?.trim() ?? '';

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            boxShadow: AppShadows.sm,
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.mobileGutter,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 20,
                        color: AppColors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LAPAK8',
                            style: AppTextStyles.headlineSm(
                              color: AppColors.primary,
                            ).copyWith(letterSpacing: -0.45),
                          ),
                          Text(
                            'SMK 8 MALANG',
                            style: AppTextStyles.labelSm(
                              weight: FontWeight.w500,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Buka profil admin',
                      child: InkWell(
                        onTap: () => context.push('/admin/profile'),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surfaceContainerLowest,
                              width: 2,
                            ),
                          ),
                          child: fotoUrl.isEmpty
                              ? _buildInitials(initials)
                              : Image.network(
                                  fotoUrl,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildInitials(initials),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitials(String initials) => Text(
    initials.isEmpty ? 'A' : initials,
    style: AppTextStyles.labelMd(
      weight: FontWeight.w800,
      color: AppColors.primary,
    ),
  );
}
