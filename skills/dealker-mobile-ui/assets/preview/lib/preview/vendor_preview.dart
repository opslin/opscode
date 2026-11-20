import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../vendor/core/theme/app_colors.dart';
import '../vendor/features/home/presentation/widgets/home_actions.dart';
import '../vendor/features/home/presentation/widgets/home_bottom_nav.dart';
import '../vendor/features/home/presentation/widgets/home_common.dart';
import '../vendor/features/home/presentation/widgets/home_header_stats.dart';
import '../vendor/features/wholesale/data/wholesale_models.dart';
import '../vendor/routing/route_names.dart';
import '../vendor/shared/widgets/premium_ui.dart';
import '../vendor/shared/widgets/wholesale_product_card.dart';

const stock = [
  WholesaleItem(
    id: 'vendor-phone',
    name: '5G Smartphone · 128 GB',
    price: 15800,
    retailPrice: 18999,
    moq: 3,
    stock: 24,
    condition: 'NEW',
    thumbnail: 'assets/categories/smartphones.png',
    seller: WholesaleSeller(
      id: 'demo-seller',
      name: 'Demo Electronics',
      city: 'Bengaluru',
    ),
  ),
  WholesaleItem(
    id: 'vendor-audio',
    name: 'Wireless Studio Headphones',
    price: 1150,
    retailPrice: 1799,
    moq: 5,
    stock: 8,
    condition: 'NEW',
    thumbnail: 'assets/categories/headphones.png',
    seller: WholesaleSeller(id: 'demo-audio', name: 'Demo Audio Supply'),
  ),
];

class VendorPreview extends ConsumerWidget {
  const VendorPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: AppColors.canvas,
    bottomNavigationBar: const HomeBottomNav(),
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        HomeHeader(
          cartCount: ref
              .watch(vendorCartProvider)
              .values
              .fold(0, (a, b) => a + b),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const QuickActions(),
              const SizedBox(height: 16),
              HeroBanner(
                title: 'Buy stock in bulk',
                subtitle: 'Compare wholesale prices and minimum quantities.',
                art: A3.extra('cartons'),
                cta: HeroButton(
                  'Explore marketplace',
                  onTap: () => context.go(Routes.wholesale),
                ),
              ),
              const SizedBox(height: 20),
              SectionTitle(
                title: 'Marketplace',
                onViewAll: () => context.go(Routes.wholesale),
              ),
              const SizedBox(height: 10),
              const StockShelf(),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => context.go('/'),
                child: const Text('Customer UI'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class VendorMarketplace extends StatelessWidget {
  const VendorMarketplace({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    appBar: AppBar(
      title: const Text('Wholesale marketplace'),
      actions: [
        IconButton(
          tooltip: 'Wholesale cart',
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () => context.push(Routes.wholesaleCart),
        ),
      ],
      leading: IconButton(
        tooltip: 'Vendor home',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(Routes.home),
      ),
    ),
    bottomNavigationBar: const HomeBottomNav(current: NavTab.marketplace),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(14),
      child: StockShelf(),
    ),
  );
}

final vendorCartProvider = NotifierProvider<VendorCart, Map<String, int>>(
  VendorCart.new,
);

class VendorCart extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void setQuantity(WholesaleItem item, int next) {
    final quantities = Map<String, int>.of(state);
    if (next < item.moq) {
      quantities.remove(item.id);
    } else {
      quantities[item.id] = next.clamp(item.moq, item.stock);
    }
    state = Map.unmodifiable(quantities);
  }
}

class VendorCartPreview extends ConsumerWidget {
  const VendorCartPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantities = ref.watch(vendorCartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wholesale cart')),
      body: quantities.isEmpty
          ? const Center(child: Text('Your wholesale cart is empty'))
          : ListView(
              children: [
                for (final item in stock)
                  if (quantities[item.id] case final quantity?)
                    ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '$quantity units · ₹${item.price} per unit',
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove ${item.name}',
                        onPressed: () => ref
                            .read(vendorCartProvider.notifier)
                            .setQuantity(item, 0),
                        icon: const Icon(Icons.close),
                      ),
                    ),
              ],
            ),
    );
  }
}

class StockShelf extends ConsumerWidget {
  const StockShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantities = ref.watch(vendorCartProvider);
    final cart = ref.read(vendorCartProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final item in stock)
              WholesaleProductCard(
                item: item,
                width: width,
                qty: quantities[item.id] ?? 0,
                onAdd: () => cart.setQuantity(item, item.moq),
                onInc: () =>
                    cart.setQuantity(item, (quantities[item.id] ?? 0) + 1),
                onDec: () =>
                    cart.setQuantity(item, (quantities[item.id] ?? 0) - 1),
              ),
          ],
        );
      },
    );
  }
}
