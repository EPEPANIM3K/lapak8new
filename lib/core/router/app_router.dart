import 'package:go_router/go_router.dart';
import 'package:lapak8new/features/auth/screens/login_screen.dart';
import 'package:lapak8new/features/auth/screens/welcome_screen.dart';
import 'package:lapak8new/features/dashboard/screens/dashboard_screen.dart';
import 'package:lapak8new/features/facilities/screens/facility_list_screen.dart';
import 'package:lapak8new/features/borrowings/screens/my_borrowings_screen.dart';
import 'package:lapak8new/features/borrowings/screens/borrowing_form_screen.dart';
import 'package:lapak8new/features/history/screens/history_screen.dart';
import 'package:lapak8new/features/notifications/screens/notifications_screen.dart';
import 'package:lapak8new/features/profile/screens/profile_screen.dart';
import 'package:lapak8new/features/qr/screens/qr_scanner_screen.dart';
import 'package:lapak8new/features/chat/screens/chat_screen.dart';

import 'package:lapak8new/features/admin/admin_shell.dart';
import 'package:lapak8new/features/admin/screens/facility_form_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_profile_screen.dart';
import 'package:lapak8new/features/auth/providers/auth_provider.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
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
  routes: [
    // ---------- AUTH ----------
    GoRoute(path: '/welcome', builder: (_, __) => const IntroScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

    // ---------- USER ----------
    GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/facilities', builder: (_, __) => const FacilityListScreen()),
    GoRoute(path: '/borrowings', builder: (_, __) => const MyBorrowingsScreen()),
    GoRoute(path: '/borrowing-form', builder: (_, __) => const BorrowingFormScreen()),
    GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),

    // ---------- UMUM ----------
    GoRoute(path: '/scan', builder: (_, __) => const QrScannerScreen()),
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationsScreen(),
    ),

    // ---------- ADMIN ----------
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminShell(),
      routes: [
        GoRoute(
          path: 'items/form',
          builder: (_, state) => FacilityFormScreen(
            initial: state.extra as FacilityFormData?,
          ),
        ),
        GoRoute(path: 'profile', builder: (_, __) => const AdminProfileScreen()),
      ],
    ),
  ],
);