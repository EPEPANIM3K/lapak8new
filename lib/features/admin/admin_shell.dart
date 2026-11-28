import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/lapak_header.dart';
import '../auth/providers/auth_provider.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({required this.child, required this.location, super.key});

  static const _mainMenuPaths = {
    '/admin/dashboard',
    '/admin/borrowings',
    '/admin/history',
    '/admin/items',
    '/admin/manage',
  };

  final Widget child;
  final String location;

  int get _currentIndex => switch (location) {
    '/admin/dashboard' => 0,
    '/admin/borrowings' => 1,
    '/admin/history' => 2,
    '/admin/items' => 3,
    '/admin/manage' => 4,
    _ => -1,
  };

  @override
  Widget build(BuildContext context) {
    if (!_mainMenuPaths.contains(location)) return child;

    final insets = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: LapakHeader.contentHeight + insets.top,
                bottom: AppBottomNav.totalHeight + insets.bottom,
              ),
              child: child,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: authProvider,
              builder: (context, _) => LapakHeader(
                avatarUrl: authProvider.user?.fotoUrl ?? '',
                onAvatarTap: () => context.push('/admin/profile'),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AdminBottomNav(currentIndex: _currentIndex),
          ),
        ],
      ),
    );
  }
}
