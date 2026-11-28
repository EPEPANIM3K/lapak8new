import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../shared/widgets/lapak_header.dart';
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
          AnimatedBuilder(
            animation: authProvider,
            builder: (context, _) => LapakHeader(
              avatarUrl: authProvider.user?.fotoUrl ?? '',
              onAvatarTap: () => context.push('/admin/profile'),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
