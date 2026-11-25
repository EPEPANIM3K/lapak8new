import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'features/auth/providers/auth_provider.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await authProvider.restoreSession();
=======
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  await authProvider.init(); // pulihkan sesi login yang tersimpan
>>>>>>> c4d3b6adf1f29467316add0189fb5d57a0cafedd
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
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
      ),
      builder: (context, child) => AdaptiveToolbarHost(child: child!),
      routerConfig: appRouter,
    );
  }
}