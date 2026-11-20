import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';

/// Keep cards readable as the browser grows, while preserving native layouts.
int productGridColumns(double width, {required bool isWeb}) {
  if (!isWeb) return 2;
  return ((width + 12) / 212).floor().clamp(2, 6);
}

/// Responsive grid of the one Dealkr product card (the same card as the home
/// sections, search and carousels). The column width comes from the space the
/// sliver is given and every row uses the card's own computed height, so the
/// card never overflows and no fixed row height needs tuning.
///
/// Padding is the caller's job (wrap in a [SliverPadding]).
class SliverDealkerProductGrid extends StatelessWidget {
  const SliverDealkerProductGrid({
    required this.products,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 14,
    this.wrapCard,
    super.key,
  });

  final List<ProductEntity> products;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  /// Lets a screen add its own entrance animation around a card.
  final Widget Function(int index, ProductEntity product, Widget card)?
      wrapCard;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (BuildContext context, SliverConstraints constraints) {
        final int columns = productGridColumns(constraints.crossAxisExtent, isWeb: kIsWeb);
        final double width =
            (constraints.crossAxisExtent - crossAxisSpacing * (columns - 1)) / columns;
        final DealkerCardSlots slots =
            DealkerCardSlots.forProducts(products, width);
        final double height = slots.heightFor(width);

        return SliverGrid.builder(
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            mainAxisExtent: height,
          ),
          itemBuilder: (BuildContext context, int index) {
            final ProductEntity product = products[index];
            final Widget card = DealkerProductCard(
              product: product,
              width: width,
              nameLines: slots.nameLines,
              showSoldRow: slots.showSold,
              showRatingRow: slots.showRating,
              onTap: () => context.push('/product/${product.id}'),
              onOptionsTap: product.hasMultipleOptions
                  ? () => showProductOptionsSheet(context, product)
                  : null,
            );
            return wrapCard == null ? card : wrapCard!(index, product, card);
          },
        );
      },
    );
  }
}
