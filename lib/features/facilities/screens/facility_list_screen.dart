import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/facility.dart';
import '../services/facility_service.dart';

class FacilityListScreen extends StatefulWidget {
  const FacilityListScreen({super.key});
  @override
  State<FacilityListScreen> createState() => _FacilityListScreenState();
}

/// Ikon pin lokasi (heroicons outline, stroke 2) persis seperti di Dashboard.
const _pinSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#94A3B8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<path d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
<path d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
</svg>
''';

class _FacilityListScreenState extends State<FacilityListScreen> {
  // ===== Palette (sesuai desain) =====
  static const cSurfaceLowest = Color(0xFFFFFFFF);
  static const cSurfaceContainer = Color(0xFFEAEDFF);
  static const cOnSurface = Color(0xFF131B2E);
  static const cOnSurfaceVariant = Color(0xFF434655);
  static const cPrimary = Color(0xFF0037B0);
  static const cSecondary = Color(0xFF505F76);
  static const cError = Color(0xFFBA1A1A);
  static const cOutline = Color(0xFF747686);

  final _searchCtrl = TextEditingController();
  String _filter = 'all';
  String _query = '';
  List<Facility> _items = const [];
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
      final list = await facilityService.fetchFacilities(onlyActive: true);
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

  List<Facility> get _filtered => _items.where((item) {
    final q = _query.toLowerCase();
    final okQ =
        q.isEmpty ||
        item.nama.toLowerCase().contains(q) ||
        item.lokasiNama.toLowerCase().contains(q) ||
        item.kategori.toLowerCase().contains(q);
    final okF =
        _filter == 'all' ||
        (_filter == 'available' && item.isAvailable) ||
        (_filter == 'unavailable' && !item.isAvailable);
    return okQ && okF;
  }).toList();

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _searchBar(),
                    _titleAndFilters(filtered.length),
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
                      _grid(filtered),
                  ],
                ),
              ),
            ),
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
          const Icon(Icons.search, size: 20, color: cOutline),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                color: cOnSurface,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Cari item atau barang...',
                hintStyle: TextStyle(fontSize: 12, color: cOnSurfaceVariant),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              onPressed: _clearSearch,
              icon: const Icon(Icons.close, size: 18, color: cOutline),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    ),
  );

  Widget _titleAndFilters(int count) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Daftar Item',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cOnSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cSurfaceContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count Item',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cPrimary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('Semua', 'all'),
              const SizedBox(width: 8),
              _filterChip('Tersedia', 'available'),
              const SizedBox(width: 8),
              _filterChip('Tidak tersedia', 'unavailable'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
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

  Widget _grid(List<Facility> items) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _itemCard(left)),
            const SizedBox(width: 12),
            Expanded(
              child: right == null ? const SizedBox.shrink() : _itemCard(right),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  Widget _itemCard(Facility item) {
    final available = item.isAvailable;
    final imgUrl = item.fotoUrl;

    return Container(
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
                const ColoredBox(
                  color: AppColors.slate100,
                  child: Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 36,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
                if (imgUrl != null && imgUrl.isNotEmpty)
                  Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: AppColors.slate100,
                      child: Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 36,
                          color: AppColors.slate400,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _StockBadge(
                    label: item.unitTersedia,
                    available: available,
                  ),
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
                      item.kategori,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.jakarta(
                        size: 10,
                        lineHeight: 14,
                        weight: FontWeight.w700,
                        color: AppColors.slate500,
                      ).copyWith(letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.outfit(
                        size: 14,
                        lineHeight: 20,
                        weight: FontWeight.w700,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SvgPicture.string(_pinSvg, width: 14, height: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.lokasiNama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.jakarta(
                              size: 12,
                              lineHeight: 16,
                              color: AppColors.slate500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _BorrowButton(
                  available: available,
                  onTap: available
                      ? () => context.push('/borrowing-form', extra: item.id)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFE2E7FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.search_off, size: 36, color: cPrimary),
        ),
        const SizedBox(height: 12),
        const Text(
          'Item Tidak Ditemukan',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cOnSurface,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Coba gunakan kata kunci lain seperti "proyektor", "kamera", atau "mic".',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cOnSurfaceVariant),
        ),
      ],
    ),
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
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$label Unit',
                  style: AppTextStyles.jakarta(
                    size: 10,
                    lineHeight: 22,
                    weight: FontWeight.w700,
                    color: AppColors.slate700,
                  ),
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
                'Pinjam',
                style: AppTextStyles.jakarta(
                  size: 12,
                  lineHeight: 16,
                  weight: FontWeight.w500,
                  color: available ? AppColors.white : AppColors.slate600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
