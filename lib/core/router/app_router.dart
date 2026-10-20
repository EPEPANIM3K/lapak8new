import 'package:go_router/go_router.dart';
import 'package:lapak8new/features/dashboard/screens/dashboard_screen.dart';
import 'package:lapak8new/features/facilities/screens/facility_list_screen.dart';
import 'package:lapak8new/features/borrowings/screens/my_borrowings_screen.dart';
import 'package:lapak8new/features/borrowings/screens/borrowing_form_screen.dart';
import 'package:lapak8new/features/history/screens/history_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const DashboardScreen(),
    ),
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
    GoRoute(
      path: '/history',
      builder: (_, __) => const HistoryScreen(),
    ),
  ],
);
