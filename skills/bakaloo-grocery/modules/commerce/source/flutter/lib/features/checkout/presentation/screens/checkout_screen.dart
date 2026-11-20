import 'package:bakaloo_flutter_app/commerce/commerce_client.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

part 'checkout_sections.dart';

String _money(double value) =>
    '₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.products});
  final List<ProductEntity> products;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late Map<String, int> _items;
  Map<String, dynamic>? _quote;
  Map<String, dynamic>? _order;
  bool _pending = false;
  String? _error;
  String _requestId = checkoutReference();

  @override
  void initState() {
    super.initState();
    _items = Map.of(ref.read(demoShopProvider).quantities);
    if (_items.isNotEmpty) _calculate();
  }

  List<Map<String, Object>> get _requestItems => [
    for (final item in _items.entries)
      {'product_id': item.key, 'quantity': item.value},
  ];

  Future<void> _calculate() async {
    setState(() {
      _quote = null;
      _error = null;
      _pending = _items.isNotEmpty;
    });
    if (_items.isEmpty) return;
    try {
      final quote = await checkoutRequest('quote', {'items': _requestItems});
      if (mounted) setState(() => _quote = quote);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _change(ProductEntity product, int quantity) {
    ref.read(demoShopProvider.notifier).setQuantity(product, quantity);
    _items = Map.of(ref.read(demoShopProvider).quantities);
    _requestId = checkoutReference();
    _calculate();
  }

  Future<void> _place(double total) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final order = await checkoutRequest('orders', {
        'items': _requestItems,
        'request_id': _requestId,
        'quoted_total': total,
      });
      if (!mounted) return;
      for (final product in widget.products.where(
        (p) => _items.containsKey(p.id),
      )) {
        ref.read(demoShopProvider.notifier).setQuantity(product, 0);
      }
      ref.invalidate(catalogProvider);
      setState(() => _order = order);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_order case final result?) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order confirmation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primaryGreen,
                  size: 60,
                ),
                const SizedBox(height: 18),
                Text('Demo order placed', style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(result['orderNumber'] as String, style: AppTextStyles.h2),
                const SizedBox(height: 6),
                Text(
                  '${_money((result['totalAmount'] as num).toDouble())} due on delivery',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Continue shopping'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final bill = _quote?['bill'] as Map<String, dynamic>?;
    final total = (bill?['totalPayable'] as num?)?.toDouble();
    final productsById = {
      for (final product in widget.products) product.id: product,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      bottomNavigationBar: total == null
          ? null
          : _CheckoutBottomBar(
              total: total,
              isLoading: _pending,
              onPlaceOrder: () => _place(total),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_items.isEmpty)
            const ListTile(title: Text('Your cart is empty.'))
          else ...[
            Text('Delivery address', style: AppTextStyles.h3),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.location_on_outlined),
              title: Text('Home'),
              subtitle: Text('12 Lake View Road, Bengaluru'),
            ),
            const Divider(),
            Text('Review items', style: AppTextStyles.h3),
            for (final entry in _items.entries)
              if (productsById[entry.key] case final product?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(product.name),
                  subtitle: Text(product.unit),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Remove one ${product.name}',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _pending
                            ? null
                            : () => _change(product, entry.value - 1),
                      ),
                      Text('${entry.value}'),
                      IconButton(
                        tooltip: 'Add one ${product.name}',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed:
                            _pending ||
                                entry.value >= product.stockQuantity ||
                                entry.value >= 50
                            ? null
                            : () => _change(product, entry.value + 1),
                      ),
                    ],
                  ),
                ),
            const Divider(),
            Text('Payment', style: AppTextStyles.h3),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.payments_outlined),
              title: Text('Cash on delivery'),
              subtitle: Text('Demo checkout. No payment is collected.'),
            ),
            if (bill != null) ...[
              const Divider(),
              _BillRow(
                label: 'Items subtotal',
                value: (bill['itemsSubtotal'] as num).toDouble(),
              ),
              const SizedBox(height: 10),
              _BillRow(
                label: 'Delivery fee',
                isFree: bill['deliveryFeeWaived'] == true,
                value: (bill['deliveryFee'] as num).toDouble(),
              ),
            ],
          ],
          if (_pending)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: _pending ? null : _calculate,
              child: const Text('Refresh quote'),
            ),
          ],
        ],
      ),
    );
  }
}
