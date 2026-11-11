import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';
import 'package:lapak8new/features/admin/services/media_picker_service.dart';
import 'package:lapak8new/features/admin/widgets/documentation_section.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';
import 'package:lapak8new/shared/widgets/ms_icon.dart';

// Simpan di: lib/features/admin/screens/admin_borrowings_screen.dart
// Halaman Aktivitas admin: Peminjaman + Pengembalian (satu screen, dua tab).

// ---------------------------------------------------------------------------
// Jenis aktivitas + status
// ---------------------------------------------------------------------------
enum ActivityTab { peminjaman, pengembalian }

enum _LoanStatus { waiting, borrowed, approved, late, done }

enum _ReturnStatus { pending, returned, late, damaged, rejected }

// Warna status yang belum ada di AppColors (amber untuk "menunggu").
const _amberBg = Color(0xFFFFF1D6);
const _amberFg = Color(0xFFB45309);

class _Loan {
  const _Loan({
    required this.code,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.itemName,
    required this.serial,
    required this.itemIcon,
    required this.detailIcon,
    required this.detail,
    this.isTeacher = false,
    this.extra,
    this.extraColor,
    this.highlight,
    this.highlightColor,
    this.trailingDetail,
    this.note,
    this.avatarUrl,
  });

  final String code;
  final String name;
  final String subtitle;
  final _LoanStatus status;
  final String itemName;
  final String serial;
  final IconData itemIcon;
  final IconData detailIcon;
  final String detail; // teks biasa
  final bool isTeacher;
  final String? extra; // baris di bawah nama (rekam pinjam / sisa waktu)
  final Color? extraColor;
  final String? highlight; // potongan teks berwarna di akhir detail
  final Color? highlightColor;
  final String? trailingDetail; // mis. tanggal di kanan
  final String? note;
  final String? avatarUrl; // isi bila sudah ada foto profil

  String get initials {
    final parts = name.replaceAll('Drs. ', '').trim().split(' ');
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }
}

class _Return {
  const _Return({
    required this.code,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.itemName,
    required this.serial,
    required this.itemIcon,
    required this.detailIcon,
    required this.detail,
    this.isTeacher = false,
    this.highlight,
    this.highlightColor,
    this.trailingDetail,
    this.note,
    this.avatarUrl,
    this.checkResult,
  });

  final String code;
  final String name;
  final String subtitle;
  final _ReturnStatus status;
  final String itemName;
  final String serial;
  final IconData itemIcon;
  final IconData detailIcon;
  final String detail;
  final bool isTeacher;
  final String? highlight;
  final Color? highlightColor;
  final String? trailingDetail;
  final String? note;
  final String? avatarUrl;

  /// Hasil verifikasi Cek Kondisi (diisi saat petugas selesai memeriksa).
  final InspectionResult? checkResult;

  String get initials {
    final parts = name.replaceAll('Drs. ', '').trim().split(' ');
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }
}

/// Hasil pemeriksaan kondisi barang dari form Cek Kondisi.
class InspectionResult {
  const InspectionResult({
    required this.isApproved,
    required this.positiveChecks,
    required this.negativeChecks,
    required this.description,
    required this.fine,
    required this.checkedAt,
    this.documentationPhotos = const [],
    this.documentationVideo,
  });

  final bool isApproved;
  final List<String> positiveChecks;
  final List<String> negativeChecks;
  final String description;
  final String fine;
  final String checkedAt;

  /// Dokumentasi kondisi barang yang dipilih saat pemeriksaan.
  /// (State frontend sementara; integrasi unggah menyusul.)
  final List<PendingDocumentationFile> documentationPhotos;
  final PendingDocumentationFile? documentationVideo;
}

class AdminBorrowingsScreen extends StatefulWidget {
  const AdminBorrowingsScreen({
    super.key,
    this.initialTab = ActivityTab.peminjaman,
  });

  /// Tab yang terbuka saat halaman pertama kali tampil.
  /// Default: Peminjaman (sesuai menu "Aktivitas").
  final ActivityTab initialTab;

  @override
  State<AdminBorrowingsScreen> createState() => _AdminBorrowingsScreenState();
}

class _AdminBorrowingsScreenState extends State<AdminBorrowingsScreen> {
  late ActivityTab _tab = widget.initialTab; // default: Peminjaman
  _LoanStatus? _loanFilter; // null = semua
  _ReturnStatus? _returnFilter; // null = semua
  String _query = '';

  // TODO: ganti dengan data dari backend.
  static const List<_Loan> _loans = [
    _Loan(
      code: 'BK-2024-089',
      name: 'Arya Putra Pratama',
      subtitle: 'XII RPL 1 • NIS: 202208112',
      extra: 'Rekam Pinjam: Baik (0 Pelanggaran)',
      extraColor: AppColors.primary,
      status: _LoanStatus.waiting,
      itemName: 'Huion Kamvas 16 Pro',
      serial: 'SN: HU-K16-004',
      itemIcon: Symbols.draw,
      detailIcon: Symbols.schedule,
      detail: '24 Okt 2024 • 08:00 - 15:00 WIB',
      note: '"Praktik Pembuatan Game 2D - UKK Jurusan"',
    ),
    _Loan(
      code: 'BK-2024-088',
      name: 'Siti Nurhaliza',
      subtitle: 'XI MM 2 • NIS: 202307045',
      extra: 'Sisa Waktu: 2 Jam 45 Menit',
      extraColor: AppColors.primary,
      status: _LoanStatus.borrowed,
      itemName: 'Sony Alpha A7 IV Kit',
      serial: 'SNY-A74-002',
      itemIcon: Symbols.photo_camera,
      detailIcon: Symbols.history,
      detail: 'Batas Pengembalian: ',
      highlight: 'Hari ini, 16:30 WIB',
      highlightColor: AppColors.error,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCM9TBr73lAvJae_M-j8bVPXa69t9E8fJjw6s1fOkJB9Rwn5SdnSrc2vwOfl_FwiSc0PAsKLZ3OrWbOxQRw_0Nv8TltDOZ-YW8v68X2WTQJl29s3nRn2_K2GuSWHAvMZpMCZJe6iBeZDp5yEl_7IcjmKNNuCgejx9XkiISbISzKzJKsN4oi8-ZVu-ddev07E4AA7eAz81C-Lou8NTkx8lFKRMgys8zcncLJEU3cjaxS9X4CrRZuET7Y',
    ),
    _Loan(
      code: 'BK-2024-087',
      name: 'Drs. Agus Hidayat',
      isTeacher: true,
      subtitle: 'Guru Produktif TKJ • NIP: 19780512...',
      status: _LoanStatus.approved,
      itemName: 'MikroTik Cloud Core CCR',
      serial: 'MTK-CCR-1009',
      itemIcon: Symbols.router,
      detailIcon: Symbols.calendar_month,
      detail: 'Jadwal: 24 Okt 2024, 07:15 - 11:45 WIB',
    ),
    _Loan(
      code: 'BK-2024-085',
      name: 'Praboro Subranto',
      subtitle: 'XI MM 2 • NIS: 202307200',
      extra: 'Sisa Waktu: 0 Jam 0 Menit',
      extraColor: AppColors.error,
      status: _LoanStatus.late,
      itemName: 'Sony Alpha A7 IV Kit',
      serial: 'SNY-A74-002',
      itemIcon: Symbols.photo_camera,
      detailIcon: Symbols.history,
      detail: 'Batas Pengembalian: ',
      highlight: 'Hari ini, 16:30 WIB',
      highlightColor: AppColors.error,
    ),
    _Loan(
      code: 'BK-2024-086',
      name: 'Annisa Rahma',
      subtitle: 'XII DKV 1 • NIS: 202208034',
      status: _LoanStatus.done,
      itemName: 'Rode PodMic Set Dual',
      serial: 'ROD-PM-019',
      itemIcon: Symbols.mic,
      detailIcon: Symbols.check_circle,
      detail: 'Kondisi: Lengkap & Bersih',
      trailingDetail: '23 Okt 2024',
    ),
  ];

  final List<_Return> _returns = [
    _Return(
      code: 'KM-2024-031',
      name: 'Siti Nurhaliza',
      subtitle: 'XI MM 2 • NIS: 202307045',
      status: _ReturnStatus.pending,
      itemName: 'Sony Alpha A7 IV Kit',
      serial: 'SNY-A74-002',
      itemIcon: Symbols.photo_camera,
      detailIcon: Symbols.schedule,
      detail: 'Pengajuan: 24 Okt 2024, 16:45 WIB',
      note: 'Kondisi dilaporkan: Lengkap & Bersih',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCM9TBr73lAvJae_M-j8bVPXa69t9E8fJjw6s1fOkJB9Rwn5SdnSrc2vwOfl_FwiSc0PAsKLZ3OrWbOxQRw_0Nv8TltDOZ-YW8v68X2WTQJl29s3nRn2_K2GuSWHAvMZpMCZJe6iBeZDp5yEl_7IcjmKNNuCgejx9XkiISbISzKzJKsN4oi8-ZVu-ddev07E4AA7eAz81C-Lou8NTkx8lFKRMgys8zcncLJEU3cjaxS9X4CrRZuET7Y',
    ),
    _Return(
      code: 'KM-2024-030',
      name: 'Drs. Agus Hidayat',
      isTeacher: true,
      subtitle: 'Guru Produktif TKJ • NIP: 19780512...',
      status: _ReturnStatus.returned,
      itemName: 'MikroTik Cloud Core CCR',
      serial: 'MTK-CCR-1009',
      itemIcon: Symbols.router,
      detailIcon: Symbols.check_circle,
      detail: 'Dikembalikan: ',
      highlight: '24 Okt 2024, 11:50 WIB',
      highlightColor: AppColors.emerald500,
      trailingDetail: '24 Okt 2024',
    ),
    _Return(
      code: 'KM-2024-029',
      name: 'Praboro Subranto',
      subtitle: 'XI MM 2 • NIS: 202307200',
      status: _ReturnStatus.late,
      itemName: 'Sony Alpha A7 IV Kit',
      serial: 'SNY-A74-002',
      itemIcon: Symbols.photo_camera,
      detailIcon: Symbols.history,
      detail: 'Batas: ',
      highlight: '24 Okt 2024, 16:30 WIB',
      highlightColor: AppColors.error,
      note: '"Terlambat 2 jam 15 menit"',
    ),
    _Return(
      code: 'KM-2024-028',
      name: 'Annisa Rahma',
      subtitle: 'XII DKV 1 • NIS: 202208034',
      status: _ReturnStatus.damaged,
      itemName: 'Rode PodMic Set Dual',
      serial: 'ROD-PM-019',
      itemIcon: Symbols.mic,
      detailIcon: Symbols.build,
      detail: 'Diterima: 23 Okt 2024, 15:20 WIB',
      note: 'Kabel XLR putus, shock mount longgar',
    ),
  ];

// Filter status per jenis aktivitas (tidak tercampur antar tab).
  static const _loanFilters = <(String, _LoanStatus?)>[
    ('Semua', null),
    ('Menunggu', _LoanStatus.waiting),
    ('Dipinjam', _LoanStatus.borrowed),
    ('Disetujui', _LoanStatus.approved),
    ('Terlambat', _LoanStatus.late),
    ('Selesai', _LoanStatus.done),
  ];

  static const _returnFilters = <(String, _ReturnStatus?)>[
    ('Semua', null),
    ('Menunggu', _ReturnStatus.pending),
    ('Diverifikasi', _ReturnStatus.returned),
    ('Terlambat', _ReturnStatus.late),
    ('Rusak', _ReturnStatus.damaged),
    ('Ditolak', _ReturnStatus.rejected),
  ];

  bool get _isLoanTab => _tab == ActivityTab.peminjaman;

  List<_Loan> get _visibleLoans {
    final q = _query.trim().toLowerCase();
    return _loans.where((l) {
      if (_loanFilter != null && l.status != _loanFilter) return false;
      if (q.isEmpty) return true;
      return l.name.toLowerCase().contains(q) ||
          l.code.toLowerCase().contains(q) ||
          l.itemName.toLowerCase().contains(q) ||
          l.serial.toLowerCase().contains(q);
    }).toList();
  }

  List<_Return> get _visibleReturns {
    final q = _query.trim().toLowerCase();
    return _returns.where((r) {
      if (_returnFilter != null && r.status != _returnFilter) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          r.code.toLowerCase().contains(q) ||
          r.itemName.toLowerCase().contains(q) ||
          r.serial.toLowerCase().contains(q);
    }).toList();
  }

  int get _activeTotal => _isLoanTab ? _loans.length : _returns.length;

  // -------------------------------------------------------------------------
  // Aksi peminjaman (dengan popup konfirmasi gaya ConfirmDialog)
  // -------------------------------------------------------------------------
  void _confirmApprove(_Loan l) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.check,
        title: 'Setujui Peminjaman?',
        message: 'Pastikan data peminjaman "${l.itemName}" (${l.serial}) '
            'atas nama ${l.name} sudah benar sebelum disetujui.',
        confirmText: 'Ya, Setujui',
        confirmIcon: Symbols.check,
        confirmColor: AppColors.primary,
        iconColor: AppColors.primary,
        iconBackground: AppColors.primaryFixed,
        onConfirm: () {
          if (!mounted) return;
          // TODO: kirim aksi setujui ke backend, lalu refresh daftar.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Peminjaman disetujui')),
          );
        },
      ),
    );
  }

  void _confirmReject(_Loan l) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.close,
        title: 'Tolak Peminjaman?',
        message: 'Pengajuan "${l.itemName}" (${l.serial}) atas nama '
            '${l.name} akan ditolak.',
        confirmText: 'Ya, Tolak',
        confirmIcon: Symbols.close,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        onConfirm: () {
          if (!mounted) return;
          // TODO: kirim aksi tolak ke backend, lalu refresh daftar.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Peminjaman ditolak')),
          );
        },
      ),
    );
  }

  void _confirmSuspend(_Loan l) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.lock,
        title: 'Suspend Akun?',
        message: 'Akun ${l.name} akan disuspend karena keterlambatan '
            'pengembalian "${l.itemName}".',
        confirmText: 'Ya, Suspend',
        confirmIcon: Symbols.lock,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        onConfirm: () {
          if (!mounted) return;
          // TODO: kirim aksi suspend ke backend, lalu refresh daftar.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Akun di-suspend')),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Aksi pengembalian — alur verifikasi "Cek Kondisi"
  // -------------------------------------------------------------------------
  Future<void> _openInspection(_Return r) async {
    final result = await showModalBottomSheet<InspectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _ConditionInspectionSheet(item: r),
    );
    if (result == null || !mounted) return;

    setState(() {
      final idx = _returns.indexWhere((x) => x.code == r.code);
      if (idx == -1) return;
      _returns[idx] = _Return(
        code: r.code,
        name: r.name,
        subtitle: r.subtitle,
        status: result.isApproved
            ? _ReturnStatus.returned
            : _ReturnStatus.rejected,
        itemName: r.itemName,
        serial: r.serial,
        itemIcon: r.itemIcon,
        detailIcon: result.isApproved ? Symbols.check_circle : Symbols.close,
        detail: result.isApproved
            ? 'Diverifikasi: '
            : 'Pengembalian ditolak • ',
        highlight: result.checkedAt,
        highlightColor:
            result.isApproved ? AppColors.emerald500 : AppColors.error,
        isTeacher: r.isTeacher,
        note: result.negativeChecks.isEmpty
            ? 'Kondisi barang: lengkap, baik & berfungsi normal.'
            : 'Temuan: ${result.negativeChecks.join(', ')}.',
        avatarUrl: r.avatarUrl,
        checkResult: result,
      );
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            result.isApproved
                ? 'Pengembalian ${r.code} berhasil diverifikasi'
                : 'Pengembalian ${r.code} ditolak karena kondisi barang',
          ),
        ),
      );
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final loans = _visibleLoans;
    final returns = _visibleReturns;
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.mobileGutter,
          AppSpacing.md,
          AppSpacing.mobileGutter,
          AppSpacing.md,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aktivitas',
                    style: AppTextStyles.headlineMd(color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(
                  'Kelola aktivitas peminjaman dan pengembalian barang sekolah.',
                  style: AppTextStyles.bodyMd(color: AppColors.slate600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SyncRow(),
          const SizedBox(height: 16),
          _buildTabSwitcher(),
          const SizedBox(height: 16),
          _SearchField(
            hintText: _isLoanTab
                ? 'Cari peminjam, item, atau no. aset...'
                : 'Cari pengembalian, item, atau no. aset...',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          _isLoanTab
              ? _buildLoanFilterChips()
              : _buildReturnFilterChips(),
          const SizedBox(height: 16),
          if (_isLoanTab && loans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Tidak ada data peminjaman',
                  style: AppTextStyles.bodyMd(color: AppColors.slate500),
                ),
              ),
            ),
          if (!_isLoanTab && returns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Tidak ada data pengembalian',
                  style: AppTextStyles.bodyMd(color: AppColors.slate500),
                ),
              ),
            ),
          if (_isLoanTab)
            for (final l in loans) ...[
              _LoanCard(
                loan: l,
                onReject: () => _confirmReject(l),
                onApprove: () => _confirmApprove(l),
                onSuspend: () => _confirmSuspend(l),
              ),
              const SizedBox(height: 16),
            ],
          if (!_isLoanTab)
            for (final r in returns) ...[
              _ReturnCard(
                item: r,
                onCheck: () => _openInspection(r),
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.mobileGutter,
          AppSpacing.md,
          AppSpacing.mobileGutter,
          AppSpacing.md,
        ),
        child: _SummaryBar(
          total: _activeTotal,
          onExport: () {
            // TODO: export rekap ke XLS (sesuai tab aktif).
          },
        ),
      ),
    );
  }

  // Tab Peminjaman / Pengembalian
  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          _tabButton(
            ActivityTab.peminjaman,
            'Peminjaman',
            Symbols.event_available,
          ),
          _tabButton(
            ActivityTab.pengembalian,
            'Pengembalian',
            Symbols.assignment_return,
          ),
        ],
      ),
    );
  }

  Widget _tabButton(ActivityTab tab, String label, IconData icon) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MsIcon(icon, size: 18, color: selected ? AppColors.onPrimary : AppColors.slate600),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelMd(
                  weight: FontWeight.w700,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoanFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _loanFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, status) = _loanFilters[i];
          return _filterChip(
            label: label,
            count: _loanCount(status),
            selected: _loanFilter == status,
            onTap: () => setState(() => _loanFilter = status),
          );
        },
      ),
    );
  }

  Widget _buildReturnFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _returnFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, status) = _returnFilters[i];
          return _filterChip(
            label: label,
            count: _returnCount(status),
            selected: _returnFilter == status,
            onTap: () => setState(() => _returnFilter = status),
          );
        },
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: selected ? null : AppShadows.sm,
        ),
        child: Text(
          '$label ($count)',
          style: AppTextStyles.labelMd(
            weight: FontWeight.w700,
            color: selected ? AppColors.onPrimary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  int _loanCount(_LoanStatus? s) =>
      s == null ? _loans.length : _loans.where((l) => l.status == s).length;

  int _returnCount(_ReturnStatus? s) => s == null
      ? _returns.length
      : _returns.where((r) => r.status == s).length;
}

// ---------------------------------------------------------------------------
// Baris "Sync Sarpras Live"
// ---------------------------------------------------------------------------
class _SyncRow extends StatelessWidget {
  const _SyncRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Sync Sarpras Live',
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Terakhir diperbarui: 09:41 WIB',
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMd(
                weight: FontWeight.w500,
                color: AppColors.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kolom pencarian
// ---------------------------------------------------------------------------
class _SearchField extends StatelessWidget {
  const _SearchField({required this.hintText, required this.onChanged});
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadows.sm,
      ),
      child: TextField(
        onChanged: onChanged,
        style: AppTextStyles.bodyMd(color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
          prefixIcon: const Icon(Symbols.search, color: AppColors.slate600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip status peminjaman
// ---------------------------------------------------------------------------
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _LoanStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    IconData? icon;
    switch (status) {
      case _LoanStatus.waiting:
        label = 'Menunggu Konfirmasi';
        bg = _amberBg;
        fg = _amberFg;
      case _LoanStatus.borrowed:
        label = 'Sedang Dipinjam';
        bg = AppColors.primaryFixed;
        fg = AppColors.primary;
      case _LoanStatus.approved:
        label = 'Disetujui (Ready)';
        bg = AppColors.tertiaryFixed;
        fg = AppColors.onTertiaryFixedVariant;
      case _LoanStatus.late:
        label = 'Terlambat';
        bg = AppColors.errorContainer;
        fg = AppColors.error;
      case _LoanStatus.done:
        label = 'Selesai (Tepat Waktu)';
        bg = AppColors.surfaceContainerLow;
        fg = AppColors.slate600;
        icon = Symbols.check_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: fg)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSm(weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip status pengembalian
// ---------------------------------------------------------------------------
class _ReturnStatusChip extends StatelessWidget {
  const _ReturnStatusChip({required this.status});
  final _ReturnStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    IconData? icon;
    switch (status) {
      case _ReturnStatus.pending:
        label = 'Menunggu Verifikasi';
        bg = _amberBg;
        fg = _amberFg;
      case _ReturnStatus.returned:
        label = 'Dikembalikan';
        bg = AppColors.tertiaryFixed;
        fg = AppColors.onTertiaryFixedVariant;
        icon = Symbols.check_circle;
      case _ReturnStatus.late:
        label = 'Terlambat';
        bg = AppColors.errorContainer;
        fg = AppColors.error;
      case _ReturnStatus.damaged:
        label = 'Rusak';
        bg = AppColors.errorContainer;
        fg = AppColors.error;
        icon = Symbols.warning;
      case _ReturnStatus.rejected:
        label = 'Ditolak';
        bg = AppColors.errorContainer;
        fg = AppColors.error;
        icon = Symbols.close;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: fg)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSm(weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu peminjaman
// ---------------------------------------------------------------------------
class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.onReject,
    required this.onApprove,
    required this.onSuspend,
  });

  final _Loan loan;
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kode + status
          Row(
            children: [
              Text('#',
                  style: AppTextStyles.headlineSm(color: AppColors.primary)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  loan.code.startsWith('BK') ? loan.code : '#${loan.code}',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(status: loan.status),
            ],
          ),
          const SizedBox(height: 14),
          _buildPerson(),
          const SizedBox(height: 14),
          _buildItemBox(),
          if (loan.status == _LoanStatus.waiting) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Tolak',
                    icon: Symbols.close,
                    background: AppColors.errorContainer,
                    foreground: AppColors.error,
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Setujui',
                    icon: Symbols.check,
                    background: AppColors.primary,
                    foreground: AppColors.onPrimary,
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ],
          if (loan.status == _LoanStatus.late) ...[
            const SizedBox(height: 16),
            _ActionButton(
              label: 'Suspend Akun',
              icon: Symbols.lock,
              background: AppColors.errorContainer,
              foreground: AppColors.error,
              onPressed: onSuspend,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerson() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            shape: BoxShape.circle,
            image: loan.avatarUrl == null
                ? null
                : DecorationImage(
                    image: NetworkImage(loan.avatarUrl!),
                    fit: BoxFit.cover,
                  ),
          ),
          child: loan.avatarUrl == null
              ? Text(
                  loan.initials,
                  style: AppTextStyles.headlineSm(color: AppColors.primary)
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      loan.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineSm(
                              color: AppColors.onSurface)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (loan.isTeacher) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Guru',
                        style: AppTextStyles.labelSm(
                          weight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                loan.subtitle,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm(
                  weight: FontWeight.w500,
                  color: AppColors.slate600,
                ),
              ),
              if (loan.extra != null) ...[
                const SizedBox(height: 2),
                Text(
                  loan.extra!,
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w700,
                    color: loan.extraColor ?? AppColors.slate600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loan.status == _LoanStatus.approved) ...[
                Icon(loan.itemIcon, size: 22, color: AppColors.primary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  loan.itemName,
                  style: AppTextStyles.bodyMd(
                    weight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.fade(0.6),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  loan.serial,
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w700,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(loan.detailIcon,
                  size: 16,
                  color: loan.status == _LoanStatus.done
                      ? AppColors.emerald500
                      : AppColors.slate600),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: loan.detail,
                    children: [
                      if (loan.highlight != null)
                        TextSpan(
                          text: loan.highlight,
                          style: TextStyle(
                            color: loan.highlightColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: AppColors.slate600,
                  ),
                ),
              ),
              if (loan.trailingDetail != null)
                Text(
                  loan.trailingDetail!,
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
            ],
          ),
          if (loan.note != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.fact_check,
                    size: 16, color: AppColors.slate600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loan.note!,
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w500,
                      color: AppColors.slate600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu pengembalian (komponen & struktur konsisten dengan kartu peminjaman)
// ---------------------------------------------------------------------------
class _ReturnCard extends StatelessWidget {
  const _ReturnCard({
    required this.item,
    required this.onCheck,
  });

  final _Return item;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kode + status
          Row(
            children: [
              Text('#',
                  style: AppTextStyles.headlineSm(color: AppColors.primary)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.code.startsWith('KM') ? item.code : '#${item.code}',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _ReturnStatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 14),
          _buildPerson(),
          const SizedBox(height: 14),
          _buildItemBox(),
          if (item.status == _ReturnStatus.pending) ...[
            const SizedBox(height: 16),
            _ActionButton(
              label: 'Cek Kondisi',
              icon: Symbols.checklist,
              background: AppColors.primary,
              foreground: AppColors.onPrimary,
              onPressed: onCheck,
            ),
          ] else ...[
            const SizedBox(height: 16),
            _InspectionResultStrip(item: item),
          ],
        ],
      ),
    );
  }

  Widget _buildPerson() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            shape: BoxShape.circle,
            image: item.avatarUrl == null
                ? null
                : DecorationImage(
                    image: NetworkImage(item.avatarUrl!),
                    fit: BoxFit.cover,
                  ),
          ),
          child: item.avatarUrl == null
              ? Text(
                  item.initials,
                  style: AppTextStyles.headlineSm(color: AppColors.primary)
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineSm(
                              color: AppColors.onSurface)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (item.isTeacher) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Guru',
                        style: AppTextStyles.labelSm(
                          weight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm(
                  weight: FontWeight.w500,
                  color: AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.itemIcon, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.itemName,
                  style: AppTextStyles.bodyMd(
                    weight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.fade(0.6),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  item.serial,
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w700,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(item.detailIcon,
                  size: 16,
                  color: item.status == _ReturnStatus.returned
                      ? AppColors.emerald500
                      : AppColors.slate600),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: item.detail,
                    children: [
                      if (item.highlight != null)
                        TextSpan(
                          text: item.highlight,
                          style: TextStyle(
                            color: item.highlightColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: AppColors.slate600,
                  ),
                ),
              ),
              if (item.trailingDetail != null)
                Text(
                  item.trailingDetail!,
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
            ],
          ),
          if (item.note != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.fact_check,
                    size: 16, color: AppColors.slate600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.note!,
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w500,
                      color: AppColors.slate600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strip ringkas hasil verifikasi pada kartu pengembalian (setelah dicek)
// ---------------------------------------------------------------------------
class _InspectionResultStrip extends StatelessWidget {
  const _InspectionResultStrip({required this.item});
  final _Return item;

  @override
  Widget build(BuildContext context) {
    final ok = item.status == _ReturnStatus.returned;
    final bg = ok ? AppColors.tertiaryFixed : AppColors.errorContainer;
    final fg = ok ? AppColors.onTertiaryFixedVariant : AppColors.error;
    final icon = ok ? Symbols.check_circle : Symbols.close;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MsIcon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Verifikasi berhasil' : 'Pengembalian ditolak',
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.checkResult?.negativeChecks.isEmpty ?? true
                      ? 'Barang lengkap, baik, dan berfungsi normal.'
                      : 'Temuan: ${item.checkResult?.negativeChecks.join(', ')}.',
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (item.checkResult != null &&
                    (item.checkResult!.fine.isNotEmpty ||
                        item.checkResult!.description.isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (item.checkResult!.fine.isNotEmpty)
                        'Denda: ${item.checkResult!.fine}',
                      if (item.checkResult!.description.isNotEmpty)
                        item.checkResult!.description,
                    ].join(' • '),
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet: Form Pemeriksaan Kondisi Barang (Cek Kondisi)
// ---------------------------------------------------------------------------
class _ConditionInspectionSheet extends StatefulWidget {
  const _ConditionInspectionSheet({required this.item});
  final _Return item;

  @override
  State<_ConditionInspectionSheet> createState() =>
      _ConditionInspectionSheetState();
}

class _ConditionInspectionSheetState extends State<_ConditionInspectionSheet> {
  // Checklist positif (bisa dicentang sendiri-sendiri).
  static const _positiveOptions = [
    'Barang lengkap sesuai peminjaman',
    'Kondisi fisik barang baik dan tidak rusak',
    'Barang bersih dan berfungsi normal',
  ];

  // Checklist negatif (independen dari positif, boleh campur).
  static const _negativeOptions = [
    'Barang rusak',
    'Barang cacat atau terdapat kerusakan fisik',
    'Komponen atau aksesori hilang',
    'Barang tidak berfungsi',
    'Lainnya',
  ];

  final Set<int> _positive = {};
  final Set<int> _negative = {};
  final _descCtrl = TextEditingController();
  final _fineCtrl = TextEditingController();
  bool _submitting = false;

  // Menandai apakah field validasi pernah gagal (untuk pesan error).
  bool _touched = false;

  // Dokumentasi kondisi barang (state frontend sementara, belum ada backend).
  final MediaPickerService _docPicker = MediaPickerService();
  List<PendingDocumentationFile> _docPhotos = [];
  PendingDocumentationFile? _docVideo;

  bool get _hasNegative => _negative.isNotEmpty;

  @override
  void dispose() {
    _descCtrl.dispose();
    _fineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNegative = _hasNegative;
    final canSubmit = _positive.isNotEmpty &&
        (!hasNegative || _fineCtrl.text.trim().isNotEmpty);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    'Kondisi Barang',
                    'Centang kondisi yang sesuai hasil pemeriksaan.',
                  ),
                  const SizedBox(height: 12),
                  _buildChecklist(
                    options: _positiveOptions,
                    selected: _positive,
                    positive: true,
                    onToggle: _togglePositive,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    'Temuan Kerusakan',
                    'Centang bila ditemukan masalah. Dapat dipilih '
                    'bersamaan dengan kondisi normal di atas.',
                  ),
                  const SizedBox(height: 12),
                  _buildChecklist(
                    options: _negativeOptions,
                    selected: _negative,
                    positive: false,
                    onToggle: _toggleNegative,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Deskripsi Kondisi Barang',
                      'Keterangan tambahan (opsional).'),
                  const SizedBox(height: 12),
                  _buildDescriptionField(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) =>
                        SizeTransition(
                      sizeFactor: animation,
                      alignment: Alignment.topCenter,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    ),
                    child: hasNegative
                        ? Padding(
                            key: const ValueKey('fine'),
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Denda / Sanksi',
                                  'Wajib diisi karena ada temuan kerusakan.',
                                ),
                                const SizedBox(height: 12),
                                _buildFineField(),
                                if (_touched &&
                                    _fineCtrl.text.trim().isEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildErrorText(
                                    'Harap isi denda atau sanksi terlebih '
                                    'dahulu.',
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('no-fine'),
                          ),
                  ),
                  const SizedBox(height: 24),
                  DocumentationSection(
                    picker: _docPicker,
                    onChanged: (photos, video) {
                      _docPhotos = photos;
                      _docVideo = video;
                    },
                  ),
                  if (_touched && _positive.isEmpty) ...[
                    const SizedBox(height: 12),
                    _buildErrorText(
                        'Pilih minimal satu kondisi pemeriksaan terlebih '
                        'dahulu.'),
                  ],
                ],
              ),
            ),
          ),
          // Tombol konfirmasi dinamis + batas aman
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.fade(0.06),
                  offset: const Offset(0, -6),
                  blurRadius: 24,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: _buildSubmitButton(canSubmit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            shape: BoxShape.circle,
          ),
          child: const MsIcon(Symbols.checklist,
              size: 22, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cek Kondisi Barang',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Verifikasi kondisi fisik barang saat dikembalikan.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            child: const MsIcon(Symbols.close,
                size: 18, color: AppColors.slate600),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final r = widget.item;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _infoLabel('Kode'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.code,
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLabel('Peminjam'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.name,
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLabel('Barang'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${r.itemName} • ${r.serial}',
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w600,
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

  Widget _infoLabel(String t) => SizedBox(
        width: 64,
        child: Text(
          t,
          style: AppTextStyles.labelMd(
            weight: FontWeight.w500,
            color: AppColors.slate500,
          ),
        ),
      );

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSm(color: AppColors.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextStyles.bodySm(
            weight: FontWeight.w500,
            color: AppColors.slate600,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklist({
    required List<String> options,
    required Set<int> selected,
    required bool positive,
    required void Function(int) onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _ChecklistTile(
              label: options[i],
              value: selected.contains(i),
              accent: positive
                  ? AppColors.primary
                  : AppColors.error,
              onChanged: (v) => onToggle(i),
            ),
            if (i != options.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 52,
                color: AppColors.outlineVariant.fade(0.5),
              ),
          ],
        ],
      ),
    );
  }

  void _togglePositive(int i) =>
      setState(() => _positive.contains(i) ? _positive.remove(i) : _positive.add(i));

  void _toggleNegative(int i) {
    setState(() {
      if (_negative.contains(i)) {
        _negative.remove(i);
      } else {
        _negative.add(i);
      }
    });
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descCtrl,
      maxLines: 3,
      minLines: 2,
      textCapitalization: TextCapitalization.sentences,
      style: AppTextStyles.bodyMd(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'Contoh: goresan kecil di bodi, kabel rapi, dsb.',
        hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFineField() {
    return TextField(
      controller: _fineCtrl,
      onChanged: (_) => setState(() => _touched = true),
      textCapitalization: TextCapitalization.sentences,
      style: AppTextStyles.bodyMd(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'Contoh: denda Rp50.000 / penggantian komponen',
        hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        errorText: _touched && _fineCtrl.text.trim().isEmpty
            ? 'Wajib diisi karena ada temuan kerusakan.'
            : null,
        prefixIcon: const MsIcon(Symbols.payments,
            size: 20, color: AppColors.error),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildErrorText(String msg) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MsIcon(Symbols.info, size: 16, color: AppColors.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            msg,
            style: AppTextStyles.bodySm(
              weight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool canSubmit) {
    final hasNegative = _hasNegative;
    final bg = hasNegative ? AppColors.error : AppColors.primary;
    final fg = Colors.white;
    final icon = hasNegative ? Symbols.close : Symbols.check;
    final label =
        hasNegative ? 'Tolak Pengembalian' : 'Konfirmasi Pengembalian';
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _submitting || !canSubmit
            ? null
            : _submit,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : MsIcon(icon, size: 20, color: fg),
        label: Text(
          _submitting ? 'Memproses...' : label,
          style: AppTextStyles.labelLg(
              weight: FontWeight.w700, color: fg),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: const StadiumBorder(),
          disabledBackgroundColor: bg.fade(0.35),
          disabledForegroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _touched = true);

    // Validasi: minimal satu kondisi positif.
    if (_positive.isEmpty) return;

    // Validasi: jika ada temuan negatif, denda/sanksi wajib diisi.
    if (_hasNegative && _fineCtrl.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    // Simulasi proses (backend akan menggantikan di sini).
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    final result = InspectionResult(
      isApproved: !_hasNegative,
      positiveChecks: [
        for (final i in _positive) _positiveOptions[i],
      ],
      negativeChecks: [
        for (final i in _negative) _negativeOptions[i],
      ],
      description: _descCtrl.text.trim(),
      fine: _fineCtrl.text.trim(),
      checkedAt: '24 Okt 2024, 17:05 WIB',
      documentationPhotos: List.of(_docPhotos),
      documentationVideo: _docVideo,
    );
    Navigator.of(context).pop(result);
  }
}

// ---------------------------------------------------------------------------
// Satu baris checklist pada form pemeriksaan
// ---------------------------------------------------------------------------
class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? accent : Colors.transparent,
                shape: BoxShape.circle,
                border: value
                    ? null
                    : Border.all(
                        color: AppColors.outlineVariant,
                        width: 2,
                      ),
              ),
              child: value
                  ? const MsIcon(Symbols.check,
                      size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMd(
                  weight: value ? FontWeight.w700 : FontWeight.w500,
                  color: value ? accent : AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: AppTextStyles.labelLg(
              weight: FontWeight.w700, color: foreground),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bar ringkasan di atas bottom nav: total, rekap XLS
// ---------------------------------------------------------------------------
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.total,
    required this.onExport,
  });

  final int total;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mobileGutter,
        8,
        AppSpacing.mobileGutter,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$total Total\nTransaksi',
                style: AppTextStyles.labelSm(
                  weight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            _PillButton(
              icon: Symbols.download,
              label: 'Rekap\nXLS',
              background: AppColors.primaryFixed,
              foreground: AppColors.primary,
              onPressed: onExport,
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                textAlign: TextAlign.left,
                style: AppTextStyles.labelSm(
                  weight: FontWeight.w700,
                  color: foreground,
                ).copyWith(height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}