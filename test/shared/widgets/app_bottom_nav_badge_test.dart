import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapak8new/shared/widgets/app_bottom_nav.dart';

Widget _buildNav(int badgeCount) {
  return MaterialApp(
    home: Scaffold(
      body: AppBottomNav(
        items: [
          AppBottomNavItem(
            icon: Icons.home,
            label: 'Aktivitas',
            badgeCount: badgeCount,
            route: '/admin/borrowings',
          ),
        ],
        currentIndex: 0,
        onTap: (_) {},
        useRouter: false,
      ),
    ),
  );
}

void main() {
  testWidgets('badgeCount 3 menampilkan angka 3', (tester) async {
    await tester.pumpWidget(_buildNav(3));

    expect(find.text('3'), findsOneWidget);
    expect(
      find.byKey(const Key('notification-badge-/admin/borrowings')),
      findsOneWidget,
    );
  });

  testWidgets('badgeCount 100 dibatasi menjadi 99+', (tester) async {
    await tester.pumpWidget(_buildNav(100));

    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('badgeCount 0 tidak merender badge', (tester) async {
    await tester.pumpWidget(_buildNav(0));

    expect(find.text('0'), findsNothing);
    expect(
      find.byKey(const Key('notification-badge-/admin/borrowings')),
      findsNothing,
    );
  });
}
