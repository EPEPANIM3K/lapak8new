import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import 'admin_route_observer.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/lapak_header.dart';
import '../auth/providers/auth_provider.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _mainMenuPaths = {
    '/admin/dashboard',
    '/admin/borrowings',
    '/admin/history',
    '/admin/items',
    '/admin/manage',
  };

  int get _currentIndex => switch (widget.location) {
    '/admin/dashboard' => 0,
    '/admin/borrowings' => 1,
    '/admin/history' => 2,
    '/admin/items' => 3,
    '/admin/manage' => 4,
    _ => -1,
  };

  @override
  void didUpdateWidget(covariant AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      adminActiveLocation.value = widget.location;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_mainMenuPaths.contains(widget.location)) return widget.child;

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
              child: widget.child,
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
