
import 'package:flutter/material.dart';
import 'features/dashboard/screens/dashboard_screen.dart';

void main() {
  runApp(const Lapak8App());
}

class Lapak8App extends StatelessWidget {
  const Lapak8App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const DashboardScreen(),
    );
  }
}
