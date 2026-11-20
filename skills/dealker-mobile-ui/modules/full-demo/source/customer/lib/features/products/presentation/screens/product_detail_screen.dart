import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_loading_screen.dart';
import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/analytics/analytics_service.dart';
import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:dealker_app/features/business_account/presentation/providers/price_mode_provider.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/exchange/data/exchange_models.dart';
import 'package:dealker_app/features/exchange/presentation/exchange_providers.dart';
import 'package:dealker_app/features/products/data/condition/product_condition.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/presentation/widgets/product_condition_blocks.dart';
import 'package:dealker_app/features/products/presentation/providers/product_detail_provider.dart';
import 'package:dealker_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:dealker_app/features/products/presentation/providers/recently_viewed_provider.dart';
import 'package:dealker_app/features/products/presentation/screens/product_detail_compat.dart';
import 'package:dealker_app/features/products/presentation/screens/product_detail_socket_delegate.dart';
import 'package:dealker_app/features/products/presentation/screens/product_list_screen.dart';
import 'package:dealker_app/features/products/presentation/widgets/product_detail_marketplace.dart';
import 'package:dealker_app/features/products/presentation/widgets/web_product_overview.dart';
import 'package:dealker_app/features/products/presentation/widgets/product_store_row.dart';
import 'package:dealker_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:dealker_app/features/products/presentation/widgets/product_recommendation_wrappers.dart';
import 'package:dealker_app/features/products/presentation/widgets/product_variant_selector.dart';
import 'package:dealker_app/features/wishlist/presentation/providers/wishlist_ids_provider.dart';
import 'package:dealker_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/error_state.dart';
import 'package:dealker_app/shared/widgets/web_storefront_footer.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    required this.id,
    super.key,
  });

  final String id;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late final ScrollController _scrollController;
  late ProductDetailSocketDelegate _socketDelegate;
  bool _isAppBarCollapsed = false;
  double _scrollOffset = 0;
  bool _hasLoggedView = false;
  // Which family member is currently displayed. Starts as widget.id but can
  // be swapped in place via the "Select Unit" chip row (product_variant_
  // selector.dart) without a route change — see _selectVariant.
  late String _selectedProductId;
  // The product page often renders instantly from cache; hold the branded
  // "opening product" animation for a moment so every open feels intentional.
  bool _introDone = false;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _introDone = true);
    });
    _selectedProductId = widget.id;
    _scrollController = ScrollController()..addListener(_onScroll);
    _socketDelegate = _createSocketDelegate();
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _socketDelegate.dispose();
    super.dispose();
  }

  ProductDetailSocketDelegate _createSocketDelegate() {
    return ProductDetailSocketDelegate(
      ref: ref,
      productId: _selectedProductId,
      onProductDataChanged: _refreshProductData,
      onCartChanged: () => ref.read(cartProvider.notifier).refresh(),
    )..setup();
  }

  // The socket delegate filters live stock/price events by a fixed
  // productId set at construction time, so swapping variants needs a fresh
  // delegate bound to the newly selected id — otherwise socket pushes for
  // the new variant would be silently ignored.
  void _selectVariant(String productId) {
    if (productId == _selectedProductId) {
      return;
    }
    _socketDelegate.dispose();
    setState(() {
      _selectedProductId = productId;
      _hasLoggedView = false;
    });
    _socketDelegate = _createSocketDelegate();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollOffset = _scrollController.offset;
    final collapsed = _scrollOffset > 260;
    if (collapsed != _isAppBarCollapsed) {
      setState(() => _isAppBarCollapsed = collapsed);
    }
  }

  void _refreshProductData() {
    ref
      ..invalidate(productDetailProvider(_selectedProductId))
      ..invalidate(pairWithProductsProvider(_selectedProductId))
      ..invalidate(relatedProductsProvider(_selectedProductId));
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(_selectedProductId));

    if (!_introDone) {
      return const Scaffold(
        backgroundColor: AppColors.brandCream,
        body: DealkerPageLoader(
          kind: DealkerLoadingKind.product,
          delay: Duration.zero,
        ),
      );
    }

    return productAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.brandCream,
        body: DealkerPageLoader(kind: DealkerLoadingKind.product),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: ErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: _refreshProductData,
        ),
      ),
      data: (product) {
        final effectiveProduct = normalizedProductForDetail(product);
        final effectiveAttributes = effectiveAttributesForDetail(
          effectiveProduct,
        );
        // Piggybacks on the product detail fetch that's already happening —
        // no extra per-card network call. Cheap no-op when already known.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(purchaseLimitsNotifierProvider.notifier)
              .ensureLoaded(<String>[effectiveProduct.id]);
        });

        if (!_hasLoggedView) {
          _hasLoggedView = true;
          unawaited(
            ref.read(analyticsServiceProvider).logProductView(
                  effectiveProduct.id,
                  effectiveProduct.categoryId,
                ),
          );
          unawaited(
            ref
                .read(recentlyViewedProvider.notifier)
                .recordView(effectiveProduct.id),
          );
        }

        final ProductCondition? condition = ref
            .watch(productConditionProvider(effectiveProduct.id))
            .asData
            ?.value;
        final List<String> order =
            ref.watch(productPageLayoutProvider).asData?.value ??
                kDefaultProductBlocks;

        final bool wideWeb = kIsWeb && MediaQuery.sizeOf(context).width >= 700;
        final ExchangeOffer? exchange = wideWeb
            ? ref.watch(exchangeForProductProvider(effectiveProduct.id)).asData?.value
            : null;

        // The gallery photo up top can be light-toned (wood/plant lifestyle
        // shots), which made the platform-default light status bar icons
        // (white time/battery/signal) unreadable against it — force dark
        // icons here regardless of collapsed state, matching the pattern
        // already used on the Home screen.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: wideWeb ? 1200 : double.infinity),
                child: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, _) => CustomScrollView(
                    controller: _scrollController,
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: wideWeb
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: WebProductOverview(
                                  product: effectiveProduct,
                                  onExchange: exchange?.eligible == true
                                      ? () => _openExchange(effectiveProduct)
                                      : null,
                                  exchangeMaxValue: exchange?.maxValue ?? 0,
                                  isWishlisted:
                                      ref.watch(wishlistIdsProvider.select(
                                    (ids) => ids.contains(effectiveProduct.id),
                                  )),
                                  onAdd: () => _addSelectedVariantToCart(
                                      effectiveProduct),
                                  onBuy: () => _buyNow(effectiveProduct),
                                  onWishlist: () =>
                                      _toggleWishlist(effectiveProduct),
                                ),
                              )
                            : PdpHead(
                                product: effectiveProduct,
                                condition: condition,
                                onBack: _handleBack,
                                onWishlist: () =>
                                    _toggleWishlist(effectiveProduct),
                                onCart: () => context.push(RouteNames.cart),
                                onExchange: (typeKey) => _openExchange(
                                  effectiveProduct,
                                  typeKey: typeKey,
                                ),
                              ),
                      ),
                      if (wideWeb)
                        SliverToBoxAdapter(
                          child:
                              ProductStoreRow(productId: effectiveProduct.id),
                        ),
                      if (effectiveProduct.hasMultipleOptions)
                        SliverToBoxAdapter(
                          child: ProductVariantSelector(
                            familyProductId: widget.id,
                            selectedProductId: _selectedProductId,
                            onSelect: _selectVariant,
                          ),
                        ),
                      for (final String key in order)
                        ..._block(
                          key,
                          effectiveProduct,
                          condition,
                          effectiveAttributes,
                        ),
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: RecentlyViewedWrapper(
                            productId: effectiveProduct.id,
                            enabled: _scrollOffset >= 180,
                            onProductTap: (targetProduct) =>
                                _openProduct(targetProduct),
                            onAddToCart: _addToCart,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: PairWithWrapper(
                            productId: effectiveProduct.id,
                            enabled: _scrollOffset >= 180,
                            onProductTap: (targetProduct) => _handlePairWithTap(
                              effectiveProduct,
                              targetProduct,
                            ),
                            onSeeAll: _openRecommendedProducts,
                            onAddToCart: _addToCart,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: SizedBox(height: 80),
                        ),
                      ),
                      if (wideWeb)
                        SliverToBoxAdapter(
                          child: WebStorefrontFooter(
                              onNavigate: (path) => context.go(path)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: wideWeb
                ? null
                : PdpBottomBar(
                    inStock: effectiveProduct.inStock,
                    onAdd: () => _addSelectedVariantToCart(effectiveProduct),
                    onBuy: () => _buyNow(effectiveProduct),
                  ),
          ),
        );
      },
    );
  }

  /// One movable block of the product page; order + visibility come from the dashboard theme builder.
  List<Widget> _block(
    String key,
    ProductEntity p,
    ProductCondition? c,
    List<Map<String, dynamic>> attributes,
  ) {
    Widget? w;
    switch (key) {
      case 'condition':
        if (c != null) w = ConditionBlock(condition: c);
      case 'qc':
        if (c != null) {
          w = QcSummaryCard(condition: c, productId: p.id, name: p.name);
        }
      case 'in_box':
        if (c != null) w = InBoxBlock(condition: c);
      case 'highlights':
        w = HighlightsBlock(lines: _highlightLines(p));
      case 'specs':
        final List<({String label, String value})> rows =
            <({String label, String value})>[
          for (final Map<String, dynamic> a in attributes)
            (
              label: '${a['label'] ?? a['name'] ?? ''}'.trim(),
              value: '${a['value'] ?? ''}'.trim(),
            ),
          if (attributes.isEmpty) ...?c?.specs,
        ].where((r) => r.label.isNotEmpty && r.value.isNotEmpty).toList();
        w = SpecsBlock(rows: rows);
      case 'description':
        w = DescriptionBlock(text: p.description ?? '');
      case 'vendor':
        w = VendorBlock(product: p, fallbackShopId: c?.shopId);
      case 'similar':
        w = SimilarWrapper(
          productId: p.id,
          enabled: _scrollOffset >= 80,
          onProductTap: (ProductEntity t) => _handleSimilarTap(p, t),
          onSeeAll: () => _openSimilarProducts(p),
          onAddToCart: _addToCart,
        );
    }
    if (w == null) return const <Widget>[];
    return <Widget>[SliverToBoxAdapter(child: RepaintBoundary(child: w))];
  }

  List<String> _highlightLines(ProductEntity p) {
    final Map<String, dynamic> h = p.highlights ?? const <String, dynamic>{};
    return h.entries
        .where((MapEntry<String, dynamic> e) => '${e.value}'.trim().isNotEmpty)
        .map(
          (MapEntry<String, dynamic> e) => int.tryParse(e.key) != null
              ? '${e.value}'
              : '${e.key}: ${e.value}',
        )
        .toList();
  }

  Future<void> _openExchange(ProductEntity p, {String? typeKey}) async {
    final String route = Uri(
      path: RouteNames.exchange,
      queryParameters: <String, String>{
        'productId': p.id,
        'name': p.name,
        'price': p.effectivePrice.toStringAsFixed(0),
        if (typeKey != null) 'type': typeKey,
      },
    ).toString();
    final bool allowed = await ref
        .read(authGateControllerProvider)
        .protectRoute(
          context,
          route: route,
          title: 'Log in to exchange',
          message: 'Please log in to get an exchange value for your old device.',
        );
    if (allowed && mounted) context.push(route);
  }

  Future<void> _buyNow(ProductEntity p) async {
    await _addSelectedVariantToCart(p);
    if (!mounted) return;
    if (ref.read(cartItemQuantityProvider(p.id)) > 0)
      context.push(RouteNames.cart);
  }

  /// A shared product link (e.g. dealker.in/products/:slug, opened via App
  /// Links) cold-starts the app directly onto this screen with nothing
  /// else on the navigation stack. `Navigator.pop` on an empty stack left
  /// the user staring at a black screen instead of leaving the app or
  /// going anywhere useful — check canPop first and fall back to home.
  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go(RouteNames.home);
    }
  }

  void _openProduct(ProductEntity product) {
    if (product.id == _selectedProductId) {
      return;
    }
    context.push('/product/${product.id}');
  }

  void _openRecommendedProducts() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProductListScreen(title: 'Recommended products'),
      ),
    );
  }

  void _openSimilarProducts(ProductEntity product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductListScreen(
          categoryId: product.categoryId,
          title: 'Similar Products',
        ),
      ),
    );
  }

  void _handlePairWithTap(
    ProductEntity currentProduct,
    ProductEntity targetProduct,
  ) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductPairWithTap(
            currentProduct.id,
            targetProduct.id,
          ),
    );
    _openProduct(targetProduct);
  }

  void _handleSimilarTap(
    ProductEntity currentProduct,
    ProductEntity targetProduct,
  ) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductSimilarTap(
            currentProduct.id,
            targetProduct.id,
          ),
    );
    _openProduct(targetProduct);
  }

  void _logProductDetailsExpand(
    ProductEntity product,
    String sectionName,
  ) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductDetailsExpand(
            product.id,
            sectionName,
          ),
    );
  }

  Future<void> _toggleWishlist(ProductEntity product) async {
    final authGate = ref.read(authGateControllerProvider);
    final allowed = await authGate.protectWishlist(context, product);
    if (!allowed || !mounted) {
      return;
    }

    final isInWishlist = ref.read(wishlistIdsProvider).contains(product.id);
    unawaited(
      ref.read(analyticsServiceProvider).logWishlistToggle(
            product.id,
            isInWishlist ? 'remove' : 'add',
          ),
    );
    final result =
        await ref.read(wishlistProvider.notifier).toggleWishlist(product);
    if (!mounted || result.isSuccess) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
  }

  // Used by the recommendation rails (Pair With / Similar / Recently
  // Viewed), which have no inline unit selector of their own — a
  // multi-option product tapped from one of those rows still needs the
  // picker sheet to choose which variant to add.
  Future<void> _addToCart(ProductEntity product) async {
    if (!product.inStock) {
      showCartSnackBar(context, 'This product is currently unavailable.');
      return;
    }

    if (product.hasMultipleOptions) {
      showProductOptionsSheet(context, product);
      return;
    }

    await _addProductToCart(product);
  }

  // Used by this screen's own bottom bar. The "Select Unit" chip row
  // (when present) already lets the customer choose the exact variant
  // in place, so — unlike _addToCart — this skips straight to adding
  // whichever variant is currently displayed instead of popping the
  // options sheet again on top of it.
  Future<void> _addSelectedVariantToCart(ProductEntity product) async {
    if (!product.inStock) {
      showCartSnackBar(context, 'This product is currently unavailable.');
      return;
    }

    await _addProductToCart(product);
  }

  Future<void> _addProductToCart(ProductEntity product) async {
    // Re-checked fresh on every tap (ref.read, not a watched value) so a
    // stale cache can never let a mutation through — block before it ever
    // reaches the network.
    final purchaseLimitStatus =
        ref.read(purchaseLimitStatusProvider(product.id));
    if (purchaseLimitStatus?.isAtLimit ?? false) {
      AppToast.show(context, 'Maximum product order complete');
      return;
    }

    final authGate = ref.read(authGateControllerProvider);
    final allowed = await authGate.protectAddToCart(context, product);
    if (!allowed || !mounted) {
      return;
    }

    // A wholesale listing with a bulk minimum can't usefully start at 1 —
    // that's a quantity the customer would just have to immediately tap
    // "+" past several more times to reach the minimum. Land straight on
    // it instead, mirroring the same-purpose logic in product_card.dart.
    final wholesaleActive = ref.read(isWholesalePricingActiveProvider);
    final startQty = wholesaleActive && product.hasBulkMinimum
        ? product.bulkMinQuantity!
        : 1;

    unawaited(
      ref.read(analyticsServiceProvider).logAddToCart(
            product.id,
            startQty,
            product.effectivePrice,
          ),
    );
    final result = await ref.read(cartProvider.notifier).addItem(
          product.id,
          startQty,
          product: product,
          shopProductId: product.shopProductId,
        );
    if (!mounted) {
      return;
    }
    if (!result.isSuccess) {
      showCartSnackBar(context, result.failure!.message);
      return;
    }
    if (startQty > 1) {
      AppToast.show(
        context,
        'Added $startQty — the bulk minimum for this product',
        type: ToastType.info,
      );
    }
  }
}
