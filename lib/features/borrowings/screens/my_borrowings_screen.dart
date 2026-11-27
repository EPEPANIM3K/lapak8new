import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/lapak_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/qr_ticket_modal.dart';
import '../models/peminjaman.dart';
import '../services/peminjaman_service.dart';
import 'borrowing_detail_screen.dart';

class MyBorrowingsScreen extends StatefulWidget {
  const MyBorrowingsScreen({super.key});

  @override
  State<MyBorrowingsScreen> createState() => _MyBorrowingsScreenState();
}

class _MyBorrowingsScreenState extends State<MyBorrowingsScreen> {
  static const cSurface = Color(0xFFFAF8FF);
  static const cSurfaceLowest = Color(0xFFFFFFFF);
  static const cSurfaceLow = Color(0xFFF2F3FF);
  static const cSurfaceContainer = Color(0xFFEAEDFF);
  static const cSurfaceHigh = Color(0xFFE2E7FF);
  static const cOnSurface = Color(0xFF131B2E);
  static const cOnSurfaceVariant = Color(0xFF434655);
  static const cPrimary = Color(0xFF0037B0);
  static const cPrimaryContainer = Color(0xFF1D4ED8);
  static const cTertiary = Color(0xFF004F35);
  static const cTertiaryFixed = Color(0xFF6FFBBE);
  static const cError = Color(0xFFBA1A1A);
  static const cErrorContainer = Color(0xFFFFDAD6);
  static const cOnErrorContainer = Color(0xFF93000A);
  static const cSecondary = Color(0xFF505F76);
  static const cSecondaryContainer = Color(0xFFD0E1FB);
  static const cOnSecondaryContainer = Color(0xFF54647A);
  static const cOutlineVariant = Color(0xFFC4C5D7);

  String _tab = 'aktif';
  List<Peminjaman> _list = [];
  bool _loading = true;
  String? _errorMessage;
  final Set<String> _cancellingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await peminjamanService.ambilPeminjamanSaya();
      if (!mounted) return;
      setState(() {
        _list = data;
        _loading = false;
      });
    } on PeminjamanException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.pesan;
        _loading = false;
      });
    }
  }

  List<Peminjaman> get _activeList => _list
      .where(
        (p) =>
            p.status == StatusPeminjaman.disetujui ||
            p.status == StatusPeminjaman.dipinjam ||
            p.status == StatusPeminjaman.terlambat,
      )
      .toList();

  List<Peminjaman> get _pendingList => _list
      .where((p) => p.status == StatusPeminjaman.menungguPersetujuan)
      .toList();

  List<Peminjaman> get _historyList => _list
      .where(
        (p) =>
            p.status == StatusPeminjaman.ditolak ||
            p.status == StatusPeminjaman.dikembalikan ||
            p.status == StatusPeminjaman.dibatalkan,
      )
      .toList();

  void _switchTab(String t) => setState(() => _tab = t);

  void _showQrModal(Peminjaman p) {
    final facilityTitle = _facilityTitle(p);
    showDialog<void>(
      context: context,
      builder: (_) => QrTicketModal(
        bookingCode: '#${p.kodeBooking}',
        facilityName: facilityTitle,
        activity: p.namaKegiatan,
        schedule:
            '${_formatDate(p.mulaiPada)} • ${_formatTime(p.mulaiPada)} - ${_formatTime(p.estimasiKembaliPada)} WIB',
        picName: p.namaPeminjam ?? 'Petugas Sarpras',
      ),
    );
  }

  void _openDetail(Peminjaman p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BorrowingDetailSheet(peminjaman: p),
    );
  }

  Future<void> _cancelBooking(Peminjaman p) async {
    final facilityTitle = _facilityTitle(p);
    var confirmed = false;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Icons.event_busy,
        title: 'Batalkan Reservasi?',
        message:
            'Apakah Anda yakin ingin membatalkan reservasi $facilityTitle?',
        cancelText: 'Tidak',
        confirmText: 'Ya, Batalkan',
        confirmIcon: Icons.cancel_outlined,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        onConfirm: () => confirmed = true,
      ),
    );
    if (!confirmed || !mounted) return;
    setState(() => _cancellingIds.add(p.id));
    try {
      await peminjamanService.batalkan(p.id);
      if (!mounted) return;
      _snack('Peminjaman ${p.kodeBooking} berhasil dibatalkan.');
      await _load();
    } on PeminjamanException catch (e) {
      if (!mounted) return;
      _snack(e.pesan, error: true);
    } finally {
      if (mounted) setState(() => _cancellingIds.remove(p.id));
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: error ? cError : null),
      );
  }

  String _facilityTitle(Peminjaman p) {
    if (p.items.isEmpty) return p.namaKegiatan;
    final first = p.items.first.namaFasilitasSnapshot;
    if (p.items.length == 1) return first;
    return '$first (+${p.items.length - 1} lainnya)';
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${days[local.weekday - 1]}, ${local.day} ${months[local.month - 1]} ${local.year}';
  }

  String _formatTime(DateTime d) {
    final local = d.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    final activeItems = _activeList;
    final pendingItems = _pendingList;
    final historyItems = _historyList;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              edgeOffset: LapakHeader.contentHeight + inset.top,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        LapakHeader.contentHeight + inset.top + 12,
                        16,
                        12,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _tabBtn(
                              'aktif',
                              'Peminjaman Aktif',
                              count: activeItems.length,
                            ),
                            const SizedBox(width: 8),
                            _tabBtn(
                              'menunggu',
                              'Menunggu Persetujuan',
                              count: pendingItems.length,
                            ),
                            const SizedBox(width: 8),
                            _tabBtn(
                              'riwayat',
                              'Selesai & Ditolak',
                              count: historyItems.length,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildBody(
                    activeItems: activeItems,
                    pendingItems: pendingItems,
                    historyItems: historyItems,
                    bottomInset: inset.bottom,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LapakHeader(
              avatarUrl: authProvider.user?.fotoUrl ?? '',
              onNotificationTap: () => _snack('Belum ada notifikasi baru.'),
              onAvatarTap: () => context.push('/profile'),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNav(
              items: AppBottomNav.userItems,
              currentIndex: 2,
              onTap: (_) {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required List<Peminjaman> activeItems,
    required List<Peminjaman> pendingItems,
    required List<Peminjaman> historyItems,
    required double bottomInset,
  }) {
    final bottomPadding = AppBottomNav.totalHeight + bottomInset + 16;
    if (_loading) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
        sliver: const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_errorMessage != null) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
        sliver: SliverToBoxAdapter(child: _buildErrorState()),
      );
    }

    final List<Peminjaman> currentItems = switch (_tab) {
      'aktif' => activeItems,
      'menunggu' => pendingItems,
      _ => historyItems,
    };

    if (currentItems.isEmpty) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEmptyState(),
              const SizedBox(height: 16),
              _buildHelpBanner(),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final helpBannerIndex = currentItems.length * 2;
          if (index == helpBannerIndex) return _buildHelpBanner();
          if (index == helpBannerIndex - 1) {
            return const SizedBox(height: 16);
          }
          if (index.isOdd) return const SizedBox(height: 14);
          return _buildCard(currentItems[index ~/ 2]);
        }, childCount: currentItems.length * 2 + 1),
      ),
    );
  }

  Widget _buildCard(Peminjaman p) {
    return switch (p.status) {
      StatusPeminjaman.disetujui ||
      StatusPeminjaman.dipinjam ||
      StatusPeminjaman.terlambat => _cardAktif(p),
      StatusPeminjaman.menungguPersetujuan => _cardMenunggu(p),
      _ => _cardHistoryOrRejected(p),
    };
  }

  Widget _tabBtn(String key, String label, {required int count}) {
    final selected = _tab == key;
    return GestureDetector(
      onTap: () => _switchTab(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cPrimary : cSurfaceLowest,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : cOnSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? cSurface : cSurfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? cPrimary : cOnSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== CARD AKTIF =====
  Widget _cardAktif(Peminjaman p) {
    final isCancelling = _cancellingIds.contains(p.id);
    final image = p.items.isNotEmpty ? p.items.first.fotoUrl : null;
    final statusBadge = switch (p.status) {
      StatusPeminjaman.dipinjam => _statusPill(
        'Sedang Dipinjam',
        cSurfaceContainer,
        cPrimary,
        Icons.inventory_2_outlined,
      ),
      StatusPeminjaman.terlambat => _statusPill(
        'Terlambat',
        cErrorContainer,
        cOnErrorContainer,
        Icons.warning_amber_rounded,
      ),
      _ => _statusApproved(),
    };

    return _cardWrapper(
      children: [
        _rowTop(p.kodeBooking, statusBadge),
        const SizedBox(height: 12),
        _facilityRow(
          _facilityTitle(p),
          'Kegiatan: ${p.namaKegiatan}',
          Icons.verified_user,
          cPrimary,
          image: image,
          icon: Icons.desktop_windows,
        ),
        const SizedBox(height: 12),
        _scheduleBox(
          'Jadwal Penggunaan',
          '${_formatDate(p.mulaiPada)} • ${_formatTime(p.mulaiPada)} - ${_formatTime(p.estimasiKembaliPada)} WIB',
          cPrimary,
          Icons.calendar_today,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () => _showQrModal(p),
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            label: const Text('Tampilkan QR Pass Peminjaman'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cPrimaryContainer,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () => _openDetail(p),
                  icon: const Icon(Icons.info_outline, size: 17),
                  label: const Text('Rincian Fasilitas'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cOnSurface,
                    backgroundColor: cSurfaceLow,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            if (p.status == StatusPeminjaman.disetujui) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: TextButton(
                  onPressed: isCancelling ? null : () => _cancelBooking(p),
                  style: TextButton.styleFrom(
                    backgroundColor: cErrorContainer.withValues(alpha: 0.4),
                    foregroundColor: cError,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: isCancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Batalkan',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ===== CARD MENUNGGU =====
  Widget _cardMenunggu(Peminjaman p) {
    final isCancelling = _cancellingIds.contains(p.id);
    final image = p.items.isNotEmpty ? p.items.first.fotoUrl : null;
    final totalUnit = p.items.fold<int>(0, (s, item) => s + item.jumlah);

    return _cardWrapper(
      children: [
        _rowTop(p.kodeBooking, _statusPending()),
        const SizedBox(height: 12),
        _facilityRow(
          _facilityTitle(p),
          'Jumlah: $totalUnit Unit • ${p.labelKategori}',
          Icons.assignment_ind,
          cSecondary,
          image: image,
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cSurfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 14,
                color: cOnSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Keperluan: ${p.namaKegiatan}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: cOnSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _scheduleBox(
          'Rencana Waktu',
          '${_formatDate(p.mulaiPada)} • ${_formatTime(p.mulaiPada)} - ${_formatTime(p.estimasiKembaliPada)} WIB',
          cSecondary,
          Icons.event,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cSurfaceContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STATUS VERIFIKASI PEMINJAMAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cOnSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              _stepDone(
                'Pengajuan Berhasil Dikirim',
                '${_formatDate(p.diajukanPada)}, ${_formatTime(p.diajukanPada)} WIB',
              ),
              _stepActive(
                'Review & Verifikasi PIC',
                'Sedang diproses oleh Sarpras',
              ),
              _stepInactive(
                'Konfirmasi Kunci & Akses',
                'Menunggu persetujuan petugas',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isCancelling ? null : () => _cancelBooking(p),
                icon: const Icon(Icons.close, size: 18),
                label: Text(isCancelling ? 'Membatalkan...' : 'Batalkan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cError,
                  backgroundColor: cErrorContainer.withValues(alpha: 0.35),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/chat'),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Hubungi PIC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cTertiaryFixed,
                  foregroundColor: const Color(0xFF002113),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== CARD DITOLAK / SELESAI =====
  Widget _cardHistoryOrRejected(Peminjaman p) {
    final image = p.items.isNotEmpty ? p.items.first.fotoUrl : null;
    final isRejected = p.status == StatusPeminjaman.ditolak;
    final statusWidget = switch (p.status) {
      StatusPeminjaman.ditolak => _statusRejected(),
      StatusPeminjaman.dikembalikan => _statusPill(
        'Dikembalikan',
        const Color(0xFFD1FAE5),
        cTertiary,
        Icons.check_circle_outline,
      ),
      _ => _statusPill(
        'Dibatalkan',
        cSurfaceContainer,
        cSecondary,
        Icons.block,
      ),
    };

    return _cardWrapper(
      children: [
        _rowTop(p.kodeBooking, statusWidget),
        const SizedBox(height: 12),
        _facilityRow(
          _facilityTitle(p),
          'Kegiatan: ${p.namaKegiatan}',
          Icons.info_outline,
          isRejected ? cError : cSecondary,
          image: image,
          icon: Icons.photo_camera,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cSurfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 14, color: cOnSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Diajukan: ${_formatDate(p.diajukanPada)}',
                style: const TextStyle(fontSize: 11, color: cOnSurfaceVariant),
              ),
            ],
          ),
        ),
        if (isRejected && p.alasanPenolakan != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cErrorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  color: cError,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catatan Penolakan PIC:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cOnErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '"${p.alasanPenolakan}"',
                        style: const TextStyle(
                          fontSize: 12,
                          color: cOnSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: isRejected
                ? () => context.push('/facilities')
                : () => _openDetail(p),
            icon: Icon(
              isRejected ? Icons.sync_alt : Icons.receipt_long_outlined,
              size: 18,
            ),
            label: Text(
              isRejected
                  ? 'Pilih Fasilitas / Alat Alternatif'
                  : 'Lihat Rincian Peminjaman',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: cSecondaryContainer,
              foregroundColor: cOnSecondaryContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final label = switch (_tab) {
      'aktif' => 'Belum ada peminjaman aktif',
      'menunggu' => 'Tidak ada pengajuan menunggu persetujuan',
      _ => 'Belum ada riwayat peminjaman selesai atau ditolak',
    };
    return _cardWrapper(
      children: [
        const SizedBox(height: 16),
        const Icon(
          Icons.inventory_2_outlined,
          size: 52,
          color: cOutlineVariant,
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: cOnSurface,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ajukan peminjaman barang atau ruangan melalui formulir booking.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cOnSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/borrowing-form'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajukan Peminjaman'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cPrimaryContainer,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildErrorState() => _cardWrapper(
    children: [
      const Icon(Icons.error_outline, color: cError, size: 36),
      const SizedBox(height: 8),
      Text(
        _errorMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: cError, fontSize: 13),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text('Coba lagi'),
      ),
    ],
  );

  Widget _buildHelpBanner() => GestureDetector(
    onTap: () => context.push('/chat'),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cSurfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: cSurfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline, size: 20, color: cPrimary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Butuh Bantuan Peminjaman?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cOnSurface,
                  ),
                ),
                Text(
                  'Hubungi petugas Sarpras atau baca panduan SOP',
                  style: TextStyle(fontSize: 11, color: cOnSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: cOnSurfaceVariant),
        ],
      ),
    ),
  );

  // ---------- helpers ----------
  Widget _cardWrapper({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cSurfaceLowest,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _rowTop(String id, Widget status) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'BOOKING ID',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cOnSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cSurfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '#$id',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cOnSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      status,
    ],
  );

  Widget _statusApproved() => _statusPill(
    'Disetujui',
    const Color(0xFFD1FAE5),
    cTertiary,
    Icons.circle,
    iconSize: 8,
  );

  Widget _statusPending() => _statusPill(
    'Menunggu Review',
    cSecondaryContainer,
    cOnSecondaryContainer,
    Icons.hourglass_top,
  );

  Widget _statusRejected() => _statusPill(
    'Ditolak',
    cErrorContainer,
    cOnErrorContainer,
    Icons.cancel_outlined,
  );

  Widget _statusPill(
    String label,
    Color bg,
    Color fg,
    IconData icon, {
    double iconSize = 12,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: fg),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    ),
  );

  Widget _facilityRow(
    String title,
    String subtitle,
    IconData subIcon,
    Color subColor, {
    required String? image,
    required IconData icon,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 80,
        height: 80,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cSurfaceContainer,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null && image.isNotEmpty)
              Image.network(
                image,
                cacheWidth: 160,
                cacheHeight: 160,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, p) =>
                    p == null ? child : Container(color: cSurfaceContainer),
                errorBuilder: (_, __, ___) => Container(
                  color: cSurfaceContainer,
                  child: Icon(icon, color: cOutlineVariant),
                ),
              )
            else
              Container(
                color: cSurfaceContainer,
                child: Icon(icon, color: cOutlineVariant, size: 32),
              ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cOnSurface,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(subIcon, size: 14, color: subColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: cOnSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _scheduleBox(String label, String value, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cSurfaceLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: cOnSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cOnSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _stepDone(String title, String subtitle) => _stepRow(
    color: cPrimaryContainer,
    icon: Icons.check,
    iconColor: Colors.white,
    title: title,
    titleColor: cOnSurface,
    subtitle: subtitle,
    subtitleColor: cOnSurfaceVariant,
  );

  Widget _stepActive(String title, String subtitle) => _stepRow(
    color: cSecondaryContainer,
    icon: Icons.hourglass_empty,
    iconColor: cOnSecondaryContainer,
    title: title,
    titleColor: cOnSurface,
    subtitle: subtitle,
    subtitleColor: cPrimary,
    bold: true,
  );

  Widget _stepInactive(String title, String subtitle) => _stepRow(
    color: cSurfaceHigh,
    icon: Icons.key,
    iconColor: cOnSurfaceVariant,
    title: title,
    titleColor: cOnSurfaceVariant,
    subtitle: subtitle,
    subtitleColor: cOnSurfaceVariant.withValues(alpha: 0.8),
  );

  Widget _stepRow({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required String subtitle,
    required Color subtitleColor,
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: titleColor,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: subtitleColor),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
