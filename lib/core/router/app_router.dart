import 'package:go_router/go_router.dart';
import 'package:lapak8new/features/dashboard/screens/dashboard_screen.dart';
import 'package:lapak8new/features/facilities/screens/facility_list_screen.dart';
import 'package:lapak8new/features/borrowings/screens/my_borrowings_screen.dart';
import 'package:lapak8new/features/borrowings/screens/borrowing_form_screen.dart';
import 'package:lapak8new/features/history/screens/history_screen.dart';
import 'package:lapak8new/features/profile/screens/profile_screen.dart';

import 'package:lapak8new/features/admin/screens/admin_dashboard_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_borrowings_screen.dart';
import 'package:lapak8new/features/qr/screens/qr_scanner_screen.dart';

final GoRouter appRouter = GoRouter(
  // DIUBAH: sementara buka admin dulu saat development.
  // Balikin ke '/' kalau mau buka user.
  initialLocation: '/admin/dashboard',
  routes: [
    // ---------- USER (tidak diubah) ----------
    GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
    GoRoute(
      path: '/facilities',
      builder: (_, __) => const FacilityListScreen(),
    ),
    GoRoute(
      path: '/borrowings',
      builder: (_, __) => const MyBorrowingsScreen(),
    ),
    GoRoute(
      path: '/borrowing-form',
      builder: (_, __) => const BorrowingFormScreen(),
    ),
    GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/scan', builder: (_, __) => const QrScannerScreen()),

    // ---------- ADMIN (BARU) ----------
    GoRoute(
      path: '/admin/dashboard',
      builder: (_, __) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/borrowings',
      builder: (_, __) => const AdminBorrowingsScreen(),
    ),
  ],
);
