import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/borrowings/models/peminjaman.dart';
import 'package:lapak8new/features/borrowings/services/peminjaman_service.dart';
import 'package:lapak8new/shared/widgets/app_bottom_nav.dart';
import 'package:lapak8new/shared/widgets/user_avatar.dart';

enum _HistoryFilter { all, onTime, lateReturned }

class AdminHistoryScreen extends StatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen> {
  static const _months = [
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

  _HistoryFilter _filter = _HistoryFilter.all;
  String _query = '';
  List<Peminjaman> _histories = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await peminjamanService.ambilSemuaRiwayat();
      if (!mounted) return;
      setState(() {
        _histories = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isOnTime(Peminjaman p) {
    if (p.status == StatusPeminjaman.terlambat) return false;
    if (p.dikembalikanPada != null) {
      return !p.dikembalikanPada!.isAfter(p.estimasiKembaliPada);
    }
    return true;
  }

  int _count(_HistoryFilter f) {
    if (f == _HistoryFilter.all) return _histories.length;
    if (f == _HistoryFilter.onTime) {
      return _histories.where(_isOnTime).length;
    }
    if (f == _HistoryFilter.lateReturned) {
      return _histories.where((h) => !_isOnTime(h)).length;
    }
    return _histories.length;
  }

  List<Peminjaman> get _visible {
    final q = _query.trim().toLowerCase();
    return _histories.where((h) {
      final onTime = _isOnTime(h);
      if (_filter == _HistoryFilter.onTime && !onTime) return false;
      if (_filter == _HistoryFilter.lateReturned && onTime) return false;
      if (q.isEmpty) return true;
      final itemNames = h.items.map((i) => i.namaFasilitasSnapshot).join(' ');
      return (h.namaPeminjam ?? '').toLowerCase().contains(q) ||
          h.kodeBooking.toLowerCase().contains(q) ||
          itemNames.toLowerCase().contains(q) ||
          h.namaKegiatan.toLowerCase().contains(q);
    }).toList();
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_months[local.month - 1]} ${local.year} • $hh:$mm WIB';
  }

  @override
  Widget build(BuildContext context) {
    final histories = _visible;
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  Text(
                    'Riwayat Peminjaman',
                    style: AppTextStyles.headlineMd(color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Arsip data peminjaman yang sudah selesai',
                    style: AppTextStyles.bodyMd(color: AppColors.slate600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SyncRow(isLoading: _loading, hasError: _error != null),
            const SizedBox(height: 16),
            _SearchField(onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 16),
            _buildFilterChips(),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd(color: AppColors.error),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Symbols.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else if (_histories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Symbols.history,
                        size: 40,
                        color: AppColors.slate400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada data riwayat',
                        style: AppTextStyles.bodyMd(color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
              )
            else if (histories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'Tidak ada riwayat yang cocok dengan pencarian atau filter.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMd(color: AppColors.slate500),
                  ),
                ),
              )
            else
              for (final h in histories) ...[
                _HistoryCard(
                  history: h,
                  isOnTime: _isOnTime(h),
                  returnDate: h.dikembalikanPada != null
                      ? _formatDateTime(h.dikembalikanPada!)
                      : _formatDateTime(h.estimasiKembaliPada),
                ),
                const SizedBox(height: 16),
              ],
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.mobileGutter,
              AppSpacing.md,
              AppSpacing.mobileGutter,
              AppSpacing.md,
            ),
            child: _SummaryBar(
              total: _histories.length,
              onExport: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Fitur ekspor XLS akan segera hadir.'),
                    ),
                  );
              },
            ),
          ),
          const AdminBottomNav(currentIndex: 2),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = <(String, _HistoryFilter)>[
      ('Semua (${_histories.length})', _HistoryFilter.all),
      ('Tepat Waktu (${_count(_HistoryFilter.onTime)})', _HistoryFilter.onTime),
      (
        'Terlambat (${_count(_HistoryFilter.lateReturned)})',
        _HistoryFilter.lateReturned,
      ),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, f) = filters[i];
          final selected = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
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
                label,
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

class _SyncRow extends StatelessWidget {
  const _SyncRow({required this.isLoading, required this.hasError});

  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final statusColor = hasError
        ? AppColors.error
        : isLoading
        ? AppColors.slate500
        : AppColors.emerald500;
    final statusLabel = hasError
        ? 'Sinkronisasi gagal'
        : isLoading
        ? 'Memuat riwayat'
        : 'Data tersinkronisasi';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasError
                  ? 'Periksa koneksi lalu coba muat ulang.'
                  : 'Data riwayat diambil dari database.',
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
          hintText: 'Cari nama, item, atau no. arsip...',
          hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
          prefixIcon: const Icon(Symbols.search, color: AppColors.slate600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.history,
    required this.isOnTime,
    required this.returnDate,
  });

  final Peminjaman history;
  final bool isOnTime;
  final String returnDate;

  String get _borrowerName => history.namaPeminjam?.trim().isNotEmpty == true
      ? history.namaPeminjam!
      : 'Pengguna';

  String get _subtitle {
    final kelas = history.kelasPeminjam;
    final nomor = history.nomorIndukPeminjam;
    final parts = <String>[
      if (kelas != null && kelas.isNotEmpty) kelas,
      if (nomor != null && nomor.isNotEmpty) 'NIS/NIP: $nomor',
    ];
    return parts.isEmpty ? history.labelKategori : parts.join(' • ');
  }

  String get _itemName {
    if (history.items.isEmpty) return history.namaKegiatan;
    final first = history.items.first;
    return first.namaFasilitasSnapshot;
  }

  String get _unitLabel {
    final total = history.items.fold<int>(0, (s, i) => s + i.jumlah);
    return '${total > 0 ? total : 1} Unit';
  }

  @override
  Widget build(BuildContext context) {
    final inspection = history.pemeriksaanPengembalian;
    final hasViolation = inspection?.hasPelanggaran == true;
    final statusLabel =
        inspection?.labelStatusAkhir ?? (isOnTime ? 'Selesai' : 'Terlambat');
    final statusColor = hasViolation || !isOnTime
        ? AppColors.error
        : AppColors.slate600;

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
          Row(
            children: [
              Text(
                '#',
                style: AppTextStyles.headlineSm(color: AppColors.primary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  history.kodeBooking,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm(
                    color: AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: hasViolation || !isOnTime
                      ? AppColors.errorContainer
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasViolation || !isOnTime
                          ? Symbols.warning
                          : Symbols.check_circle,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: AppTextStyles.labelSm(
                        weight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                name: _borrowerName,
                imageUrl: history.fotoUrlPeminjam,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _borrowerName,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineSm(
                        color: AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
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
          ),
          const SizedBox(height: 14),
          Container(
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
                    Expanded(
                      child: Text(
                        _itemName,
                        style: AppTextStyles.bodyMd(
                          weight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.fade(0.6),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        _unitLabel,
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
                    const Icon(
                      Symbols.calendar_month,
                      size: 16,
                      color: AppColors.slate600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dikembalikan: $returnDate',
                        style: AppTextStyles.bodySm(
                          weight: FontWeight.w500,
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Symbols.fact_check,
                      size: 16,
                      color: isOnTime ? AppColors.emerald500 : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOnTime
                            ? 'Dikembalikan tepat waktu (${history.namaKegiatan})'
                            : 'Terlambat dikembalikan (${history.namaKegiatan})',
                        style: AppTextStyles.bodySm(
                          weight: FontWeight.w600,
                          color: AppColors.slate700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (inspection != null) ...[
                  const Divider(height: 16),
                  Text(
                    inspection.labelHasil,
                    style: AppTextStyles.labelMd(
                      weight: FontWeight.w700,
                      color: hasViolation
                          ? AppColors.error
                          : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 68,
                        child: Text(
                          'Kondisi:',
                          style: AppTextStyles.bodySm(
                            weight: FontWeight.w500,
                            color: AppColors.slate600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          inspection.labelKondisi,
                          style: AppTextStyles.bodySm(
                            weight: FontWeight.w600,
                            color: AppColors.slate700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 68,
                        child: Text(
                          'Denda:',
                          style: AppTextStyles.bodySm(
                            weight: FontWeight.w500,
                            color: AppColors.slate600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          inspection.labelDenda,
                          style: AppTextStyles.bodySm(
                            weight: FontWeight.w600,
                            color: AppColors.slate700,
                          ),
                        ),
                      ),
                    ],
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

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.total, required this.onExport});

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
                color: AppColors.emerald500,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$total Total\nArsip Selesai',
                style: AppTextStyles.labelSm(
                  weight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Material(
              color: AppColors.primaryFixed,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onExport,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.download,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Rekap\nXLS',
                        style: AppTextStyles.labelSm(
                          weight: FontWeight.w700,
                          color: AppColors.primary,
                        ).copyWith(height: 1.15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
