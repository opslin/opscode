import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/search_tokens.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/presentation/providers/product_detail_provider.dart';
import 'package:dealker_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:dealker_app/features/search/domain/search_filters.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';
import 'package:dealker_app/shared/widgets/dealker_product_grid.dart';
import 'package:dealker_app/shared/widgets/web_storefront_footer.dart';

const String _font = 'PlusJakartaSans';

/// Results page body: "128 results for “iphone 15”", the Sort / Filter / In stock /
/// Brand / Price chips, and a two-column grid of the same product card the home
/// page uses.
class SearchResultsView extends StatefulWidget {
  const SearchResultsView({
    required this.query,
    required this.products,
    required this.count,
    required this.sort,
    required this.filters,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMoreFailed,
    required this.onLoadMore,
    required this.onSort,
    required this.onFilter,
    required this.onToggleInStock,
    super.key,
  });

  final String query;
  final List<ProductEntity> products;

  /// Number shown in the "N results" label.
  final int count;
  final SearchSort sort;
  final SearchFilters filters;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;
  final VoidCallback onLoadMore;
  final VoidCallback onSort;
  final VoidCallback onFilter;
  final VoidCallback onToggleInStock;

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    // A first page may fit entirely in a wide viewport, leaving no scroll
    // event to trigger pagination.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchResultsView old) {
    super.didUpdateWidget(old);
    // A short list (few matches after filtering) never scrolls: ask for more.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  void _maybeLoadMore() {
    if (!mounted || !widget.hasMore || widget.loadingMore) return;
    if (widget.loadMoreFailed) return;
    if (!_scroll.hasClients) return;
    final ScrollPosition p = _scroll.position;
    if (p.maxScrollExtent - p.pixels < 600) widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) {
    final SearchFilters f = widget.filters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: Text(
            '${widget.count} result${widget.count == 1 ? '' : 's'} for “${widget.query}”',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: SearchTokens.grey,
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              _Pill(
                label: widget.sort.pillLabel,
                trailing: PhosphorIconsBold.caretDown,
                filled: true,
                onTap: widget.onSort,
              ),
              _Pill(
                label: 'Filter',
                leading: PhosphorIconsRegular.slidersHorizontal,
                badge: f.activeCount - (f.inStockOnly ? 1 : 0),
                onTap: widget.onFilter,
              ),
              _Pill(
                label: 'In stock',
                selected: f.inStockOnly,
                onTap: widget.onToggleInStock,
              ),
              _Pill(
                label:
                    f.brands.isEmpty ? 'Brand' : 'Brand (${f.brands.length})',
                trailing: PhosphorIconsBold.caretDown,
                selected: f.brands.isNotEmpty,
                onTap: widget.onFilter,
              ),
              _Pill(
                label: 'Price',
                trailing: PhosphorIconsBold.caretDown,
                selected: f.hasPrice,
                onTap: widget.onFilter,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ColoredBox(
            color: SearchTokens.resultsCanvas,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                const double side = 14;
                const double gap = 12;
                final double w = (c.maxWidth - side * 2 - gap) / 2;
                return CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(side, 14, side, 0),
                      sliver: kIsWeb && c.maxWidth >= 700
                          ? SliverDealkerProductGrid(products: widget.products)
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int i) {
                                  final ProductEntity left =
                                      widget.products[i * 2];
                                  final int r = i * 2 + 1;
                                  final ProductEntity? right =
                                      r < widget.products.length
                                          ? widget.products[r]
                                          : null;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _ProductRow(
                                      key: ValueKey<String>(
                                        '${left.id}|${right?.id ?? ''}',
                                      ),
                                      left: left,
                                      right: right,
                                      width: w,
                                      gap: gap,
                                    ),
                                  );
                                },
                                childCount: (widget.products.length + 1) ~/ 2,
                              ),
                            ),
                    ),
                    SliverToBoxAdapter(child: _footer()),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    if (widget.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: SearchTokens.accent,
            ),
          ),
        ),
      );
    }
    if (widget.loadMoreFailed && widget.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: TextButton(
            onPressed: widget.onLoadMore,
            child: const Text(
              'Couldn’t load more · Tap to retry',
              style: TextStyle(
                fontFamily: _font,
                fontWeight: FontWeight.w700,
                color: SearchTokens.accent,
              ),
            ),
          ),
        ),
      );
    }
    if (kIsWeb && MediaQuery.sizeOf(context).width >= 700 && !widget.hasMore) {
      return WebStorefrontFooter(onNavigate: (path) => context.go(path));
    }
    return const SizedBox(height: 28);
  }
}

/// Two Home product cards side by side. The seller ("Sold by") comes with the
/// product when the search API sends it; otherwise it is read from the product's
/// detail (cached). Rows nobody in the pair has data for (rating, seller) are
/// dropped and the name block shrinks to one line when both names fit, so the
/// cards carry no empty gaps and both always have the same height.
class _ProductRow extends ConsumerWidget {
  const _ProductRow({
    required this.left,
    required this.right,
    required this.width,
    required this.gap,
    super.key,
  });

  final ProductEntity left;
  final ProductEntity? right;
  final double width;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool pendingSeller = false;
    ProductEntity withSeller(ProductEntity p) {
      if (DealkerProductCard.hasSeller(p)) return p;
      final AsyncValue<ProductEntity> detail =
          ref.watch(productDetailProvider(p.id));
      if (detail.isLoading) pendingSeller = true;
      final String? seller = detail.asData?.value.soldBy;
      return seller != null && seller.trim().isNotEmpty
          ? p.copyWith(soldBy: seller.trim())
          : p;
    }

    final ProductEntity a = withSeller(left);
    final ProductEntity? b = right == null ? null : withSeller(right!);
    final List<ProductEntity> both = <ProductEntity>[a, if (b != null) b];

    // Keep the seller row while a seller is still being fetched (no height jump).
    final bool showSold =
        pendingSeller || both.any(DealkerProductCard.hasSeller);
    final bool showRating = both.any((ProductEntity p) => p.hasRating);
    final int lines = both
        .map((ProductEntity p) => DealkerProductCard.lineCountOf(p, width))
        .reduce((int x, int y) => x > y ? x : y);
    final double height = DealkerProductCard.heightFor(
      width,
      nameLines: lines,
      showSold: showSold,
      showRating: showRating,
    );

    Widget card(ProductEntity p) => SizedBox(
          width: width,
          height: height,
          child: DealkerProductCard(
            product: p,
            width: width,
            nameLines: lines,
            showSoldRow: showSold,
            showRatingRow: showRating,
            onTap: () => context.push('/product/${p.id}'),
            onOptionsTap: p.hasMultipleOptions
                ? () => showProductOptionsSheet(context, p)
                : null,
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        card(a),
        SizedBox(width: gap),
        if (b != null) card(b) else SizedBox(width: width),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.selected = false,
    this.leading,
    this.trailing,
    this.badge = 0,
  });

  final String label;
  final VoidCallback onTap;

  /// The solid blue Sort pill.
  final bool filled;
  final bool selected;
  final PhosphorIconData? leading;
  final PhosphorIconData? trailing;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final bool active = selected || badge > 0;
    final Color fg = filled
        ? Colors.white
        : (active ? SearchTokens.accent : SearchTokens.ink);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: filled
                    ? SearchTokens.accent
                    : (active ? SearchTokens.accentSoft : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: filled
                      ? SearchTokens.accent
                      : (active
                          ? SearchTokens.accent
                          : SearchTokens.chipBorder),
                  width: active && !filled ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    PhosphorIcon(leading!, size: 17, color: fg),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 6),
                    PhosphorIcon(trailing!, size: 12, color: fg),
                  ],
                ],
              ),
            ),
            if (badge > 0)
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: SearchTokens.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
