// lib/features/borrowings/screens/my_borrowings_screen.dart
// Daftar peminjaman milik pengguna yang sedang login — skema baru.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/peminjaman.dart';
import '../services/peminjaman_service.dart';
import 'borrowing_detail_screen.dart';

class MyBorrowingsScreen extends StatefulWidget {
  const MyBorrowingsScreen({super.key});

  @override
  State<MyBorrowingsScreen> createState() => _MyBorrowingsScreenState();
}

class _MyBorrowingsScreenState extends State<MyBorrowingsScreen> {
  // ===== Palette =====
  static const _surface             = Color(0xFFFAF8FF);
  static const _onSurface           = Color(0xFF131B2E);
  static const _onSurfaceVariant    = Color(0xFF434655);
  static const _primary             = Color(0xFF0037B0);
  static const _errorColor          = Color(0xFFBA1A1A);
  static const _outline             = Color(0xFFC4C5D7);

  List<Peminjaman> _list = [];
  bool _loading = true;
  String? _errMsg;
  final Set<String> _cancellingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _errMsg = null; });
    try {
      final data = await peminjamanService.ambilPeminjamanSaya();
      if (!mounted) return;
      setState(() { _list = data; _loading = false; });
    } on PeminjamanException catch (e) {
      if (!mounted) return;
      setState(() { _errMsg = e.pesan; _loading = false; });
    }
  }

  Future<void> _confirmCancellation(Peminjaman p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan Peminjaman?'),
        content: Text('Kode: ${p.kodeBooking}\n${p.namaKegiatan}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tidak')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan', style: TextStyle(color: _errorColor)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancellingIds.add(p.id));
    try {
      await peminjamanService.batalkan(p.id);
      await _load();
    } on PeminjamanException catch (e) {
      if (!mounted) return;
      _snack(e.pesan, error: true);
    } finally {
      if (mounted) setState(() => _cancellingIds.remove(p.id));
    }
  }

  void _showQrModal(Peminjaman p) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.kodeBooking),
        content: const Text('QR Pass tersedia setelah peminjaman disetujui.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? _errorColor : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Peminjaman Saya',
          style: TextStyle(color: _onSurface, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _onSurface),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/borrowing-form'),
        icon: const Icon(Icons.add),
        label: const Text('Ajukan Peminjaman'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errMsg != null
              ? _buildError()
              : _list.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _BorrowingCard(
                          p: _list[i],
                          cancellingIds: _cancellingIds,
                          onCancel:   () => _confirmCancellation(_list[i]),
                          onShowQr:   () => _showQrModal(_list[i]),
                          onDetail:   () => _openDetail(_list[i]),
                        ),
                      ),
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

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_errMsg!, style: const TextStyle(color: _errorColor), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba lagi'),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_2_outlined, size: 64, color: _outline),
        const SizedBox(height: 12),
        const Text(
          'Belum ada peminjaman',
          style: TextStyle(color: _onSurfaceVariant, fontSize: 16),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => context.push('/borrowing-form'),
          icon: const Icon(Icons.add),
          label: const Text('Ajukan Sekarang'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Card peminjaman
// ---------------------------------------------------------------------------
class _BorrowingCard extends StatelessWidget {
  const _BorrowingCard({
    required this.p,
    required this.cancellingIds,
    required this.onCancel,
    required this.onShowQr,
    required this.onDetail,
  });

  final Peminjaman p;
  final Set<String> cancellingIds;
  final VoidCallback onCancel;
  final VoidCallback onShowQr;
  final VoidCallback onDetail;

  static const _primary          = Color(0xFF0037B0);
  static const _surfaceLow       = Color(0xFFF2F3FF);
  static const _surfaceLowest    = Color(0xFFFFFFFF);
  static const _onSurface        = Color(0xFF131B2E);
  static const _onSurfaceVariant = Color(0xFF434655);
  static const _error            = Color(0xFFBA1A1A);
  static const _errorContainer   = Color(0xFFFFDAD6);

  Color get _statusColor => switch (p.status) {
    StatusPeminjaman.menungguPersetujuan => const Color(0xFFB45309),
    StatusPeminjaman.disetujui           => const Color(0xFF065F46),
    StatusPeminjaman.dipinjam            => _primary,
    StatusPeminjaman.dikembalikan        => const Color(0xFF065F46),
    StatusPeminjaman.ditolak             => _error,
    StatusPeminjaman.dibatalkan          => const Color(0xFF64748B),
    StatusPeminjaman.terlambat           => _error,
    _                                    => _onSurfaceVariant,
  };

  bool get _isActive => p.status == StatusPeminjaman.disetujui ||
      p.status == StatusPeminjaman.dipinjam;

  bool get _isCancellable =>
      p.status == StatusPeminjaman.menungguPersetujuan ||
      p.status == StatusPeminjaman.disetujui;

  @override
  Widget build(BuildContext context) {
    final namaFasilitas = p.items.isNotEmpty
        ? p.items.first.namaFasilitasSnapshot
        : '—';
    final jumlah = p.items.isNotEmpty ? p.items.first.jumlah : 0;

    return GestureDetector(
      onTap: onDetail,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: kode + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.kodeBooking,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    p.status.label,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Fasilitas
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _surfaceLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2, color: _primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        namaFasilitas,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: _onSurface),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$jumlah unit • ${p.labelKategori}',
                        style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kegiatan: ${p.namaKegiatan}',
                        style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tanggal
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_fmt(p.mulaiPada)} – ${_fmt(p.estimasiKembaliPada)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (p.alasanPenolakan != null && p.alasanPenolakan!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Catatan: ${p.alasanPenolakan}',
                style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
              ),
            ],
            if (_isActive) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onShowQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Tampilkan QR Pass'),
              ),
            ],
            if (_isCancellable) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: TextButton.icon(
                  onPressed: cancellingIds.contains(p.id) ? null : onCancel,
                  icon: cancellingIds.contains(p.id)
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: const Text('Batalkan Pengajuan'),
                  style: TextButton.styleFrom(
                    backgroundColor: _errorContainer.withValues(alpha: 0.4),
                    foregroundColor: _error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${dt.day} ${months[dt.month - 1]}, '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}
