import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/shared/widgets/app_bottom_nav.dart';

// Simpan di: lib/features/admin/borrowings/admin_borrowings_screen.dart

enum _LoanStatus { waiting, borrowed, approved, late, done }

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

// Warna status yang belum ada di AppColors (amber untuk "menunggu").
const _amberBg = Color(0xFFFFF1D6);
const _amberFg = Color(0xFFB45309);

class AdminBorrowingsScreen extends StatefulWidget {
  const AdminBorrowingsScreen({super.key});

  @override
  State<AdminBorrowingsScreen> createState() => _AdminBorrowingsScreenState();
}

class _AdminBorrowingsScreenState extends State<AdminBorrowingsScreen> {
  _LoanStatus? _filter; // null = semua
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

  static const _filters = <(String, _LoanStatus?)>[
    ('Semua', null),
    ('Menunggu', _LoanStatus.waiting),
    ('Dipinjam', _LoanStatus.borrowed),
    ('Disetujui', _LoanStatus.approved),
    ('Terlambat', _LoanStatus.late),
    ('Selesai', _LoanStatus.done),
  ];

  int _count(_LoanStatus? s) =>
      s == null ? _loans.length : _loans.where((l) => l.status == s).length;

  List<_Loan> get _visible {
    final q = _query.trim().toLowerCase();
    return _loans.where((l) {
      if (_filter != null && l.status != _filter) return false;
      if (q.isEmpty) return true;
      return l.name.toLowerCase().contains(q) ||
          l.code.toLowerCase().contains(q) ||
          l.itemName.toLowerCase().contains(q) ||
          l.serial.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loans = _visible;
    return Scaffold(
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
                AppSpacing.md,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Data Peminjaman',
                          style: AppTextStyles.headlineMd(
                              color: AppColors.onSurface)),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola pengajuan & pengembalian sekolah',
                        style: AppTextStyles.bodyMd(color: AppColors.slate600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _SyncRow(),
                const SizedBox(height: 16),
                _SearchField(onChanged: (v) => setState(() => _query = v)),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 16),
                if (loans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'Tidak ada data peminjaman',
                        style: AppTextStyles.bodyMd(color: AppColors.slate500),
                      ),
                    ),
                  ),
                for (final l in loans) ...[
                  _LoanCard(
                    loan: l,
                    onReject: () {
                      // TODO: tolak pengajuan
                    },
                    onApprove: () {
                      // TODO: setujui pengajuan
                    },
                    onSuspend: () {
                      // TODO: suspend akun peminjam
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SummaryBar(
            total: _loans.length,
            onExport: () {
              // TODO: export rekap ke XLS
            },
            onScan: () {
              // TODO: Navigator.push ke qr_scanner_screen
            },
          ),
          AppBottomNav(
            items: AppBottomNav.dashboardItems,
            currentIndex: 1, // Pinjaman
            onTap: (_) {},
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, status) = _filters[i];
          final selected = _filter == status;
          return GestureDetector(
            onTap: () => setState(() => _filter = status),
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
                '$label (${_count(status)})',
                style: AppTextStyles.labelMd(
                  weight: FontWeight.w700,
                  color: selected ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
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
                      style: AppTextStyles.headlineSm(color: AppColors.primary)
                          .copyWith(fontWeight: FontWeight.w800),
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
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryFixed, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryFixed,
                  child:
                      Icon(Icons.person, size: 20, color: AppColors.primary),
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
  const _SearchField({required this.onChanged});
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
          hintText: 'Cari item, no. aset, atau merk...',
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
// Chip status
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
// Bar ringkasan di atas bottom nav: total, rekap XLS, scan ID
// ---------------------------------------------------------------------------
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.total,
    required this.onExport,
    required this.onScan,
  });

  final int total;
  final VoidCallback onExport;
  final VoidCallback onScan;

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
            const SizedBox(width: 8),
            _PillButton(
              icon: Symbols.qr_code_scanner,
              label: 'Scan\nID',
              background: AppColors.primary,
              foreground: AppColors.onPrimary,
              onPressed: onScan,
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