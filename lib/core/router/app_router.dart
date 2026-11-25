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
import 'package:lapak8new/features/chat/screens/chat_screen.dart';

import 'package:lapak8new/features/admin/screens/admin_dashboard_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_borrowings_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_history_screen.dart';
import 'package:lapak8new/features/admin/screens/manage_facilities_screen.dart';
import 'package:lapak8new/features/admin/screens/manage_users_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_profile_screen.dart';
import 'package:lapak8new/features/auth/providers/auth_provider.dart';

// Halaman yang boleh dibuka tanpa login.
const _publicPaths = {'/login'};

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
<<<<<<< HEAD
  refreshListenable: authProvider,
  redirect: (_, state) {
    final user = authProvider.user;
    final location = state.matchedLocation;
    final isAuthRoute = location == '/login' || location == '/welcome';
    if (user == null && !isAuthRoute) return '/login';
    if (user != null && isAuthRoute) return user.isStaff ? '/admin' : '/';
    if (user != null && location.startsWith('/admin') && !user.isStaff) {
      return '/';
    }
    return null;
  },
=======

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

>>>>>>> c4d3b6adf1f29467316add0189fb5d57a0cafedd
  routes: [
    // ---------- AUTH ----------
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

    // ---------- USER ----------
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
    GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),

    // ---------- UMUM ----------
    GoRoute(path: '/scan', builder: (_, __) => const QrScannerScreen()),

    // ---------- ADMIN ----------
    GoRoute(
      path: '/admin/dashboard',
      builder: (_, __) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/borrowings',
      builder: (_, __) => const AdminBorrowingsScreen(),
    ),
    GoRoute(
      path: '/admin/history',
      builder: (_, __) => const AdminHistoryScreen(),
    ),
    GoRoute(
      path: '/admin/items',
      builder: (_, __) => const ManageFacilitiesScreen(),
    ),
    GoRoute(
      path: '/admin/manage',
      builder: (_, __) => const ManageUsersScreen(),
    ),
    GoRoute(
      path: '/admin/profile',
      builder: (_, __) => const AdminProfileScreen(),
    ),
  ],
);
