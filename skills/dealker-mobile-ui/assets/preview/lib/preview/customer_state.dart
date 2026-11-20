import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/products/domain/entities/product_entity.dart';

typedef ShopDistance = ({String label});

final shopDistanceProvider =
    NotifierProvider<DemoDistances, Map<String, ShopDistance>>(
      DemoDistances.new,
    );

class DemoDistances extends Notifier<Map<String, ShopDistance>> {
  @override
  Map<String, ShopDistance> build() => const {};

  void request(String shopId) {}
}

final authGateControllerProvider = Provider<AuthGateController>(
  (ref) => const AuthGateController(),
);

class AuthGateController {
  const AuthGateController();

  Future<bool> protectAddToCart(
    BuildContext context,
    ProductEntity product,
  ) async => true;
  Future<bool> protectWishlist(
    BuildContext context,
    ProductEntity product,
  ) async => true;
}

class AppToast {
  static void show(BuildContext context, String message) =>
      showCartSnackBar(context, message);
}

void showCartSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void showProductOptionsSheet(BuildContext context, ProductEntity product) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ListTile(
        title: Text(product.name),
        subtitle: Text(product.displayUnit),
      ),
    ),
  );
}

class FixtureResult {
  const FixtureResult([this.failure]);
  final ({String message})? failure;
  bool get isSuccess => failure == null;
}

final cartProvider = NotifierProvider<DemoCart, Map<String, int>>(DemoCart.new);

final cartItemQuantityProvider = Provider.family<int, String>(
  (ref, id) => ref.watch(cartProvider.select((items) => items[id] ?? 0)),
);

final purchaseLimitStatusProvider =
    Provider.family<({bool isAtLimit})?, String>(
      (ref, id) => (isAtLimit: ref.watch(cartItemQuantityProvider(id)) >= 9),
    );

class DemoCart extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  Future<FixtureResult> addItem(
    String id,
    int quantity, {
    ProductEntity? product,
    String? shopProductId,
  }) =>
      updateItem(id, (state[id] ?? 0) + quantity, shopProductId: shopProductId);

  Future<FixtureResult> removeItem(String id, {String? shopProductId}) =>
      updateItem(id, 0, shopProductId: shopProductId);

  Future<FixtureResult> updateItem(
    String id,
    int quantity, {
    String? shopProductId,
  }) async {
    final next = Map<String, int>.of(state);
    if (quantity <= 0) {
      next.remove(id);
    } else {
      next[id] = quantity.clamp(1, 9);
    }
    state = Map.unmodifiable(next);
    return const FixtureResult();
  }
}

typedef WishList = ({List<({String productId})> items});

final wishlistProvider = NotifierProvider<DemoWishlist, AsyncValue<WishList>>(
  DemoWishlist.new,
);

class DemoWishlist extends Notifier<AsyncValue<WishList>> {
  @override
  AsyncValue<WishList> build() => const AsyncData((items: []));

  Future<FixtureResult> toggleWishlist(ProductEntity product) async {
    final current = state.requireValue.items
        .map((entry) => entry.productId)
        .toSet();
    if (!current.remove(product.id)) current.add(product.id);
    state = AsyncData((items: [for (final id in current) (productId: id)]));
    return const FixtureResult();
  }
}
