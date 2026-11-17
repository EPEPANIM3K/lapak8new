import 'package:go_router/go_router.dart';
import 'package:lapak8new/features/auth/providers/auth_provider.dart';
import 'package:lapak8new/features/auth/screens/login_screen.dart';
import 'package:lapak8new/features/dashboard/screens/dashboard_screen.dart';
import 'package:lapak8new/features/facilities/screens/facility_list_screen.dart';
import 'package:lapak8new/features/borrowings/screens/my_borrowings_screen.dart';
import 'package:lapak8new/features/borrowings/screens/borrowing_form_screen.dart';
import 'package:lapak8new/features/history/screens/history_screen.dart';
import 'package:lapak8new/features/profile/screens/profile_screen.dart';
import 'package:lapak8new/features/qr/screens/qr_scanner_screen.dart';

import 'package:lapak8new/features/admin/screens/admin_dashboard_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_borrowings_screen.dart';
import 'package:lapak8new/features/admin/screens/manage_facilities_screen.dart';
import 'package:lapak8new/features/admin/screens/facility_form_screen.dart';
import 'package:lapak8new/features/admin/screens/manage_users_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_profile_screen.dart';

// Halaman yang boleh dibuka tanpa login.
const _publicPaths = {'/login'};

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',

  // Router dievaluasi ulang setiap kali status login berubah
  // (login, logout, sesi habis).
  refreshListenable: authProvider,

  redirect: (context, state) {
    final loc = state.matchedLocation;
    final isPublic = _publicPaths.contains(loc);

    // Belum login -> paksa ke halaman login.
    if (!authProvider.isLoggedIn) {
      return isPublic ? null : '/login';
    }

    // Sudah login tapi masih di halaman login -> arahkan sesuai role.
    if (isPublic) {
      return authProvider.isAdmin ? '/admin/dashboard' : '/';
    }

    // Area admin hanya untuk admin.
    if (loc.startsWith('/admin') && !authProvider.isAdmin) {
      return '/';
    }

    return null; // tidak ada pengalihan
  },

  routes: [
    // ---------- AUTH ----------
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

    // ---------- USER ----------
    GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/facilities', builder: (_, __) => const FacilityListScreen()),
    GoRoute(path: '/borrowings', builder: (_, __) => const MyBorrowingsScreen()),
    GoRoute(path: '/borrowing-form', builder: (_, __) => const BorrowingFormScreen()),
    GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

    // ---------- UMUM ----------
    GoRoute(path: '/scan', builder: (_, __) => const QrScannerScreen()),

    // ---------- ADMIN ----------
    GoRoute(path: '/admin/dashboard', builder: (_, __) => const AdminDashboardScreen()),
    GoRoute(path: '/admin/borrowings', builder: (_, __) => const AdminBorrowingsScreen()),
    GoRoute(path: '/admin/items', builder: (_, __) => const ManageFacilitiesScreen()),
    GoRoute(
      path: '/admin/items/form',
      builder: (_, state) => FacilityFormScreen(
        initial: state.extra as FacilityFormData?,
      ),
    ),
    GoRoute(path: '/admin/manage', builder: (_, __) => const ManageUsersScreen()),
    GoRoute(path: '/admin/profile', builder: (_, __) => const AdminProfileScreen()),
  ],
);