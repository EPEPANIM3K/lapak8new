import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';

/// Data ringan untuk kartu populer.
/// TODO: ganti dengan model `Facility` dari features/facilities/models.
class PopularItem {
  const PopularItem({
    required this.name,
    required this.location,
    required this.stockLabel, // "2 Unit"
    required this.imageUrl,
  });

  final String name;
  final String location;
  final String stockLabel;
  final String imageUrl;
}

/// Ikon pin lokasi (heroicons outline, stroke 2) persis seperti di HTML.
const _pinSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#94A3B8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<path d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
<path d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
</svg>
''';

/// Bagian "Item Populer" (grid 2 kolom).
class PopularItemsSection extends StatelessWidget {
  const PopularItemsSection({
    super.key,
    required this.items,
    this.onSeeAllTap,
    this.onBorrowTap,
  });

  final List<PopularItem> items;
  final VoidCallback? onSeeAllTap;
  final ValueChanged<PopularItem>? onBorrowTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.sm));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Expanded(
                  child: _ItemCard(
                      item: left, onBorrow: () => onBorrowTap?.call(left))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : _ItemCard(
                        item: right, onBorrow: () => onBorrowTap?.call(right)),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item Populer',
                        style: AppTextStyles.headlineSm(
                            color: AppColors.onSurface)),
                    Text('Sering dipinjam siswa untuk praktikum & ekskul',
                        style: AppTextStyles.bodySm(
                            color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onSeeAllTap,
                child: Text('Lihat Semua',
                    style: AppTextStyles.labelSm(
                        weight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...rows,
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, this.onBorrow});

  final PopularItem item;
  final VoidCallback? onBorrow;

  @override
  Widget build(BuildContext context) {
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
          // aspect-square + badge stok
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
                  child: _StockBadge(label: item.stockLabel),
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
                        // font-['Outfit'] font-bold text-sm (14/20)
                        style: AppTextStyles.outfit(
                            size: 14,
                            lineHeight: 20,
                            weight: FontWeight.w700,
                            color: AppColors.slate900),
                      ),
                      const SizedBox(height: 4), // mb-1
                      Row(
                        children: [
                          SvgPicture.string(_pinSvg, width: 14, height: 14),
                          const SizedBox(width: 6), // gap-1.5
                          Expanded(
                            child: Text(
                              item.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // text-xs (12/16) font-normal slate-500
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
                  const SizedBox(height: 14), // mt-3.5
                  _BorrowButton(onTap: onBorrow),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.full);
    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppShadows.sm),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), // backdrop-blur-sm
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
                  decoration: const BoxDecoration(
                      color: AppColors.emerald500, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                // text-[10px] font-bold, line-height mewarisi body (22px)
                Text(
                  label,
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
  const _BorrowButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryContainer, // #1d4ed8
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => context.push('/borrowing-form'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10), // py-2.5
            child: Center(
              child: Text(
                'Pinjam',
                style: AppTextStyles.jakarta(
                    size: 12,
                    lineHeight: 16,
                    weight: FontWeight.w500,
                    color: AppColors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
