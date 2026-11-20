import 'package:bakaloo_flutter_app/commerce/commerce_client.dart';
import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:bakaloo_flutter_app/shared/widgets/storefront_icon_button.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Local storefront adapter for Bakaloo's product list with shared ProductCard.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({
    super.key,
    required this.fallback,
    required this.onCart,
  });
  final List<ProductEntity> fallback;
  final VoidCallback onCart;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(catalogProvider) ?? widget.fallback;
    final count = ref.watch(demoShopProvider.select((cart) => cart.count));
    final results = products
        .where((item) => item.name.toLowerCase().contains(_search))
        .toList();
    final width =
        (MediaQuery.sizeOf(context).width - 44) / 2 / ScreenUtil().scaleWidth;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalog'),
        actions: [
          StorefrontIconButton(
            icon: PhosphorIcons.shoppingCartSimpleBold,
            semanticLabel: 'Cart',
            badgeCount: count,
            onTap: widget.onCart,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _search = value.toLowerCase().trim()),
              decoration: const InputDecoration(
                labelText: 'Search products',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('No products match this search.'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: width.w * .84 + 180,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, index) => ProductCard(
                      product: results[index],
                      width: width,
                      style: ProductCardStyle.grid,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
