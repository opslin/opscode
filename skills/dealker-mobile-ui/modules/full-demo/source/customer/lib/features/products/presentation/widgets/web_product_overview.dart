import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/marketplace_product_box.dart';

/// Product information and purchasing controls arranged for a wide viewport.
class WebProductOverview extends StatefulWidget {
  const WebProductOverview(
      {required this.product,
      required this.onAdd,
      required this.onBuy,
      required this.onWishlist,
      this.onExchange,
      this.exchangeMaxValue = 0,
      this.isWishlisted = false,
      super.key});
  final ProductEntity product;
  final VoidCallback onAdd;
  final VoidCallback onBuy;
  final VoidCallback onWishlist;
  final VoidCallback? onExchange;
  final double exchangeMaxValue;
  final bool isWishlisted;

  @override
  State<WebProductOverview> createState() => _WebProductOverviewState();
}

class _WebProductOverviewState extends State<WebProductOverview> {
  int selected = 0;

  @override
  void didUpdateWidget(covariant WebProductOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) selected = 0;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = p.images.where((image) => image.trim().isNotEmpty).toList();
    if (images.isEmpty && (p.thumbnailUrl?.isNotEmpty ?? false))
      images.add(p.thumbnailUrl!);
    final seller = p.soldBy ?? p.vendorName;
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 760;
      final gallery = Column(children: [
        Container(
          height: stacked ? 320 : 420,
          width: double.infinity,
          decoration: BoxDecoration(
              color: AppColors.bgCard,
              border: Border.all(color: AppColors.borderLight),
              borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(24),
          child: images.isEmpty
              ? const Icon(Icons.image_outlined,
                  size: 64, color: AppColors.textTertiary)
              : AppImage(
                  imageUrl: images[selected.clamp(0, images.length - 1)],
                  memCacheWidth: 1000,
                  memCacheHeight: 1000,
                  fit: BoxFit.contain),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => InkWell(
                  onTap: () => setState(() => selected = index),
                  child: Container(
                      width: 68,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          border: Border.all(
                              color: selected == index
                                  ? AppColors.accentYellowDark
                                  : AppColors.borderLight,
                              width: selected == index ? 2 : 1),
                          borderRadius: BorderRadius.circular(8)),
                      child: AppImage(
                          imageUrl: images[index],
                          memCacheWidth: 150,
                          memCacheHeight: 150,
                          fit: BoxFit.contain)),
                ),
              )),
        ],
      ]);
      final info = Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(p.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: widget.onWishlist,
                tooltip: widget.isWishlisted
                    ? 'Remove from wishlist'
                    : 'Add to wishlist',
                icon: Icon(
                    widget.isWishlisted
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.isWishlisted ? AppColors.errorRed : null)),
          ]),
          if (p.hasRating) ...[
            const SizedBox(height: 10),
            Text(
                '★ ${p.avgRating.toStringAsFixed(1)}  (${p.ratingCount} reviews)',
                style: const TextStyle(color: AppColors.textSecondary))
          ],
          const SizedBox(height: 20),
          Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(MarketplaceProductBox.inr(p.effectivePrice),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                if (p.isOnSale)
                  Text(MarketplaceProductBox.inr(p.price),
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.lineThrough)),
              ]),
          if (seller != null && seller.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Sold by $seller',
                style: const TextStyle(color: AppColors.textSecondary))
          ],
          const SizedBox(height: 16),
          Text(p.inStock ? 'In stock' : 'Out of stock',
              style: TextStyle(
                  color:
                      p.inStock ? AppColors.successGreen : AppColors.errorRed,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.tonalIcon(
                onPressed: p.inStock ? widget.onAdd : null,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Add to cart')),
            FilledButton(
                onPressed: p.inStock ? widget.onBuy : null,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentYellow,
                    foregroundColor: AppColors.textPrimary),
                child: const Text('Buy now')),
          ]),
          if (widget.onExchange != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Exchange your old device',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                        widget.exchangeMaxValue > 0
                            ? 'Estimated value up to ${MarketplaceProductBox.inr(widget.exchangeMaxValue)}'
                            : 'Get an estimate for your old phone',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: widget.onExchange,
                        icon: const Icon(Icons.currency_exchange),
                        label: const Text('Check exchange value')),
                  ]),
            ),
          ],
        ]),
      );
      if (stacked)
        return Column(children: [gallery, const SizedBox(height: 16), info]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: gallery),
        const SizedBox(width: 24),
        Expanded(flex: 6, child: info)
      ]);
    });
  }
}
