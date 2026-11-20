import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/remote_theme_model.dart';
import '../features/home/presentation/widgets/banner_rail_section.dart';
import '../features/home/presentation/widgets/oval_spotlight_section.dart';
import '../features/home/presentation/widgets/price_sale_section.dart';
import '../features/home/presentation/widgets/store_tiles_row.dart';
import '../features/products/domain/entities/product_entity.dart';
import '../shared/widgets/dealker_product_card.dart';
import '../shared/widgets/home_header.dart';
import '../shared/widgets/home_search_bar.dart';
import 'customer_state.dart';
import 'fixtures.dart';
import 'store_state.dart';

class CustomerPreview extends ConsumerWidget {
  const CustomerPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(selectedStoreProvider);
    final count = ref.watch(
      cartProvider.select((cart) => cart.values.fold(0, (a, b) => a + b)),
    );
    final products = catalog
        .where((item) => item.categoryId == store.id)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFD),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: StorePaletteScope(
              builder: (context, palette, _) => ColoredBox(
                color: palette.background,
                child: Column(
                  children: [
                    HomeHeader(
                      addressText: 'Home · Demo address',
                      topBarTheme: TopBarTheme(
                        backgroundColor: palette.background,
                        textColor: palette.onBackground,
                      ),
                      onAddressTap: () =>
                          showCartSnackBar(context, 'Demo delivery address'),
                      onProfileTap: () => context.go('/home'),
                    ),
                    StoreTilesRow(palette: palette),
                    ColoredBox(
                      color: palette.tabFill,
                      child: HomeSearchBar(
                        onSearchTap: () => context.push('/search'),
                        onSellTap: () => context.push('/sell'),
                        animateHints: !MediaQuery.disableAnimationsOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                '${PreviewBrand.of(context)} · ${store.label}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: BannerRailSection(
              key: ValueKey(store.id),
              config: {'title': 'Featured in ${store.label}'},
              products: products,
            ),
          ),
          SliverToBoxAdapter(child: PriceSaleSection(config: priceSaleConfig)),
          SliverToBoxAdapter(
            child: OvalSpotlightSection(
              config: const {'title': 'Find your next device'},
              products: catalog.take(4).toList(growable: false),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 4,
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3B176B),
                ),
                onPressed: () => context.push('/search'),
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Browse'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3B176B),
                ),
                onPressed: () => context.push('/customer-cart'),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(count == 0 ? 'Cart' : 'Cart ($count)'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3B176B),
                ),
                onPressed: () => context.go('/home'),
                child: const Text('Vendor UI'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerCatalog extends StatefulWidget {
  const CustomerCatalog({super.key, this.category});

  final String? category;

  @override
  State<CustomerCatalog> createState() => _CustomerCatalogState();
}

class _CustomerCatalogState extends State<CustomerCatalog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = catalog
        .where(
          (item) =>
              (widget.category == null || item.categoryId == widget.category) &&
              item.name.toLowerCase().contains(_query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Browse products')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search products',
            ),
            onChanged: (text) =>
                setState(() => _query = text.trim().toLowerCase()),
          ),
          const SizedBox(height: 14),
          if (products.isEmpty)
            const Center(child: Text('No products found'))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 10) / 2;
                final slots = DealkerCardSlots.forProducts(products, width);
                return Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final item in products)
                      DealkerProductCard(
                        product: item,
                        width: width,
                        nameLines: slots.nameLines,
                        showSoldRow: slots.showSold,
                        showRatingRow: slots.showRating,
                        onTap: () => context.push('/product/${item.id}'),
                        buttonLabel: 'Add',
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class CustomerCart extends ConsumerWidget {
  const CustomerCart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantities = ref.watch(cartProvider);
    final items = catalog.where((p) => quantities.containsKey(p.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: items.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : ListView(
              children: [
                for (final ProductEntity item in items)
                  ListTile(
                    leading: Image.asset(
                      item.thumbnailUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      '${quantities[item.id]} × ₹${item.effectivePrice.toStringAsFixed(0)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove ${item.name}',
                      onPressed: () =>
                          ref.read(cartProvider.notifier).removeItem(item.id),
                      icon: const Icon(Icons.close),
                    ),
                  ),
              ],
            ),
    );
  }
}
