import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/lapak_header.dart';
import '../widgets/greeting_section.dart';
import '../widgets/popular_items_section.dart';
import '../widgets/quick_actions_section.dart';
import '../widgets/summary_grid.dart';
import '../widgets/upcoming_borrowing_section.dart';
import '../widgets/bantuan_pic_modal.dart';
import '../widgets/dashboard_modals.dart';
import '../widgets/qr_ticket_modal.dart';

/// Beranda siswa/guru.
/// Data di bawah masih contoh (dummy) dari desain; nanti ganti dengan provider.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCM9TBr73lAvJae_M-j8bVPXa69t9E8fJjw6s1fOkJB9Rwn5SdnSrc2vwOfl_FwiSc0PAsKLZ3OrWbOxQRw_0Nv8TltDOZ-YW8v68X2WTQJl29s3nRn2_K2GuSWHAvMZpMCZJe6iBeZDp5yEl_7IcjmKNNuCgejx9XkiISbISzKzJKsN4oi8-ZVu-ddev07E4AA7eAz81C-Lou8NTkx4lFKRMgys8zcncLJEU3cjaxS9X4CrRZuET7Y';

  static const _popularItems = [
    PopularItem(
      name: 'DSLR Canon 80D',
      location: 'Studio Multimedia',
      stockLabel: '2 Unit',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDQi6ib_b9JDaJEF0sfrFJhYFa6XggzsfQj0kX9NPRBYlI1BYi4WIXIyfBk7IMvFr1RqtbYmUKkZwo6jYrkCbdwKxEbjmZbWME5VFKeOX7h9ZDuFu9VSYZ6AQRV5qHbzo8p3ggW7ZOCbcqLXZsGHW3nfEHOd16DW4ZYH_T8q2LPykmX9U1iPCCAXT9r8kjM3bRR2cZ5cuKQP2rZSSV-YTl92zcQmbWY6SID7XZIi8uuGWTbv6NpLNTe',
    ),
    PopularItem(
      name: 'Drawing Tablet',
      location: 'Lab Desain DKV',
      stockLabel: '6 Unit',
      imageUrl:
          'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?auto=format&fit=crop&w=600&q=80',
    ),
    PopularItem(
      name: 'Wireless Mic Set',
      location: 'Studio Audio Visual',
      stockLabel: '3 Set',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDZu4S04e_mAePsVPS1kM1N9wGxx4pcxEFtSzXLNlITwRjdVhMqz1jEhvbry3OwUONadOzyIW6nSHyXuigHsp4RDo9U-Q5fe2_LDCjORXpR8Ws71OYWzIYRmd-JHjwiPSS-QNRQ0t6Y8sqwOipxqhv2y4hGsEwAR8rOX9WLOHIcK4DSF-VBO-QMVoMDtybhTub_3e71cULJBFh5q4oDgv2cgqGZQsVepOsolm_T5cNuezT11ol2GrhZ',
    ),
    PopularItem(
      name: 'Proyektor Epson',
      location: 'Lab RPL • Lantai 2',
      stockLabel: '4 Unit',
      imageUrl:
          'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?auto=format&fit=crop&w=600&q=80',
    ),
  ];

  void _showQr() => showDialog(
        context: context,
        builder: (_) => const QrTicketModal(),
      );

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // main: pt-16 (di bawah header) dan pb 96 (di atas nav)
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(
              top: LapakHeader.contentHeight + inset.top,
              bottom: 96 + inset.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GreetingSection(
                  name: 'Alifia Zahra',
                  roleLabel: 'Siswa • XII RPL 1',
                  nis: '2122.10.408',
                ),
                const SummaryGrid(activeCount: 1, pendingCount: 1),
                UpcomingBorrowingSection(
                  title: 'Lab Komputer 2',
                  subtitle: 'Praktik Uji Sertifikasi LSP',
                  statusLabel: 'Disetujui',
                  scheduleLabel: 'Hari ini • 13:30 - 15:30 WIB',
                  approverName: 'Pak Budi Santoso, S.Kom',
                  approverRole: 'PIC Lab',
                  onShowQrTap: _showQr,
                ),
                QuickActionsSection(
                  items: QuickActionsSection.defaults(
                    onQuickBorrow: () => context.push('/borrowing-form'),
                    onSchedule: () => showDialog(
                      context: context,
                      builder: (_) => const AulaScheduleModal(),
                    ),
                    onRules: () => showDialog(
                      context: context,
                      builder: (_) => const PeraturanModal(),
                    ),
                    onHelp: () => showDialog(
                      context: context,
                      builder: (_) => const BantuanPicModal(),
                    ),
                  ),
                ),
                PopularItemsSection(
                  items: _popularItems,
                  onBorrowTap: (_) => context.push('/borrowing-form'),
                  onSeeAllTap: () => context.push('/facilities'),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LapakHeader(
              avatarUrl: _avatarUrl,
              onAvatarTap: () => context.push('/profile'),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNav(
              items: AppBottomNav.userItems,
              currentIndex: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
            ),
          ),
        ],
      ),
    );
  }
}
