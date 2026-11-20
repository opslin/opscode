import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_state.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';

/// What `GET /cart/points` says about Dealkr Points for the current cart. All of it is the server's own
/// numbers (balance, the admin's redemption cap applied to this cart, the points this order would earn).
class CartPointsInfo {
  const CartPointsInfo({
    required this.balance,
    required this.pointValue,
    required this.minRedeemable,
    required this.maxRedemptionPct,
    required this.maxPoints,
    required this.earnEstimate,
  });

  factory CartPointsInfo.fromJson(Map<String, dynamic> j) {
    num n(Object? v) => v is num ? v : (num.tryParse('$v') ?? 0);
    return CartPointsInfo(
      balance: n(j['balance']).toInt(),
      pointValue: n(j['pointValue']).toDouble(),
      minRedeemable: n(j['minRedeemable']).toInt(),
      maxRedemptionPct: n(j['maxRedemptionPct']).toDouble(),
      maxPoints: n(j['maxPoints']).toInt(),
      earnEstimate: n(j['earnEstimate']).toInt(),
    );
  }

  final int balance;

  /// Rupees one point is worth.
  final double pointValue;
  final int minRedeemable;
  final double maxRedemptionPct;

  /// Most points this cart may spend right now (0 when below the minimum or the cap is 0).
  final int maxPoints;
  final int earnEstimate;

  double get balanceValue => balance * pointValue;
  bool get canRedeem => maxPoints > 0;
}

/// Null when points are off, the user is a guest, or the cart is empty.
/// [couponDiscount] is the applied coupon's discount: it shrinks what points may cover (same clamp as checkout).
final cartPointsInfoProvider = FutureProvider.autoDispose
    .family<CartPointsInfo?, double>((Ref ref, double couponDiscount) async {
  if (ref.watch(authStateProvider) is! AuthAuthenticated) return null;
  final int items =
      ref.watch(cartProvider.select((a) => a.asData?.value.itemCount ?? 0));
  if (items == 0) return null;
  // The subtotal changes whenever a line does.
  final double subtotal =
      ref.watch(cartProvider.select((a) => a.asData?.value.subtotal ?? 0));
  final dio = ref.watch(dioClientProvider);
  final res =
      await dio.get<dynamic>('/cart/points', queryParameters: <String, dynamic>{
    'couponDiscount': couponDiscount,
    '_':
        subtotal, // cache-buster only: forces a refetch when the cart total moves
  });
  final Object? data = res.data is Map ? (res.data as Map)['data'] : null;
  if (data is! Map || data['enabled'] != true) return null;
  return CartPointsInfo.fromJson(Map<String, dynamic>.from(data));
});

/// The customer's choice on the cart: use points or not, and how many.
class PointsSelection {
  const PointsSelection({this.on = false, this.points = 0});
  final bool on;
  final int points;
}

class CartPointsSelection extends Notifier<PointsSelection> {
  @override
  PointsSelection build() => const PointsSelection();

  void turnOn(int points) => state = PointsSelection(on: true, points: points);
  void turnOff() => state = const PointsSelection();
  void setPoints(int points) =>
      state = PointsSelection(on: true, points: points);
  void reset() => state = const PointsSelection();
}

final NotifierProvider<CartPointsSelection, PointsSelection>
    cartPointsSelectionProvider =
    NotifierProvider<CartPointsSelection, PointsSelection>(
        CartPointsSelection.new);

/// Points that will actually be sent with the order: the choice, clamped to what the server allows now.
final cartPointsAppliedProvider =
    Provider.autoDispose.family<int, double>((Ref ref, double couponDiscount) {
  final PointsSelection sel = ref.watch(cartPointsSelectionProvider);
  final CartPointsInfo? info =
      ref.watch(cartPointsInfoProvider(couponDiscount)).asData?.value;
  if (!sel.on || info == null || !info.canRedeem) return 0;
  return sel.points.clamp(0, info.maxPoints);
});
