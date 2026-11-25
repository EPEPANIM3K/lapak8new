import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/lapak8_api_client.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/lapak_header.dart';
import '../../dashboard/widgets/qr_ticket_modal.dart';
import '../models/borrowing.dart';
import '../services/borrowing_service.dart';

class MyBorrowingsScreen extends StatefulWidget {
  const MyBorrowingsScreen({super.key});

  @override
  State<MyBorrowingsScreen> createState() => _MyBorrowingsScreenState();
}

class _MyBorrowingsScreenState extends State<MyBorrowingsScreen> {
  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCM9TBr73lAvJae_M-j8bVPXa69t9E8fJjw6s1fOkJB9Rwn5SdnSrc2vwOfl_FwiSc0PAsKLZ3OrWbOxQRw_0Nv8TltDOZ-YW8v68X2WTQJl29s3nRn2_K2GuSWHAvMZpMCZJe6iBeZDp5yEl_7IcjmKNNuCgejx9XkiISbISzKzJKsN4oi8-ZVu-ddev07E4AA7eAz81C-Lou8NTkx4lFKRMgys8zcncLJEU3cjaxS9X4CrRZuET7Y';

  static const _surface = Color(0xFFFAF8FF);
  static const _surfaceLowest = Color(0xFFFFFFFF);
  static const _surfaceLow = Color(0xFFF2F3FF);
  static const _onSurface = Color(0xFF131B2E);
  static const _onSurfaceVariant = Color(0xFF434655);
  static const _primary = Color(0xFF0037B0);
  static const _tertiary = Color(0xFF004F35);
  static const _error = Color(0xFFBA1A1A);
  static const _errorContainer = Color(0xFFFFDAD6);
  static const _amber = Color(0xFFB45309);

  final BorrowingService _service = BorrowingService();
  final Set<String> _cancellingIds = {};
  List<Borrowing> _borrowings = [];
  String _tab = 'aktif';
  String? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBorrowings();
  }

  Future<void> _loadBorrowings() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final borrowings = await _service.fetchBorrowings();
      if (!mounted) return;
      setState(() {
        _borrowings = borrowings;
        _isLoading = false;
      });
    } on Lapak8ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _isLoading = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelBorrowing(Borrowing borrowing) async {
    setState(() => _cancellingIds.add(borrowing.id));
    try {
      await _service.cancel(borrowing.id);
      await _loadBorrowings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan peminjaman dibatalkan.')),
      );
    } on Lapak8ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _cancellingIds.remove(borrowing.id));
    }
  }

  void _confirmCancellation(Borrowing borrowing) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Icons.event_busy,
        title: 'Batalkan Pengajuan?',
        message: 'Pengajuan ${borrowing.code} akan dibatalkan.',
        cancelText: 'Tidak',
        confirmText: 'Ya, Batalkan',
        confirmIcon: Icons.cancel_outlined,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        onConfirm: () => _cancelBorrowing(borrowing),
      ),
    );
  }

  void _showQrModal() {
    showDialog<void>(context: context, builder: (_) => const QrTicketModal());
  }

  int _countWhere(bool Function(Borrowing) predicate) =>
      _borrowings.where(predicate).length;

  List<Borrowing> get _selectedBorrowings {
    return _borrowings.where((borrowing) {
      switch (_tab) {
        case 'aktif':
          return borrowing.status == 'approved' ||
              borrowing.status == 'borrowed';
        case 'menunggu':
          return borrowing.status == 'pending';
        default:
          return ![
            'approved',
            'borrowed',
            'pending',
          ].contains(borrowing.status);
      }
    }).toList();
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu persetujuan';
      case 'approved':
        return 'Disetujui';
      case 'borrowed':
        return 'Sedang dipinjam';
      case 'returned':
        return 'Dikembalikan';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return _amber;
      case 'approved':
      case 'borrowed':
      case 'returned':
        return _tertiary;
      default:
        return _error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          LapakHeader(
            avatarUrl: _avatarUrl,
            onAvatarTap: () => context.push('/profile'),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBorrowings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _tabButton(
                            'aktif',
                            'Peminjaman Aktif',
                            _countWhere(
                              (item) =>
                                  item.status == 'approved' ||
                                  item.status == 'borrowed',
                            ),
                          ),
                          const SizedBox(width: 8),
                          _tabButton(
                            'menunggu',
                            'Menunggu Persetujuan',
                            _countWhere((item) => item.status == 'pending'),
                          ),
                          const SizedBox(width: 8),
                          _tabButton(
                            'riwayat',
                            'Selesai & Riwayat',
                            _countWhere(
                              (item) => ![
                                'approved',
                                'borrowed',
                                'pending',
                              ].contains(item.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _tabContent(),
                  ),
                ],
              ),
            ),
          ),
          AppBottomNav(
            items: AppBottomNav.userItems,
            currentIndex: 2,
            onTap: (_) {},
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String key, String label, int count) {
    final selected = _tab == key;
    return GestureDetector(
      onTap: () => setState(() => _tab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primary : _surfaceLowest,
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
                color: selected ? Colors.white : _onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _surface : const Color(0xFFE2E7FF),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? _primary : _onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadBorrowings,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    final borrowings = _selectedBorrowings;
    if (borrowings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text('Belum ada data peminjaman pada kategori ini.'),
        ),
      );
    }
    return Column(
      children: [
        for (final borrowing in borrowings) ...[
          _borrowingCard(borrowing),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _borrowingCard(Borrowing borrowing) {
    final statusColor = _statusColor(borrowing.status);
    final isCancellable = borrowing.status == 'pending';
    final isActive =
        borrowing.status == 'approved' || borrowing.status == 'borrowed';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLowest,
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
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  borrowing.code,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(borrowing.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
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
                      borrowing.facilityName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${borrowing.location} • ${borrowing.quantity} unit',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kegiatan: ${borrowing.eventName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    '${_formatDateTime(borrowing.startAt)} - '
                    '${_formatDateTime(borrowing.endAt)}',
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
          if (borrowing.decisionNote != null &&
              borrowing.decisionNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Catatan: ${borrowing.decisionNote}',
              style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
          ],
          if (isActive) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showQrModal,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Tampilkan QR Pass Peminjaman'),
            ),
          ],
          if (isCancellable) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: TextButton.icon(
                onPressed: _cancellingIds.contains(borrowing.id)
                    ? null
                    : () => _confirmCancellation(borrowing),
                icon: _cancellingIds.contains(borrowing.id)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
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
    );
  }
}
