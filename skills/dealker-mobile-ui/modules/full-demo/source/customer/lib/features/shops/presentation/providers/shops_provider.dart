import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:dealker_app/features/products/data/models/product_model.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/shops/data/shop_summary.dart';
import 'package:dealker_app/features/shops/presentation/providers/shop_distance_provider.dart';
import 'package:dealker_app/routing/route_names.dart';

/// Vendor shops for the Home section: nearest first when the customer has a
/// saved address with coordinates, best rated otherwise.
final nearbyShopsProvider =
    FutureProvider.autoDispose.family<List<ShopSummary>, int>((
  Ref ref,
  int limit,
) async {
  final dio = ref.watch(dioClientProvider);
  final origin = ref.watch(shopOriginProvider);
  final response = await dio.get<dynamic>(
    '/discovery/shops',
    queryParameters: <String, dynamic>{
      'limit': limit,
      if (origin != null) 'lat': origin.lat,
      if (origin != null) 'lng': origin.lng,
      if (origin?.addressId != null) 'addressId': origin!.addressId,
    },
  );
  final body = response.data;
  if (body is! Map || body['data'] is! List) return const <ShopSummary>[];
  return <ShopSummary>[
    for (final dynamic row in body['data'] as List)
      if (row is Map) ShopSummary.fromJson(Map<String, dynamic>.from(row)),
  ];
});

/// Follow state the customer just changed (shop id -> following), applied on
/// top of the list so the button flips instantly and survives list refreshes.
class ShopFollowNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const <String, bool>{};

  bool isFollowing(ShopSummary shop) => state[shop.id] ?? shop.isFollowing;

  /// Followers shown on the card: the server count adjusted for a local change.
  int followers(ShopSummary shop) {
    final bool? local = state[shop.id];
    if (local == null || local == shop.isFollowing) return shop.followerCount;
    return shop.followerCount + (local ? 1 : -1);
  }

  Future<void> toggle(BuildContext context, ShopSummary shop) async {
    final bool allowed =
        await ref.read(authGateControllerProvider).protectRoute(
              context,
              route: RouteNames.home,
              title: 'Log in to follow shops',
              message: 'Follow your favourite shops and find them quickly.',
            );
    if (!allowed) return;
    final bool next = !isFollowing(shop);
    state = <String, bool>{...state, shop.id: next};
    try {
      final dio = ref.read(dioClientProvider);
      if (next) {
        await dio.post<dynamic>('/discovery/shops/${shop.id}/follow');
      } else {
        await dio.delete<dynamic>('/discovery/shops/${shop.id}/follow');
      }
    } catch (_) {
      state = <String, bool>{...state, shop.id: !next};
      if (context.mounted)
        AppToast.show(context, 'Could not update. Try again.');
    }
  }
}

final NotifierProvider<ShopFollowNotifier, Map<String, bool>>
    shopFollowProvider =
    NotifierProvider<ShopFollowNotifier, Map<String, bool>>(
  ShopFollowNotifier.new,
);

/// One shop's profile (header, stats, address, category chips).
final shopProfileProvider = FutureProvider.autoDispose
    .family<ShopProfile, String>((Ref ref, String id) async {
  final dio = ref.watch(dioClientProvider);
  final origin = ref.watch(shopOriginProvider);
  final response = await dio.get<dynamic>(
    '/discovery/shops/$id',
    queryParameters: <String, dynamic>{
      if (origin != null) 'lat': origin.lat,
      if (origin != null) 'lng': origin.lng,
      if (origin?.addressId != null) 'addressId': origin!.addressId,
    },
  );
  final body = response.data;
  if (body is! Map || body['data'] is! Map) {
    throw StateError('Shop not found');
  }
  return ShopProfile.fromJson(Map<String, dynamic>.from(body['data'] as Map));
});

/// (shopId, categoryId or '', deals only) -> that shop's products.
typedef ShopProductsQuery = ({String shopId, String categoryId, bool deals});

final shopProductsProvider = FutureProvider.autoDispose
    .family<List<ProductEntity>, ShopProductsQuery>(
        (Ref ref, ShopProductsQuery q) async {
  final dio = ref.watch(dioClientProvider);
  final response = await dio.get<dynamic>(
    '/discovery/shops/${q.shopId}/products',
    queryParameters: <String, dynamic>{
      'limit': 60,
      if (q.categoryId.isNotEmpty) 'categoryId': q.categoryId,
      if (q.deals) 'deals': 1,
    },
  );
  final body = response.data;
  if (body is! Map || body['data'] is! List) return const <ProductEntity>[];
  final List<ProductEntity> out = <ProductEntity>[];
  for (final dynamic row in body['data'] as List) {
    if (row is! Map) continue;
    try {
      out.add(ProductModel.fromJson(Map<String, dynamic>.from(row)).toEntity());
    } catch (_) {
      // Skip one unparseable product instead of failing the page.
    }
  }
  return out;
});
