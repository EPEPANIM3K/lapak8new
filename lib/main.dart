import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/constants/app_colors.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/notifications/controllers/notification_badge_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey, // ignore: deprecated_member_use
  );
  await authProvider.init(); // pulihkan sesi login yang tersimpan

  String? boundNotificationUserId;
  void syncNotificationBinding() {
    final userId = authProvider.user?.id;
    if (userId == boundNotificationUserId) return;
    boundNotificationUserId = userId;
    notificationBadgeController.bind(userId);
  }

  authProvider.addListener(syncNotificationBinding);
  syncNotificationBinding();

  runApp(const Lapak8App());
}

class Lapak8App extends StatelessWidget {
  const Lapak8App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LAPAK8',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Outfit',
        scaffoldBackgroundColor: AppColors.surface,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
      builder: (context, child) => AdaptiveToolbarHost(child: child!),
      routerConfig: appRouter,
    );
  }
}
