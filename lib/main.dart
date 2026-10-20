
import 'package:flutter/material.dart';
import 'core/router/app_router.dart';

void main() {
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
      routerConfig: appRouter,
    );
  }
}
