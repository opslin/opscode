import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/search_tokens.dart';
import 'package:dealker_app/core/utils/extensions/double_extensions.dart';
import 'package:dealker_app/features/categories/domain/entities/category_entity.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/search/domain/search_filters.dart';
import 'package:dealker_app/features/search/presentation/widgets/search_entry_view.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';
import 'package:dealker_app/shared/widgets/skeleton_loader.dart';

const String _font = 'PlusJakartaSans';

/// What shows while the customer is typing: phrases to complete the query, the
/// best matching products and the categories they sit in. Everything comes from
/// the live search of the typed text — nothing is hard-coded.
class SearchSuggestView extends StatelessWidget {
  const SearchSuggestView({
    required this.query,
    required this.loading,
    required this.products,
    required this.total,
    required this.categories,
    required this.onPick,
    required this.onFill,
    required this.onProduct,
    required this.onViewAll,
    required this.onCategory,
    super.key,
  });

  final String query;
  final bool loading;
  final List<ProductEntity> products;
  final int total;

  /// Categories to link to: the ones of the matching products.
  final List<({CategoryEntity category, int count})> categories;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onFill;
  final ValueChanged<ProductEntity> onProduct;
  final VoidCallback onViewAll;
  final ValueChanged<CategoryEntity> onCategory;

  @override
  Widget build(BuildContext context) {
    final List<String> phrases = querySuggestions(query, products);
    // The typed text itself is always the first suggestion.
    final List<String> rows = <String>[
      query.trim(),
      ...phrases.where((String p) => p != query.trim().toLowerCase()),
    ].take(6).toList();
    final List<ProductEntity> top = products.take(3).toList();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: <Widget>[
        for (int i = 0; i < rows.length; i++)
          SearchSuggestionRow(
            text: rows[i],
            typed: query,
            showDivider: i != rows.length - 1,
            onTap: () => onPick(rows[i]),
            onFill: () => onFill(rows[i]),
          ),
        if (loading && top.isEmpty) ...<Widget>[
          const SizedBox(height: 18),
          const _SuggestSkeleton(),
        ],
        if (top.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          SearchSectionHeading(
            title: 'Products',
            action: 'View all',
            onAction: onViewAll,
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < top.length; i++)
            _ProductRow(
              product: top[i],
              showDivider: i != top.length - 1,
              onTap: () => onProduct(top[i]),
            ),
        ],
        if (categories.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          const SearchSectionHeading(title: 'Categories'),
          const SizedBox(height: 2),
          for (int i = 0; i < categories.length; i++)
            _CategoryRow(
              query: query.trim(),
              category: categories[i].category,
              showDivider: i != categories.length - 1,
              onTap: () => onCategory(categories[i].category),
            ),
        ],
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.showDivider,
    required this.onTap,
  });

  final ProductEntity product;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ({String name, String? variant}) split =
        splitNameAndVariant(product.name);
    final String? variant = (product.optionLabel ?? '').trim().isNotEmpty
        ? product.optionLabel!.trim()
        : split.variant;
    final String? imageUrl = product.thumbnailUrl?.isNotEmpty == true
        ? product.thumbnailUrl
        : (product.images.isNotEmpty ? product.images.first : null);
    final int? off = product.isOnSale && product.price > 0
        ? (((product.price - product.salePrice!) / product.price) * 100).round()
        : null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: SearchTokens.divider))
              : null,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: SearchTokens.thumbBg,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(5),
              child: imageUrl == null
                  ? const SizedBox.shrink()
                  : AppImage(
                      imageUrl: imageUrl,
                      memCacheWidth: 200,
                      memCacheHeight: 200,
                      fit: BoxFit.contain,
                      placeholder: const SizedBox.shrink(),
                      errorWidget: const SizedBox.shrink(),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    split.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: SearchTokens.ink,
                    ),
                  ),
                  if (variant != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      variant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: SearchTokens.grey,
                      ),
                    ),
                  ],
                  if (product.hasRating) ...<Widget>[
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Text(
                          product.avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: SearchTokens.green,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const PhosphorIcon(
                          PhosphorIconsFill.star,
                          size: 12,
                          color: SearchTokens.green,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '(${_compact(product.ratingCount)})',
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: SearchTokens.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: <Widget>[
                      Text(
                        product.effectivePrice.round().toInrCurrency,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: SearchTokens.ink,
                        ),
                      ),
                      if (product.isOnSale)
                        Text(
                          product.price.round().toInrCurrency,
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: SearchTokens.greyLight,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      if (off != null && off > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SearchTokens.greenSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$off% OFF',
                            style: const TextStyle(
                              fontFamily: _font,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: SearchTokens.green,
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
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000) {
      final double k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return '$n';
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.query,
    required this.category,
    required this.showDivider,
    required this.onTap,
  });

  final String query;
  final CategoryEntity category;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: SearchTokens.divider))
              : null,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: SearchTokens.thumbBg,
                borderRadius: BorderRadius.circular(9),
              ),
              clipBehavior: Clip.antiAlias,
              child: (category.imageUrl ?? '').isEmpty
                  ? const Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.squaresFour,
                        size: 18,
                        color: SearchTokens.grey,
                      ),
                    )
                  : AppImage(
                      imageUrl: category.imageUrl!,
                      memCacheWidth: 120,
                      memCacheHeight: 120,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: query,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: SearchTokens.ink,
                      ),
                    ),
                    TextSpan(
                      text: ' in ${category.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: SearchTokens.grey,
                      ),
                    ),
                  ],
                  style: const TextStyle(fontFamily: _font, fontSize: 14.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              size: 18,
              color: SearchTokens.ink,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestSkeleton extends StatelessWidget {
  const _SuggestSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: <Widget>[
                SkeletonLoader(width: 64, height: 64, radius: 10),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SkeletonLoader(height: 14, radius: 6),
                      SizedBox(height: 8),
                      SkeletonLoader(width: 110, height: 12, radius: 6),
                      SizedBox(height: 8),
                      SkeletonLoader(width: 80, height: 14, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
