import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';
import '../../features/notifications/controllers/notification_badge_controller.dart';
import '../../features/notifications/utils/badge_count.dart';
import 'ms_icon.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
    this.route = '/',
  });

  final IconData icon;
  final String label;
  final int badgeCount;
  final String route;
}

/// Navigasi bawah melayang: putih 90%, radius 48, tinggi 72.
/// Blur 40 dipakai native; web memakai latar transparan tanpa backdrop filter.
/// Dapat dipasang di `Positioned(bottom: 0, ...)` atau `Scaffold.bottomNavigationBar`.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.useRouter = true,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Jika `true` (default), tap item akan memanggil `context.go(route)`.
  /// Set `false` untuk shell yang mengelola halaman sendiri lewat IndexedStack.
  final bool useRouter;

  /// Menu untuk siswa/guru (sesuai desain).
  static const userItems = [
    AppBottomNavItem(icon: Symbols.home, label: 'Beranda', route: '/'),
    AppBottomNavItem(
      icon: Symbols.category,
      label: 'Item',
      route: '/facilities',
    ),
    AppBottomNavItem(
      icon: Symbols.event_available,
      label: 'Pinjaman',
      route: '/borrowings',
    ),
    AppBottomNavItem(
      icon: Symbols.history,
      label: 'Riwayat',
      route: '/history',
    ),
  ];

  /// Menu untuk pengelola sarpras (admin).
  static const dashboardItems = [
    AppBottomNavItem(
      icon: Symbols.home,
      label: 'Beranda',
      route: '/admin/dashboard',
    ),
    AppBottomNavItem(
      icon: Symbols.swap_horiz,
      label: 'Aktivitas',
      route: '/admin/borrowings',
    ),
    AppBottomNavItem(
      icon: Symbols.history,
      label: 'Riwayat',
      route: '/admin/history',
    ),
    AppBottomNavItem(
      icon: Symbols.category,
      label: 'Item',
      route: '/admin/items',
    ),
    AppBottomNavItem(
      icon: Symbols.tune,
      label: 'Kelola',
      route: '/admin/manage',
    ),
  ];

  /// Tinggi total area nav (pt 4 + bar 72 + pb 12), belum termasuk safe area bawah.
  static const double totalHeight = 4 + AppSpacing.bottomNavHeight + 12;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navContent = Container(
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
                useRouter: useRouter,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
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
          child: kIsWeb
              ? navContent
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: navContent,
                ),
        ),
      ),
    );
  }
}

/// Navigasi bawah pengguna dengan badge jumlah notifikasi belum dibaca.
class UserBottomNav extends StatelessWidget {
  const UserBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.useRouter = true,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool useRouter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notificationBadgeController,
      builder: (context, _) {
        final items = List<AppBottomNavItem>.from(AppBottomNav.userItems);
        final index = items.indexWhere((item) => item.route == '/borrowings');
        if (index != -1) {
          final pinjaman = items[index];
          items[index] = AppBottomNavItem(
            icon: pinjaman.icon,
            label: pinjaman.label,
            badgeCount: notificationBadgeController.unreadCount,
            route: pinjaman.route,
          );
        }

        return AppBottomNav(
          items: items,
          currentIndex: currentIndex,
          onTap: onTap,
          useRouter: useRouter,
        );
      },
    );
  }
}

/// Navigasi bawah admin dengan badge notifikasi pada menu Aktivitas.
class AdminBottomNav extends StatelessWidget {
  const AdminBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.useRouter = true,
    this.aktivitasBadgeCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool useRouter;
  final int aktivitasBadgeCount;

  @override
  Widget build(BuildContext context) {
    final items = List<AppBottomNavItem>.from(AppBottomNav.dashboardItems);
    final aktivitas = items[1];
    items[1] = AppBottomNavItem(
      icon: aktivitas.icon,
      label: aktivitas.label,
      badgeCount: aktivitasBadgeCount,
      route: aktivitas.route,
    );

    return AppBottomNav(
      items: items,
      currentIndex: currentIndex,
      onTap: onTap,
      useRouter: useRouter,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.useRouter,
  });

  final AppBottomNavItem item;
  final bool selected;
  final bool useRouter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 60), // min-w-[3.75rem]
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          if (useRouter) context.go(item.route);
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
                  Text(
                    item.label,
                    style: AppTextStyles.labelSm(
                      weight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (item.badgeCount > 0)
                Positioned(
                  top: 4,
                  right: 10,
                  child: Container(
                    key: Key('notification-badge-${item.route}'),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.surfaceContainerLowest,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      formatBadgeCount(item.badgeCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
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
