import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/core/realtime/live_service.dart';

import 'package:dealker_vendor/features/orders/data/order_models.dart';
import 'package:dealker_vendor/features/orders/data/orders_repository.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>(
    (ref) => OrdersRepository(ref.watch(dioProvider)));

final ordersProvider =
    FutureProvider.autoDispose.family<OrdersPage, OrdersQuery>(
  (ref, q) {
    ref.watch(liveTickProvider);
    return ref.watch(ordersRepositoryProvider).list(q);
  },
);

/// Header badge: how many orders need the vendor right now.
final ordersNeedActionProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(liveTickProvider);
  final p = await ref
      .watch(ordersRepositoryProvider)
      .list(const OrdersQuery(tab: 'new'), limit: 1);
  return p.needsAction;
});

final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderDetail, String>(
  (ref, id) {
    ref.watch(liveTickProvider);
    return ref.watch(ordersRepositoryProvider).detail(id);
  },
);

final repairDetailProvider =
    FutureProvider.autoDispose.family<RepairDetail, String>(
  (ref, id) {
    ref.watch(liveTickProvider);
    return ref.watch(ordersRepositoryProvider).repair(id);
  },
);
