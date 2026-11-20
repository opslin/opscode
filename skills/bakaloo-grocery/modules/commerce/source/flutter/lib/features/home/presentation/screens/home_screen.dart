import 'dart:async';

import 'package:bakaloo_flutter_app/commerce/commerce_client.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/screens/categories_screen.dart';
import 'package:bakaloo_flutter_app/shared/widgets/category_artwork.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_header.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_search_bar.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_list_screen.dart';

import '../widgets/dynamic_home_sections.dart';

import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/storefront_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

part 'home_sections.dart';

/// Bakaloo’s home grid connected to the local catalog and Fresh Basket artwork.
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

  List<ProductEntity> get _products =>
      ref.read(catalogProvider) ?? widget.storefront.products;

  void _showCatalog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProductListScreen(fallback: _products, onCart: _showCart),
      ),
    );
  }

  void _showCategories() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoriesScreen(
          storefront: widget.storefront,
          onSearch: _showCatalog,
          onProduct: _showProduct,
          onCart: _showCart,
        ),
      ),
    );
  }

  void _showCart() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartScreen(storefront: widget.storefront),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storefront = widget.storefront;
    final count = ref.watch(demoShopProvider.select((state) => state.count));
    final products = ref.watch(catalogProvider) ?? storefront.products;
    final listedProducts = products
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
              onCartTap: _showCart,
              cartCount: count,
            ),
          ),
          SliverToBoxAdapter(child: HomeSearchBar(onSearchTap: _showCatalog)),
          SliverToBoxAdapter(
            child: _CategoryStrip(
              categories: storefront.categories,
              selection: _category,
              onSelect: _selectCategory,
            ),
          ),
          if (_category == 'all') ...[
            if (storefront.promos.isNotEmpty)
              SliverToBoxAdapter(
                child: _HeroPromoCarousel(
                  cards: storefront.promos,
                  onCategory: _selectCategory,
                ),
              ),
            DynamicHomeSections(
              storefront: storefront,
              onCategory: _selectCategory,
              onProduct: _showProduct,
            ),
          ],
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
      bottomNavigationBar: StorefrontNavigation(
        browsing: false,
        count: count,
        onHome: () => _selectCategory('all'),
        onBrowse: _showCategories,
        onCart: _showCart,
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
    height: 76.h + MediaQuery.textScalerOf(context).scale(12.sp) - 12.sp,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth / categories.length).clamp(
          65.w,
          92.w,
        );
        return ListView.builder(
          padding: EdgeInsets.only(top: 6.h),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return _CategoryTab(
              key: ValueKey('category-${category.id}'),
              category: category,
              isSelected: category.id == selection,
              onTap: () => onSelect(category.id),
              textColor: const Color(0xFF3B1260),
              indicatorColor: AppColors.orderViolet,
              width: width,
            );
          },
        );
      },
    ),
  );
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.category,
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.textColor,
    required this.indicatorColor,
    required this.width,
  });

  final DemoCategory category;
  final bool isSelected;
  final VoidCallback onTap;
  final Color textColor;
  final Color indicatorColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: double.infinity,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              SizedBox(
                width: 44.w,
                height: 44.h,
                child: CategoryArtwork(category: category),
              ),
              Gap(1.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.w),
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.8.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? textColor
                        : textColor.withValues(alpha: 0.72),
                  ),
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5.h,
                  width: isSelected ? width * 0.78 : 0,
                  decoration: BoxDecoration(
                    color: isSelected ? indicatorColor : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(999),
                      topRight: Radius.circular(999),
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
