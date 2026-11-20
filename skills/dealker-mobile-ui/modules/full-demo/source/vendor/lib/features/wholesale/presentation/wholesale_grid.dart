import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_vendor/features/wholesale/application/cart_provider.dart';
import 'package:dealker_vendor/features/wholesale/data/wholesale_models.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/wholesale_product_card.dart';

/// One marketplace card wired to the cart: Add → stepper; minus at the minimum order removes it (with Undo).
class CartAwareCard extends ConsumerWidget {
  const CartAwareCard({super.key, required this.item, required this.width});
  final WholesaleItem item;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(wholesaleCartProvider.select(
        (l) => l.where((x) => x.item.id == item.id).fold(0, (_, x) => x.qty)));
    final cart = ref.read(wholesaleCartProvider.notifier);
    return WholesaleProductCard(
      item: item,
      width: width,
      qty: qty,
      onTap: () => context.push(Routes.wholesaleView(item.id)),
      onAdd: () => cart.add(item),
      onInc: () => cart.setQty(item.id, qty + 1),
      onDec: () {
        if (qty > item.moq) {
          cart.setQty(item.id, qty - 1);
        } else {
          cart.remove(item.id);
          showUndoBar(
              context, 'Removed ${item.name}', () => cart.add(item, qty));
        }
      },
    );
  }
}

/// Two-column grid of marketplace cards.
class WholesaleGrid extends StatelessWidget {
  const WholesaleGrid({super.key, required this.items});
  final List<WholesaleItem> items;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - _gap) / 2;
        return Wrap(spacing: _gap, runSpacing: _gap, children: [
          for (final it in items) CartAwareCard(item: it, width: w),
        ]);
      });
}

/// Horizontally scrolling row of marketplace cards (deals, home preview).
class WholesaleHRow extends StatelessWidget {
  const WholesaleHRow({super.key, required this.items});
  final List<WholesaleItem> items;

  @override
  Widget build(BuildContext context) {
    const w = 172.0;
    return SizedBox(
      height: WholesaleProductCard.heightFor(w) + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => CartAwareCard(item: items[i], width: w),
      ),
    );
  }
}
