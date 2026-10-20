import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/lapak_header.dart';

class FacilityListScreen extends StatefulWidget {
  const FacilityListScreen({super.key});
  @override
  State<FacilityListScreen> createState() => _FacilityListScreenState();
}

class _ItemData {
  final String name, location, imageUrl;
  final int units;
  final bool available;
  const _ItemData({
    required this.name,
    required this.location,
    required this.units,
    required this.available,
    required this.imageUrl,
  });
}

/// Ikon pin lokasi (heroicons outline, stroke 2) persis seperti di Dashboard.
const _pinSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#94A3B8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<path d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
<path d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
</svg>
''';

class _FacilityListScreenState extends State<FacilityListScreen> {
  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCM9TBr73lAvJae_M-j8bVPXa69t9E8fJjw6s1fOkJB9Rwn5SdnSrc2vwOfl_FwiSc0PAsKLZ3OrWbOxQRw_0Nv8TltDOZ-YW8v68X2WTQJl29s3nRn2_K2GuSWHAvMZpMCZJe6iBeZDp5yEl_7IcjmKNNuCgejx9XkiISbISzKzJKsN4oi8-ZVu-ddev07E4AA7eAz81C-Lou8NTkx4lFKRMgys8zcncLJEU3cjaxS9X4CrRZuET7Y';

  // ===== Palette (sesuai desain) =====
  static const cSurfaceLowest = Color(0xFFFFFFFF);
  static const cSurfaceContainer = Color(0xFFEAEDFF);
  static const cOnSurface = Color(0xFF131B2E);
  static const cOnSurfaceVariant = Color(0xFF434655);
  static const cPrimary = Color(0xFF0037B0);
  static const cPrimaryContainer = Color(0xFF1D4ED8);
  static const cTertiary = Color(0xFF004F35);
  static const cTertiaryContainer = Color(0xFF006A48);
  static const cError = Color(0xFFBA1A1A);
  static const cOutlineVariant = Color(0xFFC4C5D7);
  static const cOutline = Color(0xFF747686);

  final _searchCtrl = TextEditingController();
  String _filter = 'all';
  String _query = '';

  final List<_ItemData> _items = const [
    _ItemData(name: 'Proyektor Epson EB-X400', location: 'Lab RPL', units: 4, available: true,
      imageUrl: 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=600&q=80'),
    _ItemData(name: 'Kamera DSLR Canon EOS', location: 'Studio Multimedia', units: 2, available: true,
      imageUrl: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=600&q=80'),
    _ItemData(name: 'Lab Komputer Multimedia', location: 'Gedung Praktek Lt. 1', units: 6, available: true,
      imageUrl: 'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=600&q=80'),
    _ItemData(name: 'Speaker Portable Advance', location: 'Ruang Sarpras', units: 3, available: true,
      imageUrl: 'https://images.unsplash.com/photo-1545454675-3531b543be5d?auto=format&fit=crop&w=600&q=80'),
    _ItemData(name: 'Kabel Roll & HDMI Converter', location: 'Lab RPL', units: 0, available: false,
      imageUrl: 'https://images.unsplash.com/photo-1558611848-73f7eb4001a1?auto=format&fit=crop&w=600&q=80'),
    _ItemData(name: 'Tenda & Sound System', location: 'Gudang Sarpras', units: 0, available: false,
      imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=600&q=80'),
  ];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<_ItemData> get _filtered => _items.where((item) {
    final q = _query.toLowerCase();
    final okQ = q.isEmpty || item.name.toLowerCase().contains(q) || item.location.toLowerCase().contains(q);
    final okF = _filter == 'all' ||
        (_filter == 'available' && item.available) ||
        (_filter == 'unavailable' && !item.available);
    return okQ && okF;
  }).toList();

  void _clearSearch() { _searchCtrl.clear(); setState(() => _query = ''); }

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
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _searchBar(),
                  _titleAndFilters(filtered.length),
                  if (filtered.isEmpty) _emptyState() else _grid(filtered),
                ],
              ),
            ),
          ),
          AppBottomNav(
            items: AppBottomNav.userItems,
            currentIndex: 1,
            onTap: (_) {},
          ),
        ],
      ),
    );
  }

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: cSurfaceLowest, borderRadius: BorderRadius.circular(999), boxShadow: const [
        BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
      ]),
      child: Row(children: [
        const Icon(Icons.search, size: 20, color: cOutline),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: cOnSurface),
          decoration: const InputDecoration(
            isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero,
            hintText: 'Cari item atau barang...',
            hintStyle: TextStyle(fontSize: 12, color: cOnSurfaceVariant),
          ),
        )),
        if (_query.isNotEmpty) IconButton(
          onPressed: _clearSearch, icon: const Icon(Icons.close, size: 18, color: cOutline),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
      ]),
    ),
  );

  Widget _titleAndFilters(int count) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Daftar Item', style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600, color: cOnSurface)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: cSurfaceContainer, borderRadius: BorderRadius.circular(999)),
          child: Text('$count Item', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w700, color: cPrimary, letterSpacing: 0.4)),
        ),
      ]),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _filterChip('Semua', 'all', color: cPrimaryContainer, textColor: Colors.white),
          const SizedBox(width: 8),
          _filterChip('Tersedia', 'available', color: cSurfaceLowest, textColor: cTertiary, dot: cTertiaryContainer),
          const SizedBox(width: 8),
          _filterChip('Tidak tersedia', 'unavailable', color: cSurfaceLowest, textColor: cError, dot: cError),
        ]),
      ),
    ]),
  );

  Widget _filterChip(String label, String value, {required Color color, required Color textColor, Color? dot}) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cPrimaryContainer : color,
          borderRadius: BorderRadius.circular(8),
          border: selected ? null : Border.all(color: cOutlineVariant.withValues(alpha: 0.6)),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : textColor,
          )),
        ]),
      ),
    );
  }

  Widget _grid(List<_ItemData> items) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.55,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) => _itemCard(items[i]),
  );

  Widget _itemCard(_ItemData item) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.slateBorder),
      boxShadow: AppShadows.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppColors.slate100),
              Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: AppColors.slate100),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _StockBadge(label: item.units, available: item.available),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.outfit(
                        size: 14,
                        lineHeight: 20,
                        weight: FontWeight.w700,
                        color: AppColors.slate900),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SvgPicture.string(_pinSvg, width: 14, height: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.jakarta(
                              size: 12,
                              lineHeight: 16,
                              color: AppColors.slate500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _BorrowButton(
                available: item.available,
                onTap: item.available
                    ? () => context.push('/borrowing-form')
                    : null,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
    child: Column(children: [
      Container(
        width: 64, height: 64,
        decoration: const BoxDecoration(color: Color(0xFFE2E7FF), shape: BoxShape.circle),
        child: const Icon(Icons.search_off, size: 36, color: cPrimary),
      ),
      const SizedBox(height: 12),
      const Text('Item Tidak Ditemukan', style: TextStyle(
        fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600, color: cOnSurface)),
      const SizedBox(height: 4),
      const Text('Coba gunakan kata kunci lain seperti "proyektor", "kamera", atau "mic".',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cOnSurfaceVariant)),
    ]),
  );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.label, required this.available});

  final int label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.full);
    final dotColor = available ? AppColors.emerald500 : const Color(0xFFF43F5E);
    
    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppShadows.sm),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.white.fade(0.95),
              borderRadius: radius,
              border: Border.all(color: AppColors.slate100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '$label Unit',
                  style: AppTextStyles.jakarta(
                      size: 10,
                      lineHeight: 22,
                      weight: FontWeight.w700,
                      color: AppColors.slate700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BorrowButton extends StatelessWidget {
  const _BorrowButton({this.onTap, this.available = true});

  final VoidCallback? onTap;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: available ? AppColors.primaryContainer : AppColors.slate200,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                available ? 'Pinjam' : 'Booked',
                style: AppTextStyles.jakarta(
                    size: 12,
                    lineHeight: 16,
                    weight: FontWeight.w500,
                    color: available ? AppColors.white : AppColors.slate600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
