import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/lapak_header.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_borrowings_screen.dart';
import 'screens/admin_history_screen.dart';
import 'screens/manage_facilities_screen.dart';
import 'screens/manage_users_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  // Halaman admin yang sebenarnya, diurutkan sesuai dengan items di bawah.
  late final List<Widget> _pages = [
    AdminDashboardScreen(onReviewTap: _goToBorrowings), // 0
    const AdminBorrowingsScreen(), // 1
    const AdminHistoryScreen(), // 2
    const ManageFacilitiesScreen(), // 3
    const ManageUsersScreen(), // 4
  ];

  // Avatar URL untuk admin (bisa diganti dengan data dari provider nanti)
  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCM9TBr73lAvJae_M-j8bVPXa69t9E8fJjw6s1fOkJB9Rwn5SdnSrc2vwOfl_FwiSc0PAsKLZ3OrWbOxQRw_0Nv8TltDOZ-YW8v68X2WTQJl29s3nRn2_K2GuSWHAvMZpMCZJe6iBeZDp5yEl_7IcjmKNNuCgejx9XkiISbISzKzJKsN4oi8-ZVu-ddev07E4AA7eAz81C-Lou8NTkx4lFKRMgys8zcncLJEU3cjaxS9X4CrRZuET7Y';

  /// Handle tap dengan validasi index aman
  void _onNavTap(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() => _selectedIndex = index);
    }
  }

  /// Dari tombol "Tinjau" di Dashboard → pindah ke halaman Aktivitas
  /// (index 1 = AdminBorrowingsScreen, tab default Peminjaman).
  void _goToBorrowings() {
    _onNavTap(1);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Main content area - constrain ukuran dengan Positioned
          Positioned(
            top: LapakHeader.contentHeight + inset.top,
            left: 0,
            right: 0,
            bottom: AppBottomNav.totalHeight + inset.bottom,
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
          // Header melayang di atas
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LapakHeader(
              avatarUrl: _avatarUrl,
              onAvatarTap: () => context.push('/admin/profile'),
            ),
          ),
          // Bottom nav melayang di bawah
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNav(
              items: AppBottomNav.dashboardItems,
              currentIndex: _selectedIndex,
              useRouter: false,
              onTap: _onNavTap,
            ),
          ),
        ],
      ),
    );
  }
}
