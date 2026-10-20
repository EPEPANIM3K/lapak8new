import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';
import 'ms_icon.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.label,
    this.showBadge = false,
    this.route = '/',
  });

  final IconData icon;
  final String label;
  final bool showBadge;
  final String route;
}

/// Navigasi bawah melayang: putih 90% + blur 40, radius 48, tinggi 72.
/// Letakkan di `Positioned(bottom: 0, ...)` di dalam Stack.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Menu untuk siswa/guru (sesuai desain).
  static const userItems = [
    AppBottomNavItem(icon: Symbols.home, label: 'Beranda', route: '/'),
    AppBottomNavItem(icon: Symbols.category, label: 'Item', route: '/facilities'),
    AppBottomNavItem(
        icon: Symbols.event_available, label: 'Pinjaman', showBadge: true, route: '/borrowings'),
    AppBottomNavItem(icon: Symbols.history, label: 'Riwayat', route: '/history'),
  ];

  /// Tinggi total area nav (pt 4 + bar 72 + pb 12), belum termasuk safe area bawah.
  static const double totalHeight = 4 + AppSpacing.bottomNavHeight + 12;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.mobileGutter,
        AppSpacing.xxs,
        AppSpacing.mobileGutter,
        AppSpacing.sm + bottomInset,
      ),
      child: Container(
        height: AppSpacing.bottomNavHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.fade(0.08),
              offset: const Offset(0, 8),
              blurRadius: 32,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: AppColors.surfaceContainerLowest.fade(0.9),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Material(
                type: MaterialType.transparency,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _NavItem(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () => onTap(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 60), // min-w-[3.75rem]
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          context.go(item.route);
          onTap();
        },
        child: SizedBox(
          height: AppSpacing.touchTargetMin,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MsIcon(item.icon, size: 24, color: color),
                  const SizedBox(height: 2),
                  Text(item.label,
                      style: AppTextStyles.labelSm(
                          weight: FontWeight.w700, color: color)),
                ],
              ),
              if (item.showBadge)
                Positioned(
                  top: 4,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      // ring-2 ring-surface-container-lowest
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.surfaceContainerLowest,
                            spreadRadius: 2),
                      ],
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
