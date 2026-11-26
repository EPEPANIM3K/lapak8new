import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/lapak_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../borrowings/models/peminjaman.dart';
import '../../borrowings/services/peminjaman_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const cSurfaceLowest = Color(0xFFFFFFFF);
  static const cSurfaceLow = Color(0xFFF2F3FF);
  static const cSurfaceHigh = Color(0xFFE2E7FF);
  static const cOnSurface = Color(0xFF131B2E);
  static const cOnSurfaceVariant = Color(0xFF434655);
  static const cPrimary = Color(0xFF0037B0);
  static const cTertiary = Color(0xFF004F35);
  static const cTertiaryContainer = Color(0xFF006A48);
  static const cError = Color(0xFFBA1A1A);
  static const cErrorContainer = Color(0xFFFFDAD6);
  static const cSecondary = Color(0xFF505F76);
  static const cOutlineVariant = Color(0xFFC4C5D7);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  final _searchCtrl = TextEditingController();
  String _tab = 'all';
  String _query = '';
  List<Peminjaman> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await peminjamanService.ambilRiwayatSaya();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  bool _isLate(Peminjaman p) {
    if (p.status == StatusPeminjaman.terlambat) return true;
    if (p.status == StatusPeminjaman.dikembalikan && p.dikembalikanPada != null) {
      return p.dikembalikanPada!.isAfter(p.estimasiKembaliPada);
    }
    return false;
  }

  int get _completedCount => _items
      .where((p) =>
          p.status == StatusPeminjaman.dikembalikan ||
          p.status == StatusPeminjaman.terlambat)
      .length;

  int get _onTimeCount => _items
      .where((p) => p.status == StatusPeminjaman.dikembalikan && !_isLate(p))
      .length;

  int get _lateCount => _items.where(_isLate).length;

  List<Peminjaman> get _filtered => _items.where((p) {
        final q = _query.toLowerCase();
        final itemName = p.items.isNotEmpty
            ? p.items.first.namaFasilitasSnapshot
            : p.namaKegiatan;
        final okQ = q.isEmpty ||
            itemName.toLowerCase().contains(q) ||
            p.kodeBooking.toLowerCase().contains(q) ||
            p.namaKegiatan.toLowerCase().contains(q);

        final okT = switch (_tab) {
          'completed' => p.status == StatusPeminjaman.dikembalikan ||
              p.status == StatusPeminjaman.terlambat,
          'canceled' => p.status == StatusPeminjaman.dibatalkan,
          'rejected' => p.status == StatusPeminjaman.ditolak,
          _ => true,
        };
        return okQ && okT;
      }).toList();

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_months[local.month - 1]} ${local.year}, $hh:$mm WIB';
  }

  String _formatRange(Peminjaman p) {
    final s = p.mulaiPada.toLocal();
    final e = p.estimasiKembaliPada.toLocal();
    final sh = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
    final eh = '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
    return '${s.day} ${_months[s.month - 1]} ${s.year} ($sh - $eh WIB)';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          LapakHeader(
            avatarUrl: authProvider.user?.fotoUrl ?? '',
            onAvatarTap: () => context.push('/profile'),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _pageTitle(),
                    const SizedBox(height: 12),
                    _statsGrid(),
                    const SizedBox(height: 16),
                    _searchField(),
                    const SizedBox(height: 8),
                    _filterTabs(),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _errorState()
                    else if (filtered.isEmpty)
                      _emptyState()
                    else
                      Column(
                        children: filtered
                            .map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _historyCard(p),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          AppBottomNav(
            items: AppBottomNav.userItems,
            currentIndex: 3,
            onTap: (_) {},
          ),
        ],
      ),
    );
  }

  Widget _pageTitle() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Riwayat Peminjaman',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: cOnSurface,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Catatan riwayat peminjaman sarana dan item sekolah',
            style: TextStyle(fontSize: 13, color: cSecondary),
          ),
        ],
      );

  Widget _statsGrid() => Row(children: [
        Expanded(
          child: _statCard(
            'Semua',
            '$_completedCount',
            'Selesai',
            Icons.inventory_2_outlined,
            cPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            'Tepat Waktu',
            '$_onTimeCount',
            'Aman',
            Icons.verified_outlined,
            cTertiaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            'Terlambat',
            '$_lateCount',
            'Kasus',
            Icons.running_with_errors,
            cError,
          ),
        ),
      ]);

  Widget _statCard(
    String label,
    String value,
    String suffix,
    IconData icon,
    Color color,
  ) =>
      Container(
        padding: const EdgeInsets.all(12),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cSecondary,
                  ),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  suffix,
                  style: const TextStyle(fontSize: 11, color: cSecondary),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _searchField() => Container(
        height: 52,
        decoration: BoxDecoration(
          color: cSurfaceLowest,
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
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search, size: 20, color: cSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    setState(() => _query = v.toLowerCase().trim()),
                style: const TextStyle(fontSize: 14, color: cOnSurface),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Cari riwayat booking atau item...',
                  hintStyle: TextStyle(fontSize: 14, color: cOutlineVariant),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _filterTabs() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterTab('all', 'Semua'),
            const SizedBox(width: 8),
            _filterTab('completed', 'Selesai'),
            const SizedBox(width: 8),
            _filterTab('canceled', 'Dibatalkan'),
            const SizedBox(width: 8),
            _filterTab('rejected', 'Ditolak'),
          ],
        ),
      );

  Widget _filterTab(String key, String label) {
    final selected = _tab == key;
    return GestureDetector(
      onTap: () => setState(() => _tab = key),
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : cSecondary,
          ),
        ),
      ),
    );
  }

  Widget _historyCard(Peminjaman p) {
    final firstItem = p.items.isNotEmpty ? p.items.first : null;
    final itemName = firstItem?.namaFasilitasSnapshot ?? p.namaKegiatan;
    final units = firstItem?.jumlah ?? 1;
    final imageUrl = firstItem?.fotoUrl;

    final isRejected = p.status == StatusPeminjaman.ditolak;
    final isCanceled = p.status == StatusPeminjaman.dibatalkan;
    final isLate = _isLate(p);

    final Color badgeBg;
    final Color badgeFg;
    final IconData badgeIcon;
    final String badgeText;

    if (isRejected) {
      badgeBg = cErrorContainer.withValues(alpha: 0.4);
      badgeFg = cError;
      badgeIcon = Icons.cancel_outlined;
      badgeText = 'Ditolak Admin';
    } else if (isCanceled) {
      badgeBg = cSurfaceHigh;
      badgeFg = cSecondary;
      badgeIcon = Icons.block;
      badgeText = 'Dibatalkan';
    } else if (isLate) {
      badgeBg = cErrorContainer.withValues(alpha: 0.4);
      badgeFg = cError;
      badgeIcon = Icons.schedule;
      badgeText = 'Terlambat';
    } else {
      badgeBg = const Color(0xFFECFDF5);
      badgeFg = cTertiary;
      badgeIcon = Icons.circle;
      badgeText = 'Selesai Tepat Waktu';
    }

    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tag, size: 16, color: cSecondary),
                  const SizedBox(width: 4),
                  Text(
                    p.kodeBooking,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      badgeIcon,
                      size: (isRejected || isCanceled || isLate) ? 12 : 6,
                      color: badgeFg,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cSurfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, pr) =>
                            pr == null ? child : Container(color: cSurfaceHigh),
                        errorBuilder: (_, __, ___) => Container(
                          color: cSurfaceHigh,
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: cOutlineVariant,
                          ),
                        ),
                      )
                    : Container(
                        color: cSurfaceHigh,
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: cPrimary,
                        ),
                      ),
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
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cOnSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.labelKategori} • $units Unit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: cSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          (isRejected || isCanceled)
                              ? Icons.history_toggle_off
                              : Icons.calendar_today,
                          size: 13,
                          color: (isRejected || isCanceled)
                              ? cSecondary
                              : cPrimary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatRange(p),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isRejected)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cErrorContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 16, color: cError),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alasan Penolakan:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cError,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.alasanPenolakan ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: cOnSurface,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (!isCanceled)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cSurfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _kvRow(
                    'Waktu Kembali:',
                    p.dikembalikanPada != null
                        ? _formatDateTime(p.dikembalikanPada!)
                        : '-',
                    valueColor: cOnSurface,
                    valueBold: true,
                  ),
                  const SizedBox(height: 4),
                  _kvRow(
                    'Kegiatan:',
                    p.namaKegiatan,
                    valueColor: cPrimary,
                    valueBold: true,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => context.push(
                '/borrowing-form',
                extra: firstItem?.fasilitasId,
              ),
              icon: const Icon(Icons.cached, size: 18),
              label: Text(
                (isRejected || isCanceled)
                    ? 'Ajukan Ulang / Pilih Item Lain'
                    : 'Pinjam Lagi',
                style: const TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    (isRejected || isCanceled) ? cSurfaceHigh : cPrimary,
                foregroundColor:
                    (isRejected || isCanceled) ? cOnSurface : Colors.white,
                elevation: (isRejected || isCanceled) ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(
    String k,
    String v, {
    required Color valueColor,
    bool valueBold = false,
  }) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 11, color: cSecondary)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: valueBold ? FontWeight.w600 : FontWeight.w400,
                color: valueColor,
              ),
            ),
          ),
        ],
      );

  Widget _errorState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: cError),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: cSurfaceHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history, size: 32, color: cPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data riwayat',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cOnSurface,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Riwayat peminjaman yang sudah selesai, ditolak, atau dibatalkan akan tampil di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cOnSurfaceVariant),
            ),
          ],
        ),
      );
}
