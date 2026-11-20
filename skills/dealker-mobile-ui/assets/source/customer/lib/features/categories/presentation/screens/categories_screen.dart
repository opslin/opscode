import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart'
    show AU, CartArt, CartArtImage, jakarta, dm;
import 'package:dealker_app/features/categories/presentation/widgets/category_art.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';
import 'package:dealker_app/shared/widgets/dealker_product_grid.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/core/theme/app_dimensions.dart';
import 'package:dealker_app/core/theme/app_text_styles.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/categories/domain/entities/category_entity.dart';
import 'package:dealker_app/features/categories/presentation/providers/category_provider.dart';
import 'package:dealker_app/features/products/presentation/providers/product_list_provider.dart';
import 'package:dealker_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/empty_state.dart';
import 'package:dealker_app/shared/widgets/error_state.dart';
import 'package:dealker_app/shared/widgets/skeleton_loader.dart';
import 'package:dealker_app/shared/widgets/web_storefront_footer.dart';
import 'package:dealker_app/shared/widgets/wide_storefront_scope.dart';

/// Categories accent: Dealkr navy on a cool-white canvas.
const Color _accent = AppColors.brandNavy;
const Color _accentSurface = Color(0xFFE8EEFB);

/// The product grid is 2 columns inside the pane to the right of the
/// 92.w category rail, with 14.w side padding and a 12.w gap between columns.

/// Mirrors ProductCard's grid-style layout (image = 84% of card width, plus
/// a roughly fixed footer for the unit/ADD row, price, name, and rating) so
/// the grid row stays tall enough for the real column width instead of a
/// constant tuned for phone-narrow columns. A fixed `mainAxisExtent` can't
/// work across both phone and tablet: iPad's 2-column grid is far wider per
/// column, so the width-proportional image alone was blowing past the old
/// fixed 256.h row height.
double _gridRowExtent(double columnWidth) =>
    DealkerProductCard.heightFor(columnWidth);

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String? _selectedParentId;
  String? _selectedFeedId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryCollectionProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const _CategoriesHeader(),
            Expanded(
              child: categoriesAsync.when(
                loading: _buildLoading,
                error: (error, stackTrace) => ErrorState(
                  message: 'Categories could not be loaded.',
                  onRetry: () => ref.invalidate(categoryCollectionProvider),
                ),
                data: _buildData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildData(List<CategoryEntity> categories) {
    if (categories.isEmpty) {
      return const EmptyState(
        title: 'No categories available',
        message: 'Categories will show up here once the API returns them.',
      );
    }

    final sorted = <CategoryEntity>[
      // BUNDLE categories are promo-only groupings surfaced via a banner
      // deep-link — never shown in normal category browsing.
      ...categories
          .where((category) => category.isActive && !category.isBundle),
    ]..sort((a, b) {
        final sortOrder = a.sortOrder.compareTo(b.sortOrder);
        if (sortOrder != 0) {
          return sortOrder;
        }
        return a.name.compareTo(b.name);
      });

    if (sorted.isEmpty) {
      return const EmptyState(
        title: 'No categories available',
        message: 'Categories will show up here once they are available.',
      );
    }

    final parents =
        sorted.where((category) => category.isParent).toList(growable: false);
    final rootCategories = parents.isNotEmpty ? parents : sorted;
    _selectedParentId ??= rootCategories.first.id;

    final selectedParent = rootCategories.firstWhere(
      (category) => category.id == _selectedParentId,
      orElse: () => rootCategories.first,
    );
    final childCategories = sorted
        .where((category) => category.parentId == selectedParent.id)
        .toList(growable: false);

    final validFeedIds = <String>{
      selectedParent.id,
      ...childCategories.map((category) => category.id),
    };
    final selectedFeedId = validFeedIds.contains(_selectedFeedId)
        ? _selectedFeedId!
        : selectedParent.id;
    _selectedFeedId = selectedFeedId;

    final highlightedCategory = selectedFeedId == selectedParent.id
        ? selectedParent
        : childCategories.firstWhere(
            (category) => category.id == selectedFeedId,
            orElse: () => selectedParent,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CategoryRail(
          categories: rootCategories,
          selectedCategoryId: selectedParent.id,
          onSelect: (category) {
            setState(() {
              _selectedParentId = category.id;
              _selectedFeedId = category.id;
            });
          },
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _CategoryProductPane(
              key: ValueKey<String>('${selectedParent.id}-$selectedFeedId'),
              selectedParent: selectedParent,
              highlightedCategory: highlightedCategory,
              childCategories: childCategories,
              selectedFeedId: selectedFeedId,
              onSelectChild: (categoryId) {
                setState(() {
                  _selectedFeedId = categoryId;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 98.w,
          color: const Color(0xFFF5F7FC),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < 8; i++) ...<Widget>[
                const SkeletonLoader(height: 64, radius: 16),
                Gap(12.h),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 24.h),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    productGridColumns(constraints.maxWidth, isWeb: kIsWeb);
                final double columnWidth =
                    (constraints.maxWidth - 12.w * (columns - 1)) / columns;
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 14.h,
                    mainAxisExtent: _gridRowExtent(columnWidth),
                  ),
                  itemBuilder: (_, __) =>
                      const SkeletonLoader(height: 220, radius: 16),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoriesHeader extends ConsumerWidget {
  const _CategoriesHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = kIsWeb && WideStorefrontScope.isActive(context);
    final cartCount = wide ? 0 : ref.watch(cartCountProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Categories', style: jakarta(26.sp)),
                SizedBox(height: 2.h),
                Text('Shop from the widest range',
                    style: dm(13.sp, color: AU.muted)),
              ],
            ),
          ),
          if (!wide) ...[
            SizedBox(width: 10.w),
            _HeaderIconButton(
              icon: PhosphorIcons.magnifyingGlassBold,
              semanticLabel: 'Search',
              onTap: () => context.push(RouteNames.search),
            ),
            SizedBox(width: 10.w),
            _HeaderIconButton(
              icon: PhosphorIcons.shoppingCartSimpleBold,
              art: CartArt.cart,
              semanticLabel: 'Cart',
              badgeCount: cartCount,
              onTap: () => context.push(RouteNames.cart),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.badgeCount = 0,
    this.art,
  });

  final PhosphorIconData icon;
  final CartArt? art;
  final VoidCallback onTap;
  final String semanticLabel;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 46.w,
          height: 46.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: _accentSurface,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Center(
                  child: art != null
                      ? CartArtImage(art!, size: 26.sp)
                      : PhosphorIcon(icon, size: 20.sp, color: _accent),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -2.w,
                  top: -2.h,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    constraints: BoxConstraints(minWidth: 18.w),
                    decoration: BoxDecoration(
                      color: AppColors.brandRose,
                      borderRadius: BorderRadius.circular(100.r),
                      border: Border.all(color: Colors.white, width: 1.8),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  final List<CategoryEntity> categories;
  final String selectedCategoryId;
  final ValueChanged<CategoryEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    final wide = kIsWeb && WideStorefrontScope.isActive(context);
    return Container(
      width: wide ? 220 : 98.w,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FC),
        border: Border(
          right: BorderSide(color: Color(0xFFE3E8F3)),
        ),
      ),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.id == selectedCategoryId;
          if (wide) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Semantics(
                selected: selected,
                child: Material(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(category),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        _CategoryThumb(
                            imageUrl: category.imageUrl,
                            name: category.name,
                            isSelected: selected,
                            fixedSize: 46),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(category.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? _accent
                                        : AppColors.textSecondary))),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }
          return _CategoryRailItem(
            category: category,
            isSelected: selected,
            onTap: () => onSelect(category),
          );
        },
      ),
    );
  }
}

class _CategoryRailItem extends StatelessWidget {
  const _CategoryRailItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final CategoryEntity category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(4.w, 10.h, 4.w, 10.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected ? const Color(0xFFC9D6F2) : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1A001F5F),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (isSelected)
                Positioned(
                  left: -4.w,
                  top: 18.h,
                  bottom: 18.h,
                  child: Container(
                    width: 4.w,
                    decoration: BoxDecoration(
                      color: AppColors.brandYellow,
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  children: <Widget>[
                    _CategoryThumb(
                      imageUrl: category.imageUrl,
                      name: category.name,
                      isSelected: isSelected,
                    ),
                    Gap(7.h),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5.sp,
                        color: isSelected ? _accent : const Color(0xFF5A6A8E),
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category thumbnail: a bundled 3D icon chosen from the category name, the
/// category's own uploaded image when no icon fits, or a generic 3D icon.
class _CategoryThumb extends StatelessWidget {
  const _CategoryThumb({
    required this.imageUrl,
    required this.name,
    required this.isSelected,
    this.fixedSize,
  });

  final String? imageUrl;
  final String name;
  final bool isSelected;
  final double? fixedSize;

  @override
  Widget build(BuildContext context) {
    final String? art = categoryArtFor(name);
    final bool hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final double size = fixedSize ?? 56.w;

    Widget child;
    if (art != null) {
      child = Padding(
        padding: EdgeInsets.all(size * 0.1),
        child: AnimatedScale(
          scale: isSelected ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: Image.asset(art, fit: BoxFit.contain),
        ),
      );
    } else if (hasImage) {
      child = Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: CachedNetworkImage(
          imageUrl: webImageSource(imageUrl!),
          memCacheWidth: 200,
          memCacheHeight: 200,
          filterQuality: FilterQuality.high,
          fit: BoxFit.contain,
          placeholder: (context, url) =>
              const SkeletonLoader(height: 46, radius: 14),
          errorWidget: (context, url, error) =>
              Image.asset('assets/loading/all.png', fit: BoxFit.contain),
        ),
      );
    } else {
      child = Padding(
        padding: EdgeInsets.all(size * 0.1),
        child: Image.asset('assets/loading/all.png', fit: BoxFit.contain),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSelected
              ? const <Color>[Color(0xFFE8EEFB), Color(0xFFD5E1F8)]
              : const <Color>[Colors.white, Color(0xFFEEF2FA)],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isSelected ? const Color(0xFFC9D6F2) : const Color(0xFFE3E8F3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CategoryProductPane extends ConsumerStatefulWidget {
  const _CategoryProductPane({
    required this.selectedParent,
    required this.highlightedCategory,
    required this.childCategories,
    required this.selectedFeedId,
    required this.onSelectChild,
    super.key,
  });

  final CategoryEntity selectedParent;
  final CategoryEntity highlightedCategory;
  final List<CategoryEntity> childCategories;
  final String selectedFeedId;
  final ValueChanged<String> onSelectChild;

  @override
  ConsumerState<_CategoryProductPane> createState() =>
      _CategoryProductPaneState();
}

class _CategoryProductPaneState extends ConsumerState<_CategoryProductPane> {
  late final ScrollController _scrollController;

  // The active feed params — derived from selectedFeedId.
  ProductListParams get _params => ProductListParams(
        categoryId: widget.selectedFeedId,
        title: widget.selectedFeedId == widget.selectedParent.id
            ? widget.selectedParent.name
            : widget.highlightedCategory.name,
      );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset >= max - 300) {
      final viewState = ref.read(productListProvider(_params)).asData?.value;
      if (viewState != null && viewState.hasMore && !viewState.isLoadingMore) {
        ref.read(productListProvider(_params).notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productListAsync = ref.watch(productListProvider(_params));

    final feedCategoryName = widget.selectedFeedId == widget.selectedParent.id
        ? widget.selectedParent.name
        : widget.highlightedCategory.name;

    // Show the category's true total, not how many items have loaded
    // into the list so far — the first page lands at the page size
    // (e.g. 20), so the header used to read "20 products" until the
    // user scrolled far enough to fetch the rest and it happened to
    // catch up to the real total.
    //
    // BUT the category's stored product_count is a simple "is this
    // product active" tally with no awareness of which shops actually
    // serve this customer's delivery location — the product-list query
    // applies that shop-allocation scoping, the count query doesn't. A
    // category can legitimately report more products than this customer
    // can actually see (e.g. "5 products" while only 3 are sold by a shop
    // that delivers here). Once the list has fully loaded (no more pages
    // left to fetch), loadedCount is the true, customer-accurate figure
    // and should win over the stale metadata total; before that, still
    // fall back to totalCount so the header doesn't flash a low
    // first-page number while more pages are on the way.
    final viewState = productListAsync.asData?.value;
    final loadedCount = viewState?.items.length ?? 0;
    final totalCount = widget.highlightedCategory.productCount;
    final fullyLoaded =
        viewState != null && !viewState.hasMore && !viewState.isLoadingMore;
    final countLabel = fullyLoaded
        ? '$loadedCount products'
        : (totalCount > 0 ? '$totalCount products' : '$loadedCount products');

    return CustomScrollView(
      key: widget.key,
      controller: _scrollController,
      slivers: <Widget>[
        if (widget.childCategories.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 38.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _CategoryFilterChip(
                      label: 'All',
                      selected:
                          widget.selectedFeedId == widget.selectedParent.id,
                      onTap: () =>
                          widget.onSelectChild(widget.selectedParent.id),
                    ),
                    ...widget.childCategories.map(
                      (category) => Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: _CategoryFilterChip(
                          label: category.name,
                          selected: widget.selectedFeedId == category.id,
                          onTap: () => widget.onSelectChild(category.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 10.h),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        feedCategoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(20.sp),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        countLabel,
                        style: dm(12.sp, color: AU.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        productListAsync.when(
          loading: _buildLoadingSliver,
          error: (error, stackTrace) => SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              message: error.toString().replaceFirst('Bad state: ', ''),
              onRetry: () =>
                  ref.read(productListProvider(_params).notifier).refresh(),
            ),
          ),
          data: (viewState) {
            if (viewState.items.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: 'No products in this aisle yet',
                  message:
                      'Try a different category or check back once more inventory is added.',
                ),
              );
            }

            // Piggybacks on the category product-list fetch that's already
            // happening — no extra per-card network call. Cheap no-op once
            // already known.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(purchaseLimitsNotifierProvider.notifier).ensureLoaded(
                    viewState.items.map((product) => product.id).toList(),
                  );
            });

            return SliverLayoutBuilder(
              builder: (context, sliverConstraints) {
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 4.h),
                  sliver: SliverDealkerProductGrid(
                    products: viewState.items,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 14.h,
                    wrapCard: (int index, ProductEntity product, Widget card) {
                      return TweenAnimationBuilder<double>(
                        duration: Duration(
                          milliseconds: 220 + ((index % 6) * 30),
                        ),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: 1),
                        child: card,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 16),
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        // Inline footer: spinner while loading more, or "seen all" when done.
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final viewState = productListAsync.asData?.value;
              if (viewState == null) return const SizedBox.shrink();
              if (viewState.isLoadingMore) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  child: Center(
                    child: SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(_accent),
                      ),
                    ),
                  ),
                );
              }
              if (!viewState.hasMore && viewState.items.length > 20) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 28.h),
                  child: Center(
                    child: Text(
                      "You've seen all ${viewState.items.length} products",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                );
              }
              return SizedBox(height: 24.h);
            },
          ),
        ),
        if (kIsWeb &&
            WideStorefrontScope.isActive(context) &&
            viewState != null &&
            !viewState.hasMore &&
            !viewState.isLoadingMore)
          SliverToBoxAdapter(
              child: WebStorefrontFooter(onNavigate: context.go)),
      ],
    );
  }

  Widget _buildLoadingSliver() {
    return SliverLayoutBuilder(
      builder: (context, sliverConstraints) {
        final width = sliverConstraints.crossAxisExtent - 28.w;
        final columns = productGridColumns(width, isWeb: kIsWeb);
        final double columnWidth = (width - 12.w * (columns - 1)) / columns;

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 20.h),
          sliver: SliverGrid.builder(
            itemCount: 6,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 14.h,
              mainAxisExtent: _gridRowExtent(columnWidth),
            ),
            itemBuilder: (_, __) => const SkeletonLoader(
              height: 220,
              radius: 16,
            ),
          ),
        );
      },
    );
  }
}

// ── Category filter chips ──────────────────────────────────────────────────

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _accent : Colors.white,
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(
            color: selected ? _accent : const Color(0xFFD9E0F0),
          ),
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33001F5F),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12.5.sp,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF5A6A8E),
          ),
        ),
      ),
    );
  }
}
