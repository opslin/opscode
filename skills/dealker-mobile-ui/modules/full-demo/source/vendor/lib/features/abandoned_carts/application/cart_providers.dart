import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_models.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_repository.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/demo_cart_repository.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => demoHome
      ? _demoRepo ??= DemoCartRepository()
      : CartRepository(ref.watch(dioProvider)),
);
DemoCartRepository? _demoRepo; // keeps demo data alive across rebuilds

/// A cart a customer just added shows within seconds, so the list and the KPI
/// numbers re-fetch every few seconds while a screen is watching them.
const _cartPollEvery = Duration(seconds: 4);
void _pollWhileWatched(Ref ref) {
  final t = Timer(_cartPollEvery, ref.invalidateSelf);
  ref.onDispose(t.cancel);
}

final cartSummaryProvider =
    FutureProvider.autoDispose.family<CartSummary, CartChannel>((ref, channel) {
  _pollWhileWatched(ref);
  return ref.watch(cartRepositoryProvider).summary(channel: channel);
});

final cartListProvider =
    FutureProvider.autoDispose.family<CartPage, CartQuery>((ref, q) {
  _pollWhileWatched(ref);
  return ref.watch(cartRepositoryProvider).list(q);
});

final cartDetailProvider =
    FutureProvider.autoDispose.family<CartDetail, String>(
  (ref, id) => ref.watch(cartRepositoryProvider).detail(id),
);

/// Key for a preview: template + the products the vendor ticked.
class PreviewKey {
  const PreviewKey(this.cartId, this.templateKey, this.productIds);
  final String cartId;
  final String templateKey;
  final List<String> productIds;

  @override
  bool operator ==(Object other) =>
      other is PreviewKey &&
      other.cartId == cartId &&
      other.templateKey == templateKey &&
      other.productIds.join(',') == productIds.join(',');
  @override
  int get hashCode => Object.hash(cartId, templateKey, productIds.join(','));
}

final reminderPreviewProvider =
    FutureProvider.autoDispose.family<ReminderPreview, PreviewKey>(
  (ref, k) => ref
      .watch(cartRepositoryProvider)
      .preview(k.cartId, k.templateKey, k.productIds),
);

/// Refresh every screen that shows the vendor's abandoned carts.
void refreshCarts(WidgetRef ref, {String? id}) {
  ref
    ..invalidate(cartListProvider)
    ..invalidate(cartSummaryProvider);
  if (id != null) ref.invalidate(cartDetailProvider(id));
}
