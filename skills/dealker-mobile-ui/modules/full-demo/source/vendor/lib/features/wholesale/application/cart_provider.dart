import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/wholesale/application/device_selection.dart';
import 'package:dealker_vendor/features/wholesale/data/wholesale_models.dart';

/// One wholesale listing in the buyer's cart.
class CartLine {
  const CartLine(this.item, this.qty, {this.unitNos});
  final WholesaleItem item;
  final int qty;

  /// The specific devices the buyer chose (used / refurbished / open-box stock); null = the first available.
  final List<int>? unitNos;

  num get total => item.price * qty;

  /// Changing the quantity drops a device choice that no longer matches it.
  CartLine withQty(int q) => CartLine(item, q, unitNos: unitNos != null && unitNos!.length == q ? unitNos : null);
}

/// The B2B cart. Held in memory for the session: the server has no cart yet
/// (see PROGRESS.md "Backend gaps"), so each line becomes its own order at checkout.
class WholesaleCart extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  int qtyOf(String id) {
    for (final l in state) {
      if (l.item.id == id) return l.qty;
    }
    return 0;
  }

  /// Adds [qty] units (the listing's minimum by default), keeping within stock.
  void add(WholesaleItem item, [int? qty, List<int>? unitNos]) {
    final want = qty ?? item.moq;
    final cur = qtyOf(item.id);
    final next = (cur + want)
        .clamp(item.moq, item.stock < item.moq ? item.moq : item.stock);
    state = [
      for (final l in state)
        if (l.item.id != item.id) l,
      CartLine(item, next, unitNos: unitNos != null && unitNos.length == next ? unitNos : null),
    ];
  }

  void setQty(String id, int qty) => state = [
        for (final l in state)
          if (l.item.id == id)
            l.withQty(qty.clamp(l.item.moq,
                l.item.stock < l.item.moq ? l.item.moq : l.item.stock))
          else
            l,
      ];

  /// Quantity change that keeps the device choice in step: more units → the next available devices are added,
  /// fewer → the last ones are dropped. Lines without device tracking just change the number.
  Future<void> changeQty(String id, int qty) async {
    final l = state.where((x) => x.item.id == id).firstOrNull;
    if (l == null) return;
    final q = qty.clamp(l.item.moq, l.item.stock < l.item.moq ? l.item.moq : l.item.stock);
    if (!l.item.deviceTracked) return setQty(id, q);
    var nos = l.unitNos ?? const <int>[];
    try {
      if (nos.length > q) {
        nos = nos.sublist(0, q);
      } else if (nos.length < q) {
        final more = await fetchFirstAvailable(ref.read(dioProvider), l.item.productId!, q - nos.length, skip: nos.toSet());
        nos = [...nos, ...more];
      }
    } catch (_) {
      return setQty(id, q);
    }
    state = [for (final x in state) if (x.item.id == id) CartLine(x.item, q, unitNos: nos.length == q ? nos : null) else x];
  }

  /// The buyer picked devices in the cart sheet: the quantity follows the number of devices.
  void setSelection(String id, List<int> nos) => state = [
        for (final x in state)
          if (x.item.id == id) CartLine(x.item, nos.length, unitNos: nos) else x,
      ];

  void setDevices(String id, List<int> nos) => state = [
        for (final l in state)
          if (l.item.id == id) CartLine(l.item, l.qty, unitNos: nos.length == l.qty ? nos : null) else l,
      ];

  void remove(String id) => state = [
        for (final l in state)
          if (l.item.id != id) l
      ];

  void clear() => state = const [];
}

final wholesaleCartProvider =
    NotifierProvider<WholesaleCart, List<CartLine>>(WholesaleCart.new);

final cartCountProvider = Provider<int>(
    (ref) => ref.watch(wholesaleCartProvider).fold(0, (n, l) => n + 1));
