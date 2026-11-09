import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';

enum _HistoryFilter { all, onTime, lateReturned }

class _HistoryItem {
  const _HistoryItem({
    required this.code,
    required this.name,
    required this.subtitle,
    required this.itemName,
    required this.serial,
    required this.itemIcon,
    required this.returnDate,
    required this.conditionNote,
    this.isTeacher = false,
    this.isOnTime = true,
  });

  final String code;
  final String name;
  final String subtitle;
  final String itemName;
  final String serial;
  final IconData itemIcon;
  final String returnDate;
  final String conditionNote;
  final bool isTeacher;
  final bool isOnTime;

  String get initials {
    final parts = name.replaceAll('Drs. ', '').trim().split(' ');
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }
}

class AdminHistoryScreen extends StatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;
  String _query = '';

  // Data riwayat peminjaman selesai (Dummy data sesuai style admin)
  static const List<_HistoryItem> _histories = [
    _HistoryItem(
      code: 'BK-2024-086',
      name: 'Annisa Rahma',
      subtitle: 'XII DKV 1 • NIS: 202208034',
      itemName: 'Rode PodMic Set Dual',
      serial: 'ROD-PM-019',
      itemIcon: Symbols.mic,
      returnDate: '23 Okt 2024 • 14:15 WIB',
      conditionNote: 'Kondisi: Lengkap & Bersih (Tepat Waktu)',
      isOnTime: true,
    ),
    _HistoryItem(
      code: 'BK-2024-082',
      name: 'Budi Santoso',
      subtitle: 'XI RPL 2 • NIS: 202308012',
      itemName: 'DSLR Canon EOS 80D',
      serial: 'CAN-80D-011',
      itemIcon: Symbols.photo_camera,
      returnDate: '22 Okt 2024 • 16:00 WIB',
      conditionNote: 'Kondisi: Ada sedikit debu pada lensa',
      isOnTime: true,
    ),
    _HistoryItem(
      code: 'BK-2024-079',
      name: 'Drs. Agus Hidayat',
      isTeacher: true,
      subtitle: 'Guru Produktif TKJ • NIP: 19780512...',
      itemName: 'MikroTik Cloud Core CCR',
      serial: 'MTK-CCR-1009',
      itemIcon: Symbols.router,
      returnDate: '21 Okt 2024 • 12:30 WIB',
      conditionNote: 'Kondisi: Sangat Baik & Berfungsi Normal',
      isOnTime: true,
    ),
    _HistoryItem(
      code: 'BK-2024-075',
      name: 'Devi Anggraini',
      subtitle: 'XII MM 1 • NIS: 202207099',
      itemName: 'Huion Kamvas 16 Pro',
      serial: 'HU-K16-001',
      itemIcon: Symbols.draw,
      returnDate: '20 Okt 2024 • 15:45 WIB',
      conditionNote: 'Kondisi: Terlambat dikembalikan (1 Hari)',
      isOnTime: false,
    ),
  ];

  int _count(_HistoryFilter f) {
    if (f == _HistoryFilter.all) return _histories.length;
    if (f == _HistoryFilter.onTime) return _histories.where((h) => h.isOnTime).length;
    if (f == _HistoryFilter.lateReturned) return _histories.where((h) => !h.isOnTime).length;
    return _histories.length;
  }

  List<_HistoryItem> get _visible {
    final q = _query.trim().toLowerCase();
    return _histories.where((h) {
      if (_filter == _HistoryFilter.onTime && !h.isOnTime) return false;
      if (_filter == _HistoryFilter.lateReturned && h.isOnTime) return false;
      if (q.isEmpty) return true;
      return h.name.toLowerCase().contains(q) ||
          h.code.toLowerCase().contains(q) ||
          h.itemName.toLowerCase().contains(q) ||
          h.serial.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final histories = _visible;
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
          const _SyncRow(),
          const SizedBox(height: 16),
          _SearchField(onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 16),
          _buildFilterChips(),
          const SizedBox(height: 16),
          if (histories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Tidak ada data riwayat',
                  style: AppTextStyles.bodyMd(color: AppColors.slate500),
                ),
              ),
            ),
          for (final h in histories) ...[
            _HistoryCard(history: h),
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
          total: _histories.length,
          onExport: () {
            // TODO: export riwayat ke XLS
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = <(String, _HistoryFilter)>[
      ('Semua (${_histories.length})', _HistoryFilter.all),
      ('Tepat Waktu (${_count(_HistoryFilter.onTime)})', _HistoryFilter.onTime),
      ('Terlambat (${_count(_HistoryFilter.lateReturned)})', _HistoryFilter.lateReturned),
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
                color: selected ? AppColors.primary : AppColors.surfaceContainerLowest,
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
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.emerald500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Arsip Aktif',
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w700,
                    color: AppColors.emerald500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Penyimpanan otomatis aman',
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
  const _HistoryCard({required this.history});
  final _HistoryItem history;

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
          Row(
            children: [
              Text('#', style: AppTextStyles.headlineSm(color: AppColors.primary)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  history.code,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: history.isOnTime ? AppColors.surfaceContainerLow : AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      history.isOnTime ? Symbols.check_circle : Symbols.warning,
                      size: 14,
                      color: history.isOnTime ? AppColors.slate600 : AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      history.isOnTime ? 'Selesai' : 'Terlambat',
                      style: AppTextStyles.labelSm(
                        weight: FontWeight.w700,
                        color: history.isOnTime ? AppColors.slate600 : AppColors.error,
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
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  history.initials,
                  style: AppTextStyles.headlineSm(color: AppColors.primary)
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
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
                            history.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (history.isTeacher) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      history.subtitle,
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
                        history.itemName,
                        style: AppTextStyles.bodyMd(
                          weight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.fade(0.6),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        history.serial,
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
                    const Icon(Symbols.calendar_month, size: 16, color: AppColors.slate600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dikembalikan: ${history.returnDate}',
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
                    const Icon(Symbols.fact_check, size: 16, color: AppColors.emerald500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        history.conditionNote,
                        style: AppTextStyles.bodySm(
                          weight: FontWeight.w600,
                          color: AppColors.slate700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.download, size: 20, color: AppColors.primary),
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
