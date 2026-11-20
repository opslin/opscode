import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:dealker_app/features/orders/presentation/providers/order_list_provider.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_ui.dart';
import 'package:dealker_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/refund_request_provider.dart';

/// Why the orders could not be loaded: no connection vs. a server problem.
class OrdersLoadError implements Exception {
  const OrdersLoadError({required this.offline, required this.message});
  final bool offline;
  final String message;
}

/// One order with the phase the customer sees (a delivered order with an open
/// return request shows as "Return in progress").
class OrderRow {
  const OrderRow(this.order, this.request, this.phase);
  final OrderEntity order;
  final RefundRequestStatusEntity? request;
  final OrderPhase phase;
}

/// Every order of the signed-in customer (the API returns them all in one
/// list), newest first, each with its return request when it can have one.
/// Tabs, counts and search are worked out on this list.
final FutureProvider<List<OrderRow>> myOrdersProvider =
    FutureProvider.autoDispose<List<OrderRow>>((Ref ref) async {
  final result = await ref.read(getOrdersUseCaseProvider).call(limit: 100);
  final List<OrderEntity> orders = result.fold(
    (Failure f) => throw OrdersLoadError(
      offline: f is NetworkFailure,
      message: f.message,
    ),
    (page) => page.orders.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
  return Future.wait(orders.map((OrderEntity o) async {
    RefundRequestStatusEntity? request;
    if (canHaveReturn(o)) {
      try {
        request = await ref.read(refundRequestByOrderProvider(o.id).future);
      } catch (_) {
        request = null;
      }
    }
    return OrderRow(o, request, orderPhase(o, request: request));
  }));
});

bool canHaveReturn(OrderEntity o) =>
    o.rawStatus == 'DELIVERED' ||
    o.rawStatus == 'COMPLETED' ||
    o.rawStatus == 'CLOSED' ||
    o.rawStatus == 'REFUNDED' ||
    o.rawStatus == 'RETURNED' ||
    o.rawStatus == 'RETURN_REQUESTED' ||
    o.status == OrderStatus.DELIVERED ||
    o.status == OrderStatus.REFUNDED;
