import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'app_bottom_nav.dart';
import 'lapak_header.dart';

class UserAppShell extends StatelessWidget {
  const UserAppShell({required this.child, required this.location, super.key});

  static const _mainMenuPaths = {'/', '/facilities', '/borrowings', '/history'};

  final Widget child;
  final String location;

  int get _currentIndex => switch (location) {
    '/' => 0,
    '/facilities' => 1,
    '/borrowings' => 2,
    '/history' => 3,
    _ => -1,
  };

  @override
  Widget build(BuildContext context) {
    if (!_mainMenuPaths.contains(location)) return child;

    final insets = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
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
                onAvatarTap: () => context.push('/profile'),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNav(
              items: AppBottomNav.userItems,
              currentIndex: _currentIndex,
              onTap: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
