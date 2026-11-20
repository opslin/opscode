import 'dart:async';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_header.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_search_bar.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

part 'home_sections.dart';

/// Standalone composition of Bakaloo's home header, carousel and product grid.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.storefront});

  final Storefront storefront;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _category = 'all';

  void _selectCategory(String id) => setState(() => _category = id);

  void _message(String title, String text) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ListTile(title: Text(title), subtitle: Text(text)),
        ),
      ),
    );
  }

  void _showProduct(ProductEntity product) {
    _message(
      product.name,
      '${product.unit} · ₹${product.effectivePrice.toStringAsFixed(0)}'
      '${product.inStock ? '' : ' · Out of stock'}',
    );
  }

  void _showSearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ProductSearch(
        products: widget.storefront.products,
        onProduct: _showProduct,
      ),
    );
  }

  void _showCart() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _DemoCart(products: widget.storefront.products),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storefront = widget.storefront;
    final count = ref.watch(demoShopProvider.select((state) => state.count));
    final listedProducts = storefront.products
        .where((product) => _category == 'all' || product.category == _category)
        .toList(growable: false);
    final categoryLabel = storefront.categories
        .firstWhere((category) => category.id == _category)
        .name;

    return Scaffold(
      body: CustomScrollView(
        key: const Key('storefront-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: HomeHeader(
              brandName: storefront.brand,
              addressText: storefront.address,
              deliveryEtaMinutes: storefront.deliveryMinutes,
              onAddressTap: () =>
                  _message('Delivery address', storefront.address),
              onNotificationTap: () =>
                  _message('Notifications', 'You’re all caught up.'),
              onWalletTap: () => _message('Wallet', 'Demo balance ₹0'),
            ),
          ),
          SliverToBoxAdapter(child: HomeSearchBar(onSearchTap: _showSearch)),
          SliverToBoxAdapter(
            child: _CategoryStrip(
              categories: storefront.categories,
              selection: _category,
              onSelect: _selectCategory,
            ),
          ),
          if (_category == 'all' && storefront.promos.isNotEmpty)
            SliverToBoxAdapter(
              child: _HeroPromoCarousel(
                cards: storefront.promos,
                onCategory: _selectCategory,
              ),
            ),
          if (listedProducts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No products in this category.')),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(top: 10.h, bottom: 16.h),
              sliver: SliverToBoxAdapter(
                child: _CategoryProductSection(
                  title: _category == 'all'
                      ? 'Everyday essentials'
                      : categoryLabel,
                  products: listedProducts,
                  onProductTap: _showProduct,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          color: Colors.white,
          elevation: 3,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _FooterButton(
                  label: 'Home',
                  asset: 'assets/icon/footer_icon/bakaloo-home-filled-icon.png',
                  onTap: () => _selectCategory('all'),
                ),
                _FooterButton(
                  label: 'Browse',
                  asset: 'assets/icon/footer_icon/bakaloo-categories-outline-icon.png',
                  onTap: _showSearch,
                ),
                _FooterButton(
                  label: count == 0 ? 'Cart' : 'Cart ($count)',
                  onTap: _showCart,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selection,
    required this.onSelect,
  });

  final List<DemoCategory> categories;
  final String selection;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 82.w + MediaQuery.textScalerOf(context).scale(36.sp) - 36.sp,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      itemCount: categories.length,
      separatorBuilder: (_, _) => Gap(6.w),
      itemBuilder: (context, index) {
        final category = categories[index];
        final selected = category.id == selection;
        return Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            key: ValueKey('category-${category.id}'),
            onTap: () => onSelect(category.id),
            borderRadius: BorderRadius.circular(8.r),
            child: SizedBox(
              width: 65.w,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      switch (category.icon) {
                        'leaf' => Icons.eco_rounded,
                        'milk' => Icons.water_drop_rounded,
                        'grain' => Icons.grain_rounded,
                        'snack' => Icons.lunch_dining_rounded,
                        _ => Icons.shopping_basket_rounded,
                      },
                      color: selected
                          ? AppColors.primaryGreen
                          : const Color(0xFF6B3FA0),
                      size: 27.w,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.categoryName.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  Gap(4.h),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 2,
                    width: 26.w,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryGreen
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({required this.label, required this.onTap, this.asset});
  final String label;
  final VoidCallback onTap;
  final String? asset;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (asset case final path?)
            Image.asset(
              path,
              height: 23,
              width: 23,
              cacheWidth: 92,
              cacheHeight: 92,
            )
          else
            const Icon(Icons.shopping_bag_outlined, size: 23),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.2),
          ),
        ],
      ),
    ),
  );
}

class _ProductSearch extends StatefulWidget {
  const _ProductSearch({required this.products, required this.onProduct});
  final List<ProductEntity> products;
  final ValueChanged<ProductEntity> onProduct;

  @override
  State<_ProductSearch> createState() => _ProductSearchState();
}

class _ProductSearchState extends State<_ProductSearch> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.products
        .where((product) => product.name.toLowerCase().contains(_query))
        .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .50,
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Search products'),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              Expanded(
                child: results.isEmpty
                    ? const Center(
                        child: Text('No products match your search.'),
                      )
                    : ListView(
                        children: [
                          for (final product in results)
                            ListTile(
                              title: Text(product.name),
                              subtitle: Text(product.unit),
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onProduct(product);
                              },
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

class _DemoCart extends ConsumerWidget {
  const _DemoCart({required this.products});
  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(demoShopProvider);
    final items = products
        .where((product) => cart.quantity(product.id) > 0)
        .toList();
    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.effectivePrice * cart.quantity(item.id),
    );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .42,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          children: [
            Text('Your cart', style: Theme.of(context).textTheme.titleLarge),
            if (items.isEmpty)
              const ListTile(title: Text('Your cart is empty.')),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text(
                  '${cart.quantity(item.id)} × ₹${item.effectivePrice.toStringAsFixed(0)}',
                ),
                trailing: IconButton(
                  tooltip: 'Remove ${item.name}',
                  onPressed: () =>
                      ref.read(demoShopProvider.notifier).setQuantity(item, 0),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            if (items.isNotEmpty) Text('Total ₹${total.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }
}
