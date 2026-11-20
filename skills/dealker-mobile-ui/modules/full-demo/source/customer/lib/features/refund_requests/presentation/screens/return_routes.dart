import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:dealker_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/refund_request_provider.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_chat_screen.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_request_screen.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_tracking_screen.dart';
import 'package:dealker_app/features/refund_requests/presentation/widgets/return_ui.dart';

/// Where the return flow lives in go_router (root level, so the shell's bottom nav is not shown).
class ReturnRoutes {
  ReturnRoutes._();

  static String start(String orderId) => '/returns/$orderId/new';
  static String tracking(String orderId) => '/returns/$orderId';
  static String chat(String orderId) => '/returns/$orderId/chat';
  static String policy({String? orderId}) =>
      orderId == null ? '/returns/policy' : '/returns/policy?orderId=$orderId';
}

Widget _loading(String title) => ReturnScaffold(
      title: title,
      child: const Center(
        child: CircularProgressIndicator(color: ReturnColors.indigo),
      ),
    );

Widget _failed(String title, VoidCallback retry) => ReturnScaffold(
      title: title,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Could not load this order.'),
            TextButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      ),
    );

/// Loads the order, then shows the screen built for it.
class _WithOrder extends ConsumerWidget {
  const _WithOrder({
    required this.orderId,
    required this.title,
    required this.builder,
  });

  final String orderId;
  final String title;
  final Widget Function(OrderEntity order) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(orderDetailProvider(orderId)).when(
          loading: () => _loading(title),
          error: (Object e, StackTrace _) => _failed(
            title,
            () => ref.invalidate(orderDetailProvider(orderId)),
          ),
          data: builder,
        );
  }
}

class ReturnRequestRoute extends StatelessWidget {
  const ReturnRequestRoute({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) => _WithOrder(
        orderId: orderId,
        title: 'Return Request',
        builder: (OrderEntity order) => ReturnRequestScreen(order: order),
      );
}

class ReturnTrackingRoute extends StatelessWidget {
  const ReturnTrackingRoute({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) => _WithOrder(
        orderId: orderId,
        title: 'Return Tracking',
        builder: (OrderEntity order) => ReturnTrackingScreen(order: order),
      );
}

class ReturnChatRoute extends ConsumerWidget {
  const ReturnChatRoute({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _WithOrder(
      orderId: orderId,
      title: 'Chat with Support',
      builder: (OrderEntity order) {
        final AsyncValue<RefundRequestStatusEntity?> req =
            ref.watch(refundRequestByOrderProvider(orderId));
        final RefundRequestStatusEntity? r = req.asData?.value;
        if (r == null) {
          return req.isLoading
              ? _loading('Chat with Support')
              : _failed(
                  'Chat with Support',
                  () => ref.invalidate(refundRequestByOrderProvider(orderId)),
                );
        }
        return ReturnChatScreen(request: r, order: order);
      },
    );
  }
}
