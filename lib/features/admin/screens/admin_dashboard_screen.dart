import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/auth/providers/auth_provider.dart';
import 'package:lapak8new/features/dashboard/widgets/summary_card.dart';
import 'package:lapak8new/features/facilities/models/facility.dart';
import 'package:lapak8new/features/facilities/services/facility_service.dart';
import 'package:lapak8new/features/borrowings/models/peminjaman.dart';
import 'package:lapak8new/features/borrowings/services/peminjaman_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.onReviewTap});

  final VoidCallback? onReviewTap;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _totalItems = 0;
  int _availableItems = 0;
  int _activeBorrowings = 0;
  int _pendingApprovals = 0;
  List<Peminjaman> _recentBorrowings = const [];
  List<_DailyActivity> _weeklyActivities = const [];
  bool _isLoading = true;
  bool _hasLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<Object>([
        facilityService.fetchFacilities(),
        peminjamanService.ambilSemuaPeminjaman(perHalaman: 3),
        peminjamanService.hitungMenungguPersetujuan(),
        peminjamanService.hitungPeminjamanAktif(),
        peminjamanService.ambilAktivitasMingguan(),
      ]);
      if (!mounted) return;

      final facilities = results[0] as List<Facility>;
      final recentBorrowings = results[1] as List<Peminjaman>;
      final weeklyActivity = results[4] as AktivitasPeminjamanMingguan;

      setState(() {
        _totalItems = facilities.fold(
          0,
          (total, facility) => total + facility.totalUnit,
        );
        _availableItems = facilities.fold(
          0,
          (total, facility) =>
              total +
              (facility.isAvailable
                  ? facility.unitTersedia.clamp(0, facility.totalUnit)
                  : 0),
        );
        _recentBorrowings = recentBorrowings;
        _pendingApprovals = results[2] as int;
        _activeBorrowings = results[3] as int;
        _weeklyActivities = _groupWeeklyActivity(weeklyActivity);
        _hasLoaded = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<_DailyActivity> _groupWeeklyActivity(
    AktivitasPeminjamanMingguan activity,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = today.subtract(const Duration(days: 6));
    final borrowings = List<int>.filled(7, 0);
    final returns = List<int>.filled(7, 0);

    void addDates(List<DateTime> dates, List<int> counts) {
      for (final value in dates) {
        final local = value.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        final index = day.difference(firstDay).inDays;
        if (index >= 0 && index < counts.length) counts[index]++;
      }
    }

    addDates(activity.pengajuan, borrowings);
    addDates(activity.pengembalian, returns);

    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return List.generate(7, (index) {
      final date = firstDay.add(Duration(days: index));
      return _DailyActivity(
        label: weekdays[date.weekday - 1],
        borrowings: borrowings[index],
        returns: returns[index],
        isToday: index == 6,
      );
    });
  }

  Future<void> _scanAccessTicket() async {
    final result = await context.push<Map<String, dynamic>>('/scan');
    if (!mounted || result == null) return;

    if (result['tipe_tiket'] == 'pengembalian') {
      context.go('/admin/borrowings', extra: result);
    } else {
      await _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Latar netral yang sama dengan halaman User (AppColors.surface).
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
            _ScanButton(onPressed: _scanAccessTicket),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(message: _error!, onRetry: _loadDashboardData),
            ],
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Inventaris',
              trailing: Text(
                _isLoading ? 'Memuat data...' : 'Data terbaru',
                style: AppTextStyles.labelMd(
                  weight: FontWeight.w700,
                  color: AppColors.slate500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSummaryGrid(),
            const SizedBox(height: 16),
            _ActivityChart(
              activities: _weeklyActivities,
              isLoading: _isLoading,
              hasError: _error != null && !_hasLoaded,
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Peminjaman Terbaru',
              badge: _hasLoaded ? '${_recentBorrowings.length}' : null,
            ),
            const SizedBox(height: 12),
            _buildRecentBorrowings(),
          ],
        ),
      ),
    );
  }

  String _statValue(int value) {
    if (_isLoading) return '...';
    if (!_hasLoaded) return '—';
    return value.toString();
  }

  Widget _buildSummaryGrid() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SummaryCard(
                value: _statValue(_totalItems),
                title: 'Total Item',
                subtitle: 'Unit inventaris',
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
                value: _statValue(_availableItems),
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
                value: _statValue(_activeBorrowings),
                title: 'Peminjaman Aktif',
                subtitle: 'Transaksi berjalan',
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
                value: _statValue(_pendingApprovals),
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

  Widget _buildRecentBorrowings() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasLoaded) return const SizedBox.shrink();
    if (_recentBorrowings.isEmpty) {
      return const _WhiteCard(
        child: Column(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 40,
              color: AppColors.slate500,
            ),
            SizedBox(height: 8),
            Text(
              'Belum ada peminjaman',
              style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Peminjaman terbaru akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate600),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final borrowing in _recentBorrowings) ...[
          _BorrowingCard(
            borrowing: borrowing,
            onReviewTap:
                widget.onReviewTap ?? () => context.go('/admin/borrowings'),
          ),
          const SizedBox(height: 12),
        ],
      ],
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 8),
          Text(
            'Gagal memuat data dashboard',
            style: AppTextStyles.bodyMd(
              weight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm(color: AppColors.slate600),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
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
    return AnimatedBuilder(
      animation: authProvider,
      builder: (context, _) {
        final user = authProvider.user;
        final name = user?.namaLengkap.trim();
        final displayName = name == null || name.isEmpty ? 'Pengelola' : name;
        final role = switch (user?.peran) {
          'admin' => 'Pengelola Sarpras',
          'staf' => 'Staf Sarpras',
          'guru' => 'Guru',
          'siswa' => 'Siswa',
          _ => 'Pengelola Sarpras',
        };
        final unit = user?.kelasAtauUnit?.trim();
        final roleLabel = unit == null || unit.isEmpty ? role : '$role • $unit';

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
                displayName,
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
                      roleLabel,
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
      },
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
class _DailyActivity {
  const _DailyActivity({
    required this.label,
    required this.borrowings,
    required this.returns,
    required this.isToday,
  });

  final String label;
  final int borrowings;
  final int returns;
  final bool isToday;
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({
    required this.activities,
    required this.isLoading,
    required this.hasError,
  });

  final List<_DailyActivity> activities;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final highestCount = activities.fold<int>(
      0,
      (highest, day) => [
        highest,
        day.borrowings,
        day.returns,
      ].reduce((a, b) => a > b ? a : b),
    );

    double barHeight(int count) {
      if (highestCount == 0) return 4;
      return (count / highestCount * 76).clamp(4.0, 76.0).toDouble();
    }

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
          if (isLoading)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasError)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Aktivitas tidak dapat dimuat.',
                  style: AppTextStyles.bodySm(color: AppColors.slate600),
                ),
              ),
            )
          else ...[
            if (highestCount == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Belum ada aktivitas dalam 7 hari terakhir.',
                  style: AppTextStyles.bodySm(color: AppColors.slate600),
                ),
              ),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final day in activities)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Bar(
                              height: barHeight(day.borrowings),
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            _Bar(
                              height: barHeight(day.returns),
                              color: AppColors.secondaryFixedDim,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          day.label,
                          style: AppTextStyles.labelSm(
                            weight: day.isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: day.isToday
                                ? AppColors.onSurface
                                : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
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
class _BorrowingCard extends StatelessWidget {
  const _BorrowingCard({required this.borrowing, required this.onReviewTap});

  final Peminjaman borrowing;
  final VoidCallback? onReviewTap;

  @override
  Widget build(BuildContext context) {
    final name = borrowing.namaPeminjam?.trim().isNotEmpty == true
        ? borrowing.namaPeminjam!.trim()
        : 'Pengguna LAPAK8';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final details = [
      if (borrowing.kelasPeminjam?.trim().isNotEmpty == true)
        borrowing.kelasPeminjam!.trim(),
      if (borrowing.nomorIndukPeminjam?.trim().isNotEmpty == true)
        'ID: ${borrowing.nomorIndukPeminjam!.trim()}',
    ].join(' • ');
    final itemName = borrowing.items.isEmpty
        ? borrowing.namaKegiatan
        : borrowing.items.first.namaFasilitasSnapshot;
    final date = borrowing.dibuatPada.toLocal();
    final dateLabel =
        'Diajukan: ${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';

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
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials.isEmpty ? 'U' : initials,
                  style: AppTextStyles.headlineSm(
                    color: AppColors.primary,
                  ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodyMd(
                        weight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details.isEmpty ? borrowing.labelKategori : details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm(
                        weight: FontWeight.w500,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              _BorrowingStatusBadge(status: borrowing.status),
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
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySm(
                          weight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ).copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: AppTextStyles.bodySm(
                          weight: FontWeight.w500,
                          color: AppColors.slate600,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (borrowing.status == StatusPeminjaman.menungguPersetujuan)
                  ElevatedButton(
                    onPressed: onReviewTap,
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

class _BorrowingStatusBadge extends StatelessWidget {
  const _BorrowingStatusBadge({required this.status});

  final StatusPeminjaman status;

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, foregroundColor) = switch (status) {
      StatusPeminjaman.menungguPersetujuan => (
        const Color(0xFFFFF1D6),
        const Color(0xFFB45309),
      ),
      StatusPeminjaman.disetujui || StatusPeminjaman.dikembalikan => (
        AppColors.tertiaryFixed,
        AppColors.onTertiaryFixedVariant,
      ),
      StatusPeminjaman.dipinjam => (AppColors.primaryFixed, AppColors.primary),
      StatusPeminjaman.menungguPengembalian => (
        const Color(0xFFFFF1D6),
        const Color(0xFFB45309),
      ),
      StatusPeminjaman.terlambat ||
      StatusPeminjaman.pelanggaran ||
      StatusPeminjaman.ditolak => (AppColors.errorContainer, AppColors.error),
      StatusPeminjaman.dibatalkan || StatusPeminjaman.tidak_dikenal => (
        AppColors.surfaceContainerHigh,
        AppColors.slate600,
      ),
    };
    final label = switch (status) {
      StatusPeminjaman.menungguPersetujuan => 'Menunggu',
      StatusPeminjaman.disetujui => 'Disetujui',
      StatusPeminjaman.dipinjam => 'Dipinjam',
      StatusPeminjaman.menungguPengembalian => 'Menunggu Pengembalian',
      StatusPeminjaman.pelanggaran => 'Pelanggaran',
      StatusPeminjaman.dikembalikan => 'Dikembalikan',
      StatusPeminjaman.terlambat => 'Terlambat',
      StatusPeminjaman.ditolak => 'Ditolak',
      StatusPeminjaman.dibatalkan => 'Dibatalkan',
      StatusPeminjaman.tidak_dikenal => 'Tidak dikenal',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm(
          weight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }
}
