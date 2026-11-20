import 'package:bakaloo_flutter_app/commerce/commerce_client.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_bottom_bar.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_delivery_header.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_item_card.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bakaloo's cart surfaces connected to the standalone cart and totals API.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key, required this.storefront});

  final Storefront storefront;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  Future<Map<String, dynamic>>? _quote;
  final Map<String, ProductEntity> _knownProducts = {};

  @override
  void initState() {
    super.initState();
    _quote = _requestQuote(ref.read(demoShopProvider).quantities);
  }

  Future<Map<String, dynamic>>? _requestQuote(Map<String, int> quantities) =>
      quantities.isEmpty
      ? null
      : checkoutRequest('quote', {
          'items': [
            for (final entry in quantities.entries)
              {'product_id': entry.key, 'quantity': entry.value},
          ],
        });

  void _change(ProductEntity product, int quantity) =>
      ref.read(demoShopProvider.notifier).setQuantity(product, quantity);

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('All items will be removed from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    ref.read(demoShopProvider.notifier).clearCart();
  }

  @override
  Widget build(BuildContext context) {
    final quantities = ref.watch(
      demoShopProvider.select((cart) => cart.quantities),
    );
    ref.listen(demoShopProvider.select((cart) => cart.quantities), (_, next) {
      setState(() => _quote = _requestQuote(next));
    });
    final catalog = ref.watch(catalogProvider) ?? widget.storefront.products;
    _knownProducts.addEntries(
      catalog.map((product) => MapEntry(product.id, product)),
    );
    final products = quantities.keys
        .map((id) => _knownProducts[id])
        .nonNulls
        .toList();
    final count = quantities.values.fold(0, (sum, quantity) => sum + quantity);
    return FutureBuilder(
      future: _quote,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        final bill = count > 0 && ready
            ? (snapshot.data?['bill'] as Map<String, dynamic>?)
            : null;
        final total = (bill?['totalPayable'] as num?)?.toDouble();
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 16.w,
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF222222),
              ),
            ),
            title: Text(
              count == 0 ? 'My Cart' : 'My Cart ($count)',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF222222),
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            ),
            actions: [
              if (count > 0)
                TextButton(
                  onPressed: _clear,
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: AppColors.cartPink),
                  ),
                ),
            ],
          ),
          body: count == 0
              ? const _EmptyCart()
              : ListView(
                  children: [
                    CartDeliveryHeader(
                      estimateMinutes: widget.storefront.deliveryMinutes,
                      itemCount: count,
                    ),
                    for (final product in products)
                      CartItemCard(
                        item: CartItemEntity(product, quantities[product.id]!),
                        onIncrease: () =>
                            _change(product, quantities[product.id]! + 1),
                        onDecrease: () =>
                            _change(product, quantities[product.id]! - 1),
                        onRemove: () => _change(product, 0),
                        disableIncrease:
                            quantities[product.id]! >= product.stockQuantity ||
                            quantities[product.id]! >= 50,
                      ),
                    if (bill != null) _CartBill(bill: bill),
                    if (!ready) const LinearProgressIndicator(),
                    if (ready && snapshot.hasError)
                      ListTile(
                        title: Text('${snapshot.error}'),
                        trailing: TextButton(
                          onPressed: () => setState(
                            () => _quote = _requestQuote(quantities),
                          ),
                          child: const Text('Retry'),
                        ),
                      ),
                  ],
                ),
          bottomNavigationBar: total == null
              ? null
              : CartBottomBar(
                  hasAddress: true,
                  toPay: total,
                  onlineEnabled: false,
                  onCod: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => CheckoutScreen(products: products),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.shopping_cart_outlined,
          color: AppColors.orderViolet,
          size: 54,
        ),
        const SizedBox(height: 12),
        Text('Your cart is empty', style: AppTextStyles.h2),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Start shopping'),
        ),
      ],
    ),
  );
}

class _CartBill extends StatelessWidget {
  const _CartBill({required this.bill});

  final Map<String, dynamic> bill;

  String _money(String key) {
    final amount = (bill[key] as num).toDouble();
    return '₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.all(12.w),
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bill summary', style: AppTextStyles.h3),
        SizedBox(height: 12.h),
        _row('Items subtotal', _money('itemsSubtotal')),
        _row(
          'Delivery fee',
          bill['deliveryFeeWaived'] == true ? 'FREE' : _money('deliveryFee'),
        ),
        const Divider(),
        _row('To pay', _money('totalPayable'), bold: true),
      ],
    ),
  );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h),
    child: Row(
      children: [
        Expanded(child: Text(label, style: bold ? AppTextStyles.h3 : null)),
        Text(value, style: bold ? AppTextStyles.h3 : null),
      ],
    ),
  );
}
