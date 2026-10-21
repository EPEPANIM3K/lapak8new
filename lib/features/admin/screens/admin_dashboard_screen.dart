import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/dashboard/widgets/summary_card.dart';
import 'package:lapak8new/shared/widgets/app_bottom_nav.dart';
import 'package:lapak8new/shared/widgets/status_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _navIndex = 0;

  static const List<_Borrowing> _borrowings = [
    _Borrowing(
      initials: 'AP',
      name: 'Arya Putra',
      info: 'XII RPL 1 • NISN 21089',
      status: BorrowStatus.waiting,
      itemName: 'Huion Kamvas 16 Pro',
      itemDate: 'Tgl: 24 Okt 2024 • 08:00 WIB',
      icon: Icons.draw_outlined,
      avatarBg: AppColors.primaryFixed,
      avatarFg: AppColors.primary,
      showReview: true,
    ),
    _Borrowing(
      initials: 'SN',
      name: 'Siti Nurhaliza',
      info: 'XI MM 2 • Praktik Liputan',
      status: BorrowStatus.borrowed,
      itemName: 'Sony Alpha A7 III Kit',
      itemDate: 'Tgl: 24 Okt 2024 • 3 Hari',
      icon: Icons.photo_camera_outlined,
      avatarBg: AppColors.primaryFixed,
      avatarFg: AppColors.primary,
    ),
    _Borrowing(
      initials: 'AH',
      name: 'Drs. Agus Hidayat',
      info: 'Guru TKJ • Uji Kompetensi',
      status: BorrowStatus.approved,
      itemName: 'MikroTik Cloud Core',
      itemDate: 'Tgl: 24 Okt 2024 • Lab Jaringan',
      icon: Icons.router_outlined,
      avatarBg: AppColors.tertiaryFixed,
      avatarFg: AppColors.onTertiaryFixedVariant,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Desain memakai latar lavender (surfaceContainerLow), bukan background.
      backgroundColor: AppColors.surfaceContainerLow,
      body: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.mobileGutter,
                AppSpacing.md,
                AppSpacing.mobileGutter,
                AppSpacing.xl,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    'Dashboard',
                    style: AppTextStyles.headlineMd(color: AppColors.onSurface),
                  ),
                ),
                const SizedBox(height: 12),
                const _WelcomeCard(),
                const SizedBox(height: 16),
                _ScanButton(
                  onPressed: () {
                    onPressed:
                    () => context.push('/scan');
                  },
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Inventaris',
                  trailing: Text(
                    'Update real-time',
                    style: AppTextStyles.labelMd(
                      weight: FontWeight.w700,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummaryGrid(),
                const SizedBox(height: 16),
                const _ActivityChart(),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Peminjaman Terbaru', badge: '3'),
                const SizedBox(height: 12),
                for (final b in _borrowings) ...[
                  _BorrowingCard(data: b),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNav(
          items: AppBottomNav.dashboardItems,
          currentIndex: _navIndex,
          onTap: (i) => setState(() => _navIndex = i),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SummaryCard(
                value: '142',
                title: 'Total Item',
                subtitle: '+12 semester ini',
                icon: Icons.inventory_2_outlined,
                iconBackground: AppColors.primaryFixed,
                iconColor: AppColors.primary,
                valueColor: AppColors.onSurface,
                subtitleColor: AppColors.primary,
                subtitleWeight: FontWeight.w600,
                decorationColor: AppColors.primaryFixed.fade(0.4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                value: '98',
                title: 'Tersedia',
                subtitle: 'Siap dipinjam',
                icon: Icons.check_circle,
                iconFilled: true,
                iconBackground: AppColors.tertiaryFixed,
                iconColor: AppColors.onTertiaryFixedVariant,
                valueColor: AppColors.onSurface,
                subtitleColor: AppColors.onTertiaryFixedVariant,
                subtitleWeight: FontWeight.w600,
                decorationColor: AppColors.tertiaryFixed.fade(0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SummaryCard(
                value: '36',
                title: 'Dipinjam',
                subtitle: 'Siswa & Guru',
                icon: Icons.sync,
                iconBackground: AppColors.primaryFixed,
                iconColor: AppColors.primary,
                valueColor: AppColors.onSurface,
                subtitleColor: AppColors.slate600,
                decorationColor: AppColors.primaryFixed.fade(0.4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                value: '8',
                title: 'Konfirmasi',
                subtitle: 'Tinjau segera',
                icon: Icons.priority_high,
                iconFilled: true,
                iconBackground: AppColors.errorContainer,
                iconColor: AppColors.error,
                valueColor: AppColors.error,
                subtitleColor: AppColors.error,
                subtitleWeight: FontWeight.w600,
                decorationColor: AppColors.errorContainer.fade(0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar (logo + avatar)
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: AppShadows.sm,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAPAK8',
                      style: AppTextStyles.headlineSm(
                        color: AppColors.primary,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'SMKN 8 MALANG',
                      style: AppTextStyles.labelSm(
                        weight: FontWeight.w600,
                        color: AppColors.slate500,
                      ).copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              // Ganti child dengan foto profil: backgroundImage: AssetImage(...)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryFixed, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryFixed,
                  child: Icon(Icons.person, size: 20, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu putih umum
// ---------------------------------------------------------------------------
class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _WhiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu selamat datang
// ---------------------------------------------------------------------------
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed.fade(0.55),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sistem Online & Aktif',
                      style: AppTextStyles.labelSm(
                        color: AppColors.onTertiaryFixedVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppColors.slate600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Semester Ganjil',
                    style: AppTextStyles.labelMd(
                      weight: FontWeight.w700,
                      color: AppColors.slate600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Selamat Datang,',
            style: AppTextStyles.bodyMd(color: AppColors.slate600),
          ),
          const SizedBox(height: 2),
          Text(
            'Pak Bambang S., S.Kom',
            style: AppTextStyles.headlineMd(
              color: AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 16,
                color: AppColors.primaryContainer,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Pengelola Sarpras • SMK Negeri 8 Malang',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tombol scan
// ---------------------------------------------------------------------------
class _ScanButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ScanButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.qr_code_scanner, size: 22),
        label: Text(
          'Scan Tiket Akses',
          style: AppTextStyles.labelLg(
            weight: FontWeight.w700,
            color: AppColors.onPrimary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Judul section
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final String? badge;

  const _SectionHeader({required this.title, this.trailing, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            title,
            style: AppTextStyles.headlineSm(color: AppColors.onSurface),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge!,
                style: AppTextStyles.labelSm(color: AppColors.onError),
              ),
            ),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grafik aktivitas 7 hari
// ---------------------------------------------------------------------------
class _ActivityChart extends StatelessWidget {
  const _ActivityChart();

  static const List<String> _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const List<double> _borrow = [47, 63, 35, 75, 55, 19];
  static const List<double> _return = [31, 43, 39, 55, 47, 23];
  static const int _activeIndex = 3; // Kam (hari ini) dicetak tebal

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktivitas 7 Hari',
                      style: AppTextStyles.headlineSm(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Statistik peminjaman & pengembalian',
                      style: AppTextStyles.bodySm(
                        weight: FontWeight.w500,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LegendDot(color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Pinjam',
                      style: AppTextStyles.labelSm(
                        weight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const _LegendDot(color: AppColors.secondaryFixedDim),
                    const SizedBox(width: 4),
                    Text(
                      'Kembali',
                      style: AppTextStyles.labelSm(
                        weight: FontWeight.w600,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_days.length, (i) {
                final active = i == _activeIndex;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Bar(height: _borrow[i], color: AppColors.primary),
                        const SizedBox(width: 4),
                        _Bar(
                          height: _return[i],
                          color: AppColors.secondaryFixedDim,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _days[i],
                      style: AppTextStyles.labelSm(
                        weight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active
                            ? AppColors.onSurface
                            : AppColors.slate500,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;
  const _Bar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu peminjaman terbaru
// ---------------------------------------------------------------------------
class _Borrowing {
  final String initials;
  final String name;
  final String info;
  final BorrowStatus status;
  final String itemName;
  final String itemDate;
  final IconData icon;
  final Color avatarBg;
  final Color avatarFg;
  final bool showReview;

  const _Borrowing({
    required this.initials,
    required this.name,
    required this.info,
    required this.status,
    required this.itemName,
    required this.itemDate,
    required this.icon,
    required this.avatarBg,
    required this.avatarFg,
    this.showReview = false,
  });
}

class _BorrowingCard extends StatelessWidget {
  final _Borrowing data;
  const _BorrowingCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.avatarBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  data.initials,
                  style: AppTextStyles.headlineSm(
                    color: data.avatarFg,
                  ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: AppTextStyles.bodyMd(
                        weight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.info,
                      style: AppTextStyles.bodySm(
                        weight: FontWeight.w500,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: data.status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.base),
            ),
            child: Row(
              children: [
                Icon(data.icon, size: 22, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.itemName,
                        style: AppTextStyles.bodySm(
                          weight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ).copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.itemDate,
                        style: AppTextStyles.bodySm(
                          weight: FontWeight.w500,
                          color: AppColors.slate600,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (data.showReview)
                  ElevatedButton(
                    onPressed: () {
                      // TODO: buka konfirmasi / detail pengajuan
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      minimumSize: const Size(80, AppSpacing.touchTargetMin),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Tinjau',
                      style: AppTextStyles.labelLg(
                        weight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
