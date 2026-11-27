import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/screens/facility_form_screen.dart';
import 'package:lapak8new/features/facilities/models/facility.dart';
import 'package:lapak8new/features/facilities/services/facility_service.dart';
import 'package:lapak8new/shared/widgets/app_bottom_nav.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';

// Simpan di: lib/features/admin/screens/manage_facilities_screen.dart

enum _ItemFilter { all, available, unavailable }

class ManageFacilitiesScreen extends StatefulWidget {
  const ManageFacilitiesScreen({super.key});

  @override
  State<ManageFacilitiesScreen> createState() => _ManageFacilitiesScreenState();
}

class _ManageFacilitiesScreenState extends State<ManageFacilitiesScreen> {
  _ItemFilter _filter = _ItemFilter.all;
  String _query = '';
  List<Facility> _items = const [];
  List<LokasiItem> _locations = const [];
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
      final results = await Future.wait([
        facilityService.fetchFacilities(),
        facilityService.fetchLocations(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Facility>;
        _locations = results[1] as List<LokasiItem>;
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

  int get _totalAvailable =>
      _items.fold(0, (s, i) => s + (i.isAvailable ? i.unitTersedia : 0));
  int get _totalBorrowed => _items.fold(0, (s, i) => s + i.unitDipinjam);

  int _count(_ItemFilter f) => _items.where((i) => _matchesFilter(i, f)).length;

  bool _matchesFilter(Facility i, _ItemFilter f) {
    switch (f) {
      case _ItemFilter.all:
        return true;
      case _ItemFilter.available:
        return i.isAvailable;
      case _ItemFilter.unavailable:
        return !i.isAvailable;
    }
  }

  List<Facility> get _visible {
    final q = _query.trim().toLowerCase();
    return _items.where((i) {
      if (!_matchesFilter(i, _filter)) return false;
      if (q.isEmpty) return true;
      return i.nama.toLowerCase().contains(q) ||
          i.kategori.toLowerCase().contains(q) ||
          i.lokasiNama.toLowerCase().contains(q);
    }).toList();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }

  Future<void> _confirmDelete(Facility item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ConfirmDialog(
        icon: Symbols.delete,
        title: 'Hapus item?',
        message: '"${item.nama}" akan dihapus dari inventaris.',
        confirmText: 'Ya, Hapus',
        confirmIcon: Symbols.delete,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        onConfirm: () => _deleteItem(item),
      ),
    );
  }

  Future<void> _deleteItem(Facility item) async {
    try {
      await facilityService.deleteFacility(item.id);
      if (!mounted) return;
      _showSnack('Item "${item.nama}" berhasil dihapus.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    }
  }

  /// [item] null = tambah barang baru, selain itu = edit.
  Future<void> _openForm([Facility? item]) async {
    final result = await FacilityFormScreen.show(
      context,
      locations: _locations,
      initial: item == null
          ? null
          : FacilityFormData(
              name: item.nama,
              category: item.kategori == 'SARPRAS UMUM' ? '' : item.kategori,
              location: item.lokasiNama,
              locationId: item.lokasiId,
              units: item.totalUnit,
              imageUrl: item.fotoUrl,
            ),
    );
    if (result == null || !mounted) return;

    try {
      if (item == null) {
        await facilityService.createFacility(
          nama: result.name,
          kategori: result.category,
          lokasiId: result.locationId,
          lokasiNama: result.location,
          totalUnit: result.units,
          imageBytes: result.imageBytes,
          imageFileName: result.imageFileName,
        );
        if (!mounted) return;
        _showSnack('Item "${result.name}" berhasil ditambahkan.');
      } else {
        await facilityService.updateFacility(
          item.id,
          nama: result.name,
          kategori: result.category,
          lokasiId: result.locationId,
          lokasiNama: result.location,
          totalUnit: result.units,
          imageBytes: result.imageBytes,
          imageFileName: result.imageFileName,
          existingFotoUrl: result.imageUrl,
          removePhoto: result.removePhoto,
        );
        if (!mounted) return;
        _showSnack('Perubahan item "${result.name}" berhasil disimpan.');
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    const gutter = AppSpacing.mobileGutter;

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      bottomNavigationBar: const AdminBottomNav(currentIndex: 3),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  gutter, AppSpacing.md, gutter, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Data Barang',
                            style: AppTextStyles.headlineMd(
                                color: AppColors.onSurface)),
                        const SizedBox(height: 2),
                        Text(
                          'Kelola inventaris barang & fasilitas sekolah',
                          style: AppTextStyles.bodyMd(
                              color: AppColors.slate600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AddButton(onPressed: () => _openForm()),
                  const SizedBox(height: 16),
                  _SearchField(
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Siap',
                          value: _totalAvailable,
                          color: AppColors.onTertiaryFixedVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Dipinjam',
                          value: _totalBorrowed,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: gutter, vertical: 32),
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
                ),
              )
            else if (items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'Item tidak ditemukan',
                      style: AppTextStyles.bodyMd(color: AppColors.slate500),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: gutter),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 282,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ItemCard(
                      item: items[i],
                      onEdit: () => _openForm(items[i]),
                      onDelete: () => _confirmDelete(items[i]),
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.verified,
                        size: 16, color: AppColors.slate500),
                    const SizedBox(width: 6),
                    Text(
                      'Sinkronisasi Realtime SIM-Sarpras',
                      style: AppTextStyles.labelMd(
                        weight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final entries = <(String, _ItemFilter)>[
      ('Semua (${_count(_ItemFilter.all)})', _ItemFilter.all),
      ('Tersedia', _ItemFilter.available),
      ('Tidak tersedia', _ItemFilter.unavailable),
    ];
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              flex: i == 2 ? 3 : 2,
              child: GestureDetector(
                onTap: () => setState(() => _filter = entries[i].$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _filter == entries[i].$2
                        ? AppColors.primary
                        : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow:
                        _filter == entries[i].$2 ? null : AppShadows.sm,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      entries[i].$1,
                      style: AppTextStyles.labelMd(
                        weight: FontWeight.w700,
                        color: _filter == entries[i].$2
                            ? AppColors.onPrimary
                            : AppColors.onSurface,
                      ),
                    ),
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

// ---------------------------------------------------------------------------
// Tombol tambah, pencarian, statistik
// ---------------------------------------------------------------------------
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Symbols.add_circle, size: 22),
        label: Text(
          'Tambah Item Baru',
          style: AppTextStyles.labelLg(
            weight: FontWeight.w700,
            color: AppColors.onPrimary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
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
          hintText: 'Cari item, kategori, atau lokasi...',
          hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
          prefixIcon: const Icon(Symbols.search, color: AppColors.slate600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelMd(
                  weight: FontWeight.w600,
                  color: AppColors.slate600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: AppTextStyles.headlineMd(color: color)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu item
// ---------------------------------------------------------------------------
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final Facility item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final inStock = item.isAvailable;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto + badge
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImage(),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: inStock
                          ? AppColors.tertiaryFixed
                          : AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: inStock
                                ? AppColors.emerald500
                                : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          inStock
                              ? '${item.unitTersedia} Tersedia'
                              : '${item.unitTersedia} Terisi',
                          style: AppTextStyles.labelSm(
                            weight: FontWeight.w700,
                            color: inStock
                                ? AppColors.onTertiaryFixedVariant
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.kategori,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSm(
                      weight: FontWeight.w700,
                      color: AppColors.slate500,
                    ).copyWith(fontSize: 10, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMd(
                      weight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Symbols.location_on,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item.lokasiNama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySm(
                            weight: FontWeight.w500,
                            color: AppColors.slate600,
                          ).copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Symbols.edit_note, size: 18),
                            label: Text(
                              'Edit',
                              style: AppTextStyles.labelMd(
                                weight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryFixed,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Material(
                        color: AppColors.surfaceContainerLow,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onDelete,
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Symbols.delete,
                                size: 18, color: AppColors.slate600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final placeholder = Container(
      color: AppColors.primaryFixed.fade(0.6),
      alignment: Alignment.center,
      child: const Icon(Symbols.inventory_2, size: 48, color: AppColors.primary),
    );

    if (item.fotoUrl == null || item.fotoUrl!.isEmpty) return placeholder;

    return Image.network(
      item.fotoUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}
