import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/screens/facility_form_screen.dart';
import 'package:lapak8new/shared/widgets/app_bottom_nav.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';

// Simpan di: lib/features/admin/screens/manage_facilities_screen.dart

class _Item {
  const _Item({
    required this.name,
    required this.category,
    required this.location,
    required this.available,
    required this.total,
    required this.placeholderIcon,
    this.imageUrl,
    this.imagePath,
  });

  final String name;
  final String category;
  final String location;
  final int available; // jumlah yang tersedia
  final int total; // jumlah keseluruhan
  final IconData placeholderIcon;
  final String? imageUrl; // isi bila sudah ada foto (URL)
  final String? imagePath; // foto lokal yang baru dipilih
}

enum _ItemFilter { all, available, unavailable }

class ManageFacilitiesScreen extends StatefulWidget {
  const ManageFacilitiesScreen({super.key});

  @override
  State<ManageFacilitiesScreen> createState() => _ManageFacilitiesScreenState();
}

class _ManageFacilitiesScreenState extends State<ManageFacilitiesScreen> {
  _ItemFilter _filter = _ItemFilter.all;
  String _query = '';

  // TODO: ganti dengan data dari backend.
  final List<_Item> _items = [
    const _Item(
      name: 'Huion Kamvas 16',
      category: 'JURUSAN DKV',
      location: 'Studio MM Lt. 2',
      available: 4,
      total: 5,
      placeholderIcon: Symbols.draw,
    ),
    const _Item(
      name: 'Sony Alpha A7 III Kit',
      category: 'AUDIO VISUAL',
      location: 'Sarpras Gedung A',
      available: 2,
      total: 4,
      placeholderIcon: Symbols.photo_camera,
    ),
    const _Item(
      name: 'Epson EB-X400',
      category: 'SARPRAS UMUM',
      location: 'Gudang Sarpras',
      available: 0,
      total: 3,
      placeholderIcon: Symbols.cast,
    ),
    const _Item(
      name: 'VR Oculus Quest 2',
      category: 'RPL / TKJ',
      location: 'Lab RPL 1',
      available: 8,
      total: 10,
      placeholderIcon: Symbols.view_in_ar,
    ),
  ];

  int get _totalAvailable => _items.fold(0, (s, i) => s + i.available);
  int get _totalBorrowed => _items.fold(0, (s, i) => s + (i.total - i.available));

  int _count(_ItemFilter f) => _items.where((i) => _matchesFilter(i, f)).length;

  bool _matchesFilter(_Item i, _ItemFilter f) {
    switch (f) {
      case _ItemFilter.all:
        return true;
      case _ItemFilter.available:
        return i.available > 0;
      case _ItemFilter.unavailable:
        return i.available == 0;
    }
  }

  List<_Item> get _visible {
    final q = _query.trim().toLowerCase();
    return _items.where((i) {
      if (!_matchesFilter(i, _filter)) return false;
      if (q.isEmpty) return true;
      return i.name.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q) ||
          i.location.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDelete(_Item item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ConfirmDialog(
        icon: Symbols.delete,
        title: 'Hapus item?',
        message: '"${item.name}" akan dihapus dari inventaris.',
        confirmText: 'Ya, Hapus',
        confirmIcon: Symbols.delete,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        onConfirm: () {
          if (!mounted) return;
          // TODO: hapus di backend
          setState(() => _items.remove(item));
        },
      ),
    );
  }

  /// [item] null = tambah barang baru, selain itu = edit.
  Future<void> _openForm([_Item? item]) async {
    final result = await context.push<FacilityFormData>(
      '/admin/items/form',
      extra: item == null
          ? null
          : FacilityFormData(
              name: item.name,
              category: item.category,
              location: item.location,
              units: item.available,
              imageUrl: item.imageUrl,
              imagePath: item.imagePath,
            ),
    );
    if (result == null || !mounted) return;

    // TODO: simpan ke backend
    setState(() {
      if (item == null) {
        _items.insert(
          0,
          _Item(
            name: result.name,
            category: result.category.isEmpty
                ? 'LAINNYA'
                : result.category.toUpperCase(),
            location: result.location,
            available: result.units,
            total: result.units,
            placeholderIcon: Symbols.inventory_2,
            imageUrl: result.imageUrl,
            imagePath: result.imagePath,
          ),
        );
      } else {
        final borrowed = item.total - item.available;
        final i = _items.indexOf(item);
        if (i == -1) return;
        _items[i] = _Item(
          name: result.name,
          category: result.category.isEmpty
              ? 'LAINNYA'
              : result.category.toUpperCase(),
          location: result.location,
          available: result.units,
          total: result.units + borrowed,
          placeholderIcon: item.placeholderIcon,
          imageUrl: result.imageUrl,
          imagePath: result.imagePath,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    const gutter = AppSpacing.mobileGutter;

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: Column(
        children: [
          const _TopBar(),
          Expanded(
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
                              'Kelola pengajuan & pengembalian sekolah',
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
                if (items.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          'Item tidak ditemukan',
                          style:
                              AppTextStyles.bodyMd(color: AppColors.slate500),
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
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: AppBottomNav.dashboardItems,
        currentIndex: 2, // Item
        onTap: (_) {},
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
// Tombol tambah, pencarian, statistik
// ---------------------------------------------------------------------------
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
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

  final _Item item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final inStock = item.available > 0;

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
                              ? '${item.available} Tersedia'
                              : '${item.available} Terisi',
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
                    item.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSm(
                      weight: FontWeight.w700,
                      color: AppColors.slate500,
                    ).copyWith(fontSize: 10, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.name,
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
                          item.location,
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
      child: Icon(item.placeholderIcon, size: 48, color: AppColors.primary),
    );

    if (item.imagePath != null) {
      return Image.file(
        File(item.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    if (item.imageUrl == null) return placeholder;

    return Image.network(
      item.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}