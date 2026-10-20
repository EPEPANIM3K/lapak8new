import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/lapak_header.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryData {
  final String bookingId, name, category, dateStr, returnedAt, verifiedBy, status;
  final String? rejectionReason, imageUrl;
  final int units;
  const _HistoryData({
    required this.bookingId, required this.name, required this.category,
    required this.dateStr, required this.returnedAt, required this.verifiedBy,
    required this.status, required this.units, this.rejectionReason, this.imageUrl,
  });
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCM9TBr73lAvJae_M-j8bVPXa69t9E8fJjw6s1fOkJB9Rwn5SdnSrc2vwOfl_FwiSc0PAsKLZ3OrWbOxQRw_0Nv8TltDOZ-YW8v68X2WTQJl29s3nRn2_K2GuSWHAvMZpMCZJe6iBeZDp5yEl_7IcjmKNNuCgejx9XkiISbISzKzJKsN4oi8-ZVu-ddev07E4AA7eAz81C-Lou8NTkx4lFKRMgys8zcncLJEU3cjaxS9X4CrRZuET7Y';

  static const cSurface = Color(0xFFFAF8FF);
  static const cSurfaceLowest = Color(0xFFFFFFFF);
  static const cSurfaceLow = Color(0xFFF2F3FF);
  static const cSurfaceContainer = Color(0xFFEAEDFF);
  static const cSurfaceHigh = Color(0xFFE2E7FF);
  static const cOnSurface = Color(0xFF131B2E);
  static const cOnSurfaceVariant = Color(0xFF434655);
  static const cPrimary = Color(0xFF0037B0);
  static const cTertiary = Color(0xFF004F35);
  static const cTertiaryContainer = Color(0xFF006A48);
  static const cError = Color(0xFFBA1A1A);
  static const cErrorContainer = Color(0xFFFFDAD6);
  static const cSecondary = Color(0xFF505F76);
  static const cSecondaryContainer = Color(0xFFD0E1FB);
  static const cOutline = Color(0xFF747686);
  static const cOutlineVariant = Color(0xFFC4C5D7);

  final _searchCtrl = TextEditingController();
  String _tab = 'all';
  String _query = '';

  final _items = const [
    _HistoryData(
      bookingId: 'BK-20241012-0891', name: 'Sony Alpha A6400 + Kit',
      category: 'Multimedia & Dokumentasi', units: 1,
      dateStr: '12 Okt 2024 (08:00 - 15:30 WIB)',
      returnedAt: '12 Okt 2024, 15:10 WIB', verifiedBy: 'Pak Hendra (Laboran)',
      status: 'completed',
      imageUrl: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=300&q=80',
    ),
    _HistoryData(
      bookingId: 'BK-20241008-0872', name: 'Drawing Tablet Huion Kamvas 16',
      category: 'Desain Grafis & Animasi', units: 1,
      dateStr: '8 Okt 2024 (09:00 – 14:30 WIB)',
      returnedAt: '8 Okt 2024, 14:15 WIB', verifiedBy: 'Bu Ratna (Laboran Desain)',
      status: 'completed',
      imageUrl: 'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&w=300&q=80',
    ),
    _HistoryData(
      bookingId: 'BK-20240928-0845', name: 'Proyektor Epson EB-X500',
      category: 'Multimedia Presentasi', units: 1,
      dateStr: 'Diajukan: 28 Sep 2024',
      returnedAt: '-', verifiedBy: '-',
      status: 'rejected',
      rejectionReason: 'Jadwal bentrok dengan Ujian Tengah Semester di Lab Multimedia.',
      imageUrl: 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=300&q=80',
    ),
  ];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<_HistoryData> get _filtered => _items.where((item) {
    final q = _query.toLowerCase();
    final okQ = q.isEmpty || item.name.toLowerCase().contains(q) || item.bookingId.toLowerCase().contains(q);
    final okT = _tab == 'all' || item.status == _tab;
    return okQ && okT;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          LapakHeader(
            avatarUrl: _avatarUrl,
            onAvatarTap: () => context.push('/profile'),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
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
                  filtered.isEmpty
                      ? _emptyState()
                      : Column(children: filtered.map((h) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _historyCard(h))).toList()),
                ],
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

  Widget _pageTitle() => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Riwayat Peminjaman', style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w700, color: cOnSurface, letterSpacing: -0.5)),
    SizedBox(height: 2),
    Text('Catatan riwayat peminjaman sarana dan item sekolah', style: TextStyle(fontSize: 13, color: cSecondary)),
  ]);

  Widget _statsGrid() => Row(children: [
    Expanded(child: _statCard('Semua', '18', 'Selesai', Icons.inventory_2_outlined, cPrimary)),
    const SizedBox(width: 8),
    Expanded(child: _statCard('Tepat Waktu', '16', 'Aman', Icons.verified_outlined, cTertiaryContainer)),
    const SizedBox(width: 8),
    Expanded(child: _statCard('Terlambat', '2', 'Kasus', Icons.running_with_errors, cError)),
  ]);

  Widget _statCard(String label, String value, String suffix, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: cSurfaceLowest, borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cSecondary)),
        Icon(icon, size: 16, color: color),
      ]),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 4),
        Text(suffix, style: const TextStyle(fontSize: 11, color: cSecondary)),
      ]),
    ]),
  );

  Widget _searchField() => Container(
    height: 52,
    decoration: BoxDecoration(color: cSurfaceLowest, borderRadius: BorderRadius.circular(999),
      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))]),
    child: Row(children: [
      const SizedBox(width: 16),
      const Icon(Icons.search, size: 20, color: cSecondary),
      const SizedBox(width: 8),
      Expanded(child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
        style: const TextStyle(fontSize: 14, color: cOnSurface),
        decoration: const InputDecoration(
          isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero,
          hintText: 'Cari riwayat booking atau item...',
          hintStyle: TextStyle(fontSize: 14, color: cOutlineVariant),
        ),
      )),
    ]),
  );

  Widget _filterTabs() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [
      _filterTab('all', 'Semua'),
      const SizedBox(width: 8),
      _filterTab('completed', 'Selesai'),
      const SizedBox(width: 8),
      _filterTab('canceled', 'Dibatalkan'),
      const SizedBox(width: 8),
      _filterTab('rejected', 'Ditolak'),
    ]),
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
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? Colors.white : cSecondary)),
      ),
    );
  }

  Widget _historyCard(_HistoryData h) {
    final isRejected = h.status == 'rejected';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cSurfaceLowest, borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.tag, size: 16, color: cSecondary),
            const SizedBox(width: 4),
            Text(h.bookingId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cSecondary, letterSpacing: 0.4)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isRejected ? cErrorContainer.withValues(alpha: 0.4) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isRejected ? Icons.cancel_outlined : Icons.circle,
                size: isRejected ? 12 : 6, color: isRejected ? cError : cTertiaryContainer),
              const SizedBox(width: 4),
              Text(isRejected ? 'Ditolak Admin' : 'Selesai Tepat Waktu',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isRejected ? cError : cTertiary)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 80, height: 80, clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: cSurfaceHigh, borderRadius: BorderRadius.circular(16)),
            child: h.imageUrl != null
              ? Image.network(h.imageUrl!, fit: BoxFit.cover,
                  loadingBuilder: (_, child, p) => p == null ? child : Container(color: cSurfaceHigh),
                  errorBuilder: (_, __, ___) => Container(color: cSurfaceHigh, child: const Icon(Icons.image_outlined, color: cOutlineVariant)))
              : Container(color: cSurfaceHigh),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: cOnSurface)),
            const SizedBox(height: 2),
            Text('${h.category} • ${h.units} Unit', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: cSecondary)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(isRejected ? Icons.history_toggle_off : Icons.calendar_today,
                size: 13, color: isRejected ? cOutline : cPrimary),
              const SizedBox(width: 4),
              Expanded(child: Text(h.dateStr, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: cOnSurfaceVariant))),
            ]),
          ])),
        ]),
        const SizedBox(height: 10),
        if (isRejected)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cErrorContainer.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, size: 16, color: cError),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Alasan Penolakan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cError)),
                const SizedBox(height: 2),
                Text(h.rejectionReason ?? '-', style: const TextStyle(fontSize: 12, color: cOnSurface, height: 1.4)),
              ])),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cSurfaceLow, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _kvRow('Waktu Kembali:', h.returnedAt, valueColor: cOnSurface, valueBold: true),
              const SizedBox(height: 4),
              _kvRow('Diverifikasi oleh:', h.verifiedBy, valueColor: cPrimary, valueBold: true),
            ]),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: SizedBox(height: 44, child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.cached, size: 18),
            label: Text(isRejected ? 'Ajukan Ulang / Pilih Item Lain' : 'Pinjam Lagi', style: const TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRejected ? cSurfaceHigh : cPrimary,
              foregroundColor: isRejected ? cOnSurface : Colors.white,
              elevation: isRejected ? 0 : 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ))),
          if (!isRejected) ...[
            const SizedBox(width: 8),
            SizedBox(height: 44, child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Bukti PDF', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: cPrimary, backgroundColor: cSecondaryContainer.withValues(alpha: 0.5),
                side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            )),
          ],
        ]),
      ]),
    );
  }

  Widget _kvRow(String k, String v, {required Color valueColor, bool valueBold = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(k, style: const TextStyle(fontSize: 11, color: cSecondary)),
      Text(v, style: TextStyle(fontSize: 11, fontWeight: valueBold ? FontWeight.w600 : FontWeight.w400, color: valueColor)),
    ],
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      Container(width: 64, height: 64,
        decoration: const BoxDecoration(color: cSurfaceHigh, shape: BoxShape.circle),
        child: const Icon(Icons.history, size: 32, color: cPrimary)),
      const SizedBox(height: 12),
      const Text('Belum ada riwayat', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: cOnSurface)),
      const SizedBox(height: 4),
      const Text('Riwayat peminjaman akan tampil di sini.', style: TextStyle(fontSize: 12, color: cOnSurfaceVariant)),
    ]),
  );
}
