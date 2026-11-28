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
import 'package:lapak8new/features/notifications/screens/notifications_screen.dart';
import 'package:lapak8new/features/splash/presentation/splash_screen.dart';
import 'package:lapak8new/features/welcome/presentation/welcome_screen.dart';

import 'package:lapak8new/features/admin/admin_shell.dart';
import 'package:lapak8new/features/admin/screens/admin_dashboard_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_borrowings_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_history_screen.dart';
import 'package:lapak8new/features/admin/screens/manage_facilities_screen.dart';
import 'package:lapak8new/features/admin/screens/manage_users_screen.dart';
import 'package:lapak8new/features/admin/screens/admin_profile_screen.dart';
import 'package:lapak8new/shared/widgets/user_app_shell.dart';

// Halaman yang boleh dibuka tanpa login.
const _publicPaths = {'/login', '/password-reset-help', '/welcome'};

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',

  // Router dievaluasi ulang setiap kali status login berubah
  refreshListenable: authProvider,

  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (loc == '/splash') return null;

    final isPublic = _publicPaths.contains(loc);

    // Belum login → paksa ke halaman login.
    if (!authProvider.sudahLogin) {
      return isPublic ? null : '/login';
    }

    // Sudah login tapi masih di halaman login → arahkan sesuai role.
    if (isPublic) {
      return authProvider.isAdmin ? '/admin/dashboard' : '/';
    }

    // Scanner hanya tersedia untuk admin dan staf aktif.
    if (loc == '/scan' && !authProvider.isAdminAtauStaf) {
      return '/';
    }

    // Area admin hanya untuk admin/staf.
    if (loc.startsWith('/admin') && !authProvider.isAdminAtauStaf) {
      return '/';
    }

    return null; // tidak ada pengalihan
  },

  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),

    // ---------- AUTH ----------
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: '/password-reset-help',
      builder: (_, __) => const ChatScreen(passwordResetHelp: true),
    ),

    // ---------- USER ----------
    ShellRoute(
      builder: (context, state, child) =>
          UserAppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(
          path: '/facilities',
          builder: (_, __) => const FacilityListScreen(),
        ),
        GoRoute(
          path: '/borrowings',
          builder: (_, __) => const MyBorrowingsScreen(),
        ),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
        GoRoute(
          path: '/borrowing-form',
          builder: (_, state) => BorrowingFormScreen(
            initialFacilityId: state.extra is String
                ? state.extra as String
                : null,
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen(),
        ),
      ],
    ),
    // ---------- UMUM ----------
    GoRoute(
      path: '/scan',
      builder: (_, state) {
        final extra = state.extra;
        final peminjamanId = extra is Map ? extra['peminjamanId'] : null;
        final returnPeminjamanId = extra is Map
            ? extra['returnPeminjamanId']
            : null;
        return QrScannerScreen(
          expectedBorrowingId: peminjamanId is String ? peminjamanId : null,
          expectedReturnBorrowingId: returnPeminjamanId is String
              ? returnPeminjamanId
              : null,
        );
      },
    ),

    // ---------- ADMIN ----------
    ShellRoute(
      builder: (context, state, child) =>
          AdminShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (_, __) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/borrowings',
          builder: (_, state) {
            final extra = state.extra;
            final inspectionId = extra is Map
                ? extra['return_inspection_id']
                : null;
            final borrowingId = extra is Map ? extra['peminjaman_id'] : null;
            return AdminBorrowingsScreen(
              initialReturnInspectionId: inspectionId is String
                  ? inspectionId
                  : null,
              initialReturnBorrowingId: borrowingId is String
                  ? borrowingId
                  : null,
            );
          },
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
        GoRoute(path: '/admin/chat', builder: (_, __) => const ChatScreen()),
      ],
    ),
  ],
);
