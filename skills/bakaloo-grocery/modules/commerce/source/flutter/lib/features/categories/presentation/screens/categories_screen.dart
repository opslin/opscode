import 'package:bakaloo_flutter_app/commerce/commerce_client.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:bakaloo_flutter_app/shared/widgets/category_artwork.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/storefront_icon_button.dart';
import 'package:bakaloo_flutter_app/shared/widgets/storefront_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

const _accent = AppColors.orderViolet;

/// Bakaloo's two-pane category browser fed by the standalone catalog.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({
    super.key,
    required this.storefront,
    required this.onSearch,
    required this.onProduct,
    required this.onCart,
  });

  final Storefront storefront;
  final VoidCallback onSearch;
  final ValueChanged<ProductEntity> onProduct;
  final VoidCallback onCart;

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categories = widget.storefront.categories
        .where((category) => category.id != 'all')
        .toList(growable: false);
    final selected =
        categories
            .where((category) => category.id == _selectedCategoryId)
            .firstOrNull ??
        categories.firstOrNull;
    final catalog = ref.watch(catalogProvider) ?? widget.storefront.products;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CategoriesHeader(onSearch: widget.onSearch, onCart: widget.onCart),
            const Divider(height: 1),
            if (selected == null)
              const Expanded(
                child: Center(child: Text('No categories available')),
              )
            else
              Expanded(
                child: Row(
                  children: [
                    _CategoryRail(
                      categories: categories,
                      selectedCategoryId: selected.id,
                      onSelect: (category) =>
                          setState(() => _selectedCategoryId = category.id),
                    ),
                    Expanded(
                      child: _CategoryProductPane(
                        key: ValueKey(selected.id),
                        category: selected,
                        onProduct: widget.onProduct,
                        products: catalog
                            .where((product) => product.category == selected.id)
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: StorefrontNavigation(
        browsing: true,
        count: ref.watch(demoShopProvider.select((cart) => cart.count)),
        onHome: () => Navigator.of(context).pop(),
        onBrowse: () {},
        onCart: widget.onCart,
      ),
    );
  }
}

class _CategoriesHeader extends ConsumerWidget {
  const _CategoriesHeader({required this.onSearch, required this.onCart});

  final VoidCallback onSearch;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(demoShopProvider.select((cart) => cart.count));

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Categories', style: AppTextStyles.h1),
                SizedBox(height: 2.h),
                Text(
                  'Shop from the widest range',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          StorefrontIconButton(
            icon: PhosphorIcons.magnifyingGlassBold,
            semanticLabel: 'Search',
            onTap: onSearch,
          ),
          SizedBox(width: 10.w),
          StorefrontIconButton(
            icon: PhosphorIcons.shoppingCartSimpleBold,
            semanticLabel: 'Open cart',
            badgeCount: cartCount,
            onTap: onCart,
          ),
        ],
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

  final List<DemoCategory> categories;
  final String selectedCategoryId;
  final ValueChanged<DemoCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92.w,
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryRailItem(
            category: category,
            isSelected: category.id == selectedCategoryId,
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

  final DemoCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Material(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: Semantics(
          button: true,
          selected: isSelected,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: onTap,
            child: Stack(
              children: <Widget>[
                // Active indicator bar on the left edge.
                if (isSelected)
                  Positioned(
                    left: 0,
                    top: 14.h,
                    bottom: 14.h,
                    child: Container(
                      width: 3.w,
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.orderVioletBorder
                          : Colors.transparent,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: 10.h,
                    horizontal: 4.w,
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox.square(
                        dimension: 46.w,
                        child: CategoryArtwork(category: category),
                      ),
                      Gap(6.h),
                      Text(
                        category.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 10.5.sp,
                          color: isSelected ? _accent : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
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
      ),
    );
  }
}

class _CategoryProductPane extends StatelessWidget {
  const _CategoryProductPane({
    super.key,
    required this.category,
    required this.products,
    required this.onProduct,
  });

  final DemoCategory category;
  final List<ProductEntity> products;
  final ValueChanged<ProductEntity> onProduct;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 10.h),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2.h),
              Text(
                '${products.length} ${products.length == 1 ? 'product' : 'products'}',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      if (products.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('No products in this aisle yet')),
        )
      else
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final columnWidth = (constraints.crossAxisExtent - 40.w) / 2;
            final textScale =
                MediaQuery.textScalerOf(context).scale(12.sp) - 12.sp;
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 4.h),
              sliver: SliverGrid.builder(
                itemCount: products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 14.h,
                  mainAxisExtent: columnWidth * 0.84 + 154.h + textScale * 5,
                ),
                itemBuilder: (context, index) => TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 220 + (index % 6) * 30),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0.0, end: 1.0),
                  child: ProductCard(
                    product: products[index],
                    width: columnWidth / ScreenUtil().scaleWidth,
                    style: ProductCardStyle.grid,
                    useCompactAddButton: true,
                    showImageBorder: true,
                    accentColor: _accent,
                    onTap: () => onProduct(products[index]),
                  ),
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 16),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ],
  );
}
