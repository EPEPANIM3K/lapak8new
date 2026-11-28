import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../borrowings/models/peminjaman.dart';
import '../../borrowings/services/peminjaman_service.dart';
import '../../facilities/models/facility.dart';
import '../../facilities/services/facility_service.dart';
import '../widgets/greeting_section.dart';
import '../widgets/popular_items_section.dart';
import '../widgets/quick_actions_section.dart';
import '../widgets/summary_grid.dart';
import '../widgets/upcoming_borrowing_section.dart';
import '../widgets/dashboard_modals.dart';
import '../widgets/qr_ticket_modal.dart';

/// Beranda siswa/guru.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Peminjaman> _borrowings = const [];
  List<Facility> _popularFacilities = const [];
  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _isQrLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait<Object>([
        peminjamanService.ambilDataDashboardSaya(),
        facilityService.fetchPopularFacilities(),
      ]);
      if (!mounted) return;
      setState(() {
        _borrowings = results[0] as List<Peminjaman>;
        _popularFacilities = results[1] as List<Facility>;
        _hasLoaded = true;
        _isLoading = false;
      });
    } on PeminjamanException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.pesan;
        _isLoading = false;
      });
    } on FacilityException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  int get _activeCount => _borrowings.where((borrowing) {
    return switch (borrowing.status) {
      StatusPeminjaman.dipinjam ||
      StatusPeminjaman.terlambat ||
      StatusPeminjaman.menungguPengembalian ||
      StatusPeminjaman.pelanggaran => true,
      _ => false,
    };
  }).length;

  int get _pendingCount => _borrowings
      .where(
        (borrowing) => borrowing.status == StatusPeminjaman.menungguPersetujuan,
      )
      .length;

  Peminjaman? get _upcomingBorrowing {
    final now = DateTime.now();
    final approved =
        _borrowings
            .where(
              (borrowing) =>
                  borrowing.status == StatusPeminjaman.disetujui &&
                  !borrowing.mulaiPada.isBefore(now),
            )
            .toList()
          ..sort((a, b) => a.mulaiPada.compareTo(b.mulaiPada));
    return approved.isEmpty ? null : approved.first;
  }

  String _formatDate(DateTime dateTime) {
    final date = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    final date = dateTime.toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _scheduleLabel(Peminjaman borrowing) =>
      '${_formatDate(borrowing.mulaiPada)} • '
      '${_formatTime(borrowing.mulaiPada)} - '
      '${_formatTime(borrowing.estimasiKembaliPada)} WIB';

  String _facilityTitle(Peminjaman borrowing) {
    if (borrowing.items.isEmpty) return borrowing.namaKegiatan;
    final firstItem = borrowing.items.first.namaFasilitasSnapshot;
    final additionalItems = borrowing.items.length - 1;
    return additionalItems == 0
        ? firstItem
        : '$firstItem + $additionalItems lainnya';
  }

  Future<void> _showQr(Peminjaman borrowing) async {
    if (_isQrLoading) return;
    setState(() => _isQrLoading = true);
    try {
      final ticket = await peminjamanService.buatTiketQr(
        peminjamanId: borrowing.id,
        tipe: 'pengambilan',
      );
      final payload = ticket['kode_qr'];
      final expiryValue = ticket['expired_at'];
      final expiresAt = expiryValue is String
          ? DateTime.tryParse(expiryValue)
          : null;
      if (payload is! String || expiresAt == null) {
        throw const PeminjamanException(
          'Data tiket QR dari server tidak lengkap atau tidak valid.',
        );
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => QrTicketModal(
          bookingCode: '#${borrowing.kodeBooking}',
          facilityName: _facilityTitle(borrowing),
          activity: borrowing.namaKegiatan,
          schedule: _scheduleLabel(borrowing),
          qrPayload: payload,
          borrowerName: authProvider.user?.namaLengkap ?? 'Peminjam LAPAK8',
          expiresAt: expiresAt,
        ),
      );
    } on PeminjamanException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.pesan)));
      }
    } finally {
      if (mounted) setState(() => _isQrLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedBuilder(
                animation: authProvider,
                builder: (context, _) {
                  final user = authProvider.user;
                  final name = user?.namaLengkap.trim();
                  final role = switch (user?.peran) {
                    'siswa' => 'Siswa',
                    'guru' => 'Guru',
                    'staf' => 'Staf',
                    'admin' => 'Admin',
                    _ => 'Pengguna',
                  };
                  final unit = user?.kelasAtauUnit?.trim();
                  final roleLabel = unit == null || unit.isEmpty
                      ? role
                      : '$role • $unit';

                  return GreetingSection(
                    name: name == null || name.isEmpty ? 'Pengguna' : name,
                    roleLabel: roleLabel,
                    nis: user?.nomorInduk ?? '',
                    nisLabel: user?.peran == 'siswa' ? 'NIS' : 'NIP',
                  );
                },
              ),
              SummaryGrid(
                activeCount: _hasLoaded ? _activeCount : null,
                pendingCount: _hasLoaded ? _pendingCount : null,
                isLoading: _isLoading,
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Data dashboard gagal dimuat: $_errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              UpcomingBorrowingSection(
                title: _isLoading && !_hasLoaded
                    ? 'Memuat pinjaman...'
                    : _upcomingBorrowing == null
                    ? 'Belum ada pinjaman mendatang'
                    : _facilityTitle(_upcomingBorrowing!),
                subtitle: _isLoading && !_hasLoaded
                    ? 'Memuat jadwal peminjaman...'
                    : _upcomingBorrowing?.namaKegiatan ??
                          'Peminjaman yang disetujui akan muncul di sini.',
                statusLabel: _isLoading && !_hasLoaded
                    ? '…'
                    : _upcomingBorrowing?.status.label ?? '—',
                scheduleLabel: _isLoading && !_hasLoaded
                    ? 'Memuat jadwal...'
                    : _upcomingBorrowing == null
                    ? 'Tidak ada jadwal mendatang'
                    : _scheduleLabel(_upcomingBorrowing!),
                approvalLabel:
                    _isLoading && !_hasLoaded || _upcomingBorrowing == null
                    ? null
                    : _upcomingBorrowing!.disetujuiPada == null
                    ? 'Peminjaman disetujui'
                    : 'Disetujui pada ${_formatDate(_upcomingBorrowing!.disetujuiPada!)}',
                onDetailTap: () => context.push('/borrowings'),
                onShowQrTap: _upcomingBorrowing == null
                    ? null
                    : () => _showQr(_upcomingBorrowing!),
                isQrLoading: _isQrLoading,
              ),
              QuickActionsSection(
                items: QuickActionsSection.defaults(
                  onQuickBorrow: () => context.go('/facilities'),
                  onSchedule: () => showDialog(
                    context: context,
                    builder: (_) => const AulaScheduleModal(),
                  ),
                  onRules: () => showDialog(
                    context: context,
                    builder: (_) => const PeraturanModal(),
                  ),
                  onHelp: () => context.push('/chat'),
                ),
              ),
              PopularItemsSection(
                items: _popularFacilities
                    .map(
                      (facility) => PopularItem(
                        name: facility.nama,
                        location: facility.lokasiNama,
                        stockLabel: '${facility.unitTersedia} Unit',
                        imageUrl: facility.fotoUrl,
                      ),
                    )
                    .toList(growable: false),
                emptyMessage: _isLoading
                    ? 'Memuat item populer...'
                    : _errorMessage != null
                    ? 'Item populer tidak dapat dimuat.'
                    : 'Belum ada item populer.',
                onBorrowTap: (_) => context.push('/borrowing-form'),
                onSeeAllTap: () => context.push('/facilities'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
