import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/constants/app_constants.dart';
import 'package:dealker_app/core/files/pdf_file.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/core/utils/extensions/double_extensions.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_theme.dart';
import 'package:dealker_app/features/auth/domain/entities/user_entity.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:dealker_app/features/orders/presentation/providers/active_order_provider.dart';
import 'package:dealker_app/features/orders/presentation/providers/my_orders_provider.dart';
import 'package:dealker_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:dealker_app/features/orders/presentation/providers/order_list_provider.dart';
import 'package:dealker_app/features/orders/presentation/widgets/b2b_credit_info.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_ui.dart';
import 'package:dealker_app/features/refund_requests/data/return_policy_repository.dart';
import 'package:dealker_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/refund_request_provider.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/return_providers.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_routes.dart';
import 'package:dealker_app/features/reviews/presentation/screens/order_review_screen.dart';
import 'package:dealker_app/features/tracking/data/shipment_repository.dart';
import 'package:dealker_app/features/tracking/presentation/screens/order_tracking_screen.dart';
import 'package:dealker_app/routing/app_router.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/cancel_order_sheet.dart';

/// Order Details — designs `10-order-details-top.webp`, `08-order-details-bottom.webp`
/// and the delivered / return / refund / payment-failed tiles of `07-orders-states-sheet.webp`.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _cancelling = false;
  bool _reordering = false;
  bool _downloading = false;

  Future<void> _cancel(OrderEntity order) async {
    if (_cancelling) return;
    final String? reason =
        await CancelOrderSheet.show(context, orderNumber: order.orderNumber);
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    final result = await ref
        .read(orderListControllerProvider)
        .cancelOrder(order.id, reason: reason);
    if (!mounted) return;
    setState(() => _cancelling = false);
    result.fold(
      (failure) => AppToast.show(context, failure.message),
      (_) {
        ref
          ..invalidate(activeOrderProvider)
          ..invalidate(myOrdersProvider)
          ..invalidate(orderDetailProvider(order.id));
        AppToast.show(
          context,
          'Order cancelled successfully',
          type: ToastType.success,
        );
      },
    );
  }

  Future<void> _reorder(OrderEntity order) async {
    if (_reordering) return;
    setState(() => _reordering = true);
    final result =
        await ref.read(orderListControllerProvider).reorder(order.id);
    if (!mounted) return;
    setState(() => _reordering = false);
    result.fold(
      (failure) => AppToast.show(context, failure.message),
      (data) {
        ref.invalidate(cartProvider);
        final String warnings =
            data.warnings.isEmpty ? '' : '\n${data.warnings.join('\n')}';
        AppToast.show(
          context,
          'Items added to cart$warnings',
          type: ToastType.success,
        );
        context.push(RouteNames.cart);
      },
    );
  }

  Future<void> _invoice(OrderEntity order) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final result =
        await ref.read(orderListControllerProvider).downloadInvoice(order.id);
    if (!mounted) return;
    setState(() => _downloading = false);
    await result.fold(
      (failure) async => AppToast.show(context, failure.message),
      (file) async {
        final bool opened = await openSavedPdf(file.path);
        if (!mounted) return;
        final String message = opened
            ? kIsWeb
                ? 'Invoice download started: ${file.fileName}'
                : 'Invoice downloaded: ${file.fileName}'
            : 'Could not open the invoice.';
        AppToast.show(
          context,
          message,
          type: message.startsWith('Invoice')
              ? ToastType.success
              : ToastType.error,
        );
      },
    );
  }

  Future<void> _openReturn(OrderEntity order, {required bool existing}) async {
    await context.push(
      existing ? ReturnRoutes.tracking(order.id) : ReturnRoutes.start(order.id),
    );
    ref
      ..invalidate(refundRequestByOrderProvider(order.id))
      ..invalidate(orderDetailProvider(order.id))
      ..invalidate(myOrdersProvider);
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    AppToast.show(context, '$what copied', type: ToastType.success);
  }

  void _support(OrderEntity order, [String? topic]) {
    final String q = 'order=${Uri.encodeComponent(order.orderNumber)}'
        '${topic == null ? '' : '&topic=${Uri.encodeComponent(topic)}'}';
    context.push('${RouteNames.supportChat}?$q');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<OrderEntity> async =
        ref.watch(orderDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: OV.canvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: <Widget>[
            _Bar(
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(RouteNames.orders),
              onSupport: async.asData == null
                  ? null
                  : () => _support(async.asData!.value),
            ),
            Expanded(
              child: async.when(
                loading: () => const DealkerPageLoader(),
                error: (Object e, _) => StateView(
                  art: const CloudArt(offline: false),
                  title: "Couldn't load this order",
                  body: e.toString().replaceFirst('Bad state: ', ''),
                  button: StateButton(
                    label: 'Retry',
                    onTap: () => ref.invalidate(orderDetailProvider(widget.id)),
                  ),
                ),
                data: _body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(OrderEntity order) {
    final RefundRequestStatusEntity? request =
        ref.watch(refundRequestByOrderProvider(order.id)).asData?.value;
    final List<OrderShipment> shipments =
        ref.watch(orderShipmentsProvider(order.id)).asData?.value ??
            const <OrderShipment>[];
    final ReturnPolicy? policy = ref.watch(returnPolicyProvider).asData?.value;
    final UserEntity? user = ref.watch(currentUserProvider);
    final OrderPhase phase = orderPhase(order, request: request);
    final bool hasRequest = request != null && request.blocksNewRequest;
    final DateTime? deliveredAt =
        order.deliveredAt ?? order.statusTimes['DELIVERED'];
    final bool returnOpen = phase == OrderPhase.delivered &&
        !hasRequest &&
        policy != null &&
        deliveredAt != null &&
        policy.isOpen(deliveredAt);

    final Widget? footer = _footer(order, phase, hasRequest, returnOpen);

    return Column(
      children: <Widget>[
        Expanded(
          child: RefreshIndicator(
            color: AU.indigo,
            onRefresh: () async {
              ref
                ..invalidate(orderDetailProvider(order.id))
                ..invalidate(orderShipmentsProvider(order.id))
                ..invalidate(refundRequestByOrderProvider(order.id));
              await ref.read(orderDetailProvider(order.id).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                12.w,
                12.h,
                12.w,
                footer == null ? 28.h : 16.h,
              ),
              children: <Widget>[
                _StatusCard(
                  order: order,
                  phase: phase,
                  request: request,
                  shipments: shipments,
                  onCopy: () => _copy(order.orderNumber, 'Order number'),
                ),
                if (phase != OrderPhase.paymentFailed)
                  _TimelineCard(
                    order: order,
                    phase: phase,
                    request: request,
                    shipments: shipments,
                    onCopyAwb: (String awb) => _copy(awb, 'Tracking ID'),
                  ),
                if (phase == OrderPhase.returnInProgress && request != null)
                  _ReturnDetails(
                    order: order,
                    request: request,
                    onCopy: (String t) => _copy(t, 'Tracking ID'),
                  ),
                if (phase == OrderPhase.refunded)
                  _RefundSummary(
                    order: order,
                    request: request,
                    onCopy: (String t) => _copy(t, 'Reference ID'),
                    onWallet: () => context.push(RouteNames.wallet),
                  ),
                _ItemsCard(
                  order: order,
                  phase: phase,
                  shipments: shipments,
                  returnWindow: returnOpen ? (policy, deliveredAt) : null,
                  onReview: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => OrderReviewScreen(order: order),
                    ),
                  ),
                  onBuyAgain: () => _reorder(order),
                  buyAgainBusy: _reordering,
                  onOpenProduct: (OrderItemEntity i) =>
                      context.push('/product/${i.productId}'),
                ),
                if (phase == OrderPhase.paymentFailed)
                  _PaymentFailedNote(
                    order: order,
                    onRetry: () => _reorder(order),
                    busy: _reordering,
                  ),
                if (order.isB2BCredit)
                  OrderCardBox(child: B2BCreditInfo(order: order)),
                if (phase != OrderPhase.paymentFailed) ...<Widget>[
                  _DeliveryCard(order: order, user: user),
                  _PaymentCard(order: order),
                  _MoreOptions(
                    phase: phase,
                    cancelling: _cancelling,
                    downloading: _downloading,
                    onInvoice: () => _invoice(order),
                    onBuyAgain: () => _reorder(order),
                    onPolicy: () =>
                        context.push('/returns/policy?orderId=${order.id}'),
                    onCancel: () => _cancel(order),
                  ),
                ],
                if (phase == OrderPhase.paymentFailed)
                  _NeedHelpRow(onTap: () => _support(order, 'Payment issue'))
                else
                  _HelpCard(
                    onChat: () => _support(order),
                    onTopic: (String t) => _support(order, t),
                    orderNumber: order.orderNumber,
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(4.w, 4.h, 4.w, 8.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        PhosphorIconsRegular.shieldCheck,
                        size: 20.sp,
                        color: AU.muted,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'For any return, refund or other concerns, '
                          'please reach out to our support team.',
                          style: dm(12.5.sp, color: AU.muted, h: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (footer != null)
          Container(
            padding: EdgeInsets.fromLTRB(
              16.w,
              10.h,
              16.w,
              10.h + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: OV.divider)),
            ),
            child: footer,
          ),
      ],
    );
  }

  Widget? _footer(
    OrderEntity order,
    OrderPhase phase,
    bool hasRequest,
    bool returnOpen,
  ) {
    switch (phase) {
      case OrderPhase.placed:
      case OrderPhase.confirmed:
      case OrderPhase.packed:
      case OrderPhase.shipped:
      case OrderPhase.outForDelivery:
        return OrderPrimaryButton(
          label: 'Track Order',
          icon: PhosphorIconsRegular.truck,
          onTap: () => context.push('/orders/${order.id}/track'),
        );
      case OrderPhase.delivered:
        if (returnOpen) {
          return OrderPrimaryButton(
            label: 'Return Items',
            onTap: () => _openReturn(order, existing: false),
          );
        }
        return OrderPrimaryButton(
          label: 'Buy it again',
          busy: _reordering,
          onTap: () => _reorder(order),
        );
      case OrderPhase.returnInProgress:
        return OrderPrimaryButton(
          label: 'Track Return',
          onTap: () => _openReturn(order, existing: true),
        );
      case OrderPhase.refunded:
      case OrderPhase.cancelled:
        return OrderPrimaryButton(
          label: 'Buy it again',
          busy: _reordering,
          onTap: () => _reorder(order),
        );
      case OrderPhase.paymentFailed:
        return null;
    }
  }
}

// ── App bar ──────────────────────────────────────────────────────────────────

class _Bar extends StatelessWidget {
  const _Bar({required this.onBack, required this.onSupport});
  final VoidCallback onBack;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          8.w,
          MediaQuery.of(context).padding.top + 6.h,
          8.w,
          6.h,
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: onBack,
              icon: Icon(
                PhosphorIconsRegular.arrowLeft,
                size: 26.sp,
                color: AU.ink,
              ),
            ),
            Expanded(child: Text('Order Details', style: jakarta(21.sp))),
            IconButton(
              onPressed: onSupport,
              icon: Icon(
                PhosphorIconsRegular.headset,
                size: 26.sp,
                color: AU.ink,
              ),
            ),
          ],
        ),
      );
}

// ── Status card (order number, headline, stepper, next-step band) ───────────

const List<String> _stageLabels = <String>[
  'Placed',
  'Confirmed',
  'Packed',
  'Shipped',
  'Out for\ndelivery',
  'Delivered',
];

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.order,
    required this.phase,
    required this.request,
    required this.shipments,
    required this.onCopy,
  });

  final OrderEntity order;
  final OrderPhase phase;
  final RefundRequestStatusEntity? request;
  final List<OrderShipment> shipments;
  final VoidCallback onCopy;

  DateTime? get _eta {
    for (final OrderShipment s in shipments) {
      if (s.estimatedDelivery != null) return s.estimatedDelivery;
    }
    return order.estimatedDelivery;
  }

  @override
  Widget build(BuildContext context) {
    return OrderCardBox(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onTap: onCopy,
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    'Order #${order.orderNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(17.sp),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(PhosphorIconsRegular.copy, size: 18.sp, color: AU.indigo),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: <Widget>[
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Placed on ${fullStamp(order.createdAt)}',
                    maxLines: 1,
                    style: dm(12.sp, color: AU.muted),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              OrderPill(phase: phase),
            ],
          ),
          ..._variant(),
        ],
      ),
    );
  }

  List<Widget> _variant() {
    switch (phase) {
      case OrderPhase.placed:
      case OrderPhase.confirmed:
      case OrderPhase.packed:
      case OrderPhase.shipped:
      case OrderPhase.outForDelivery:
        return _active();
      case OrderPhase.delivered:
        final DateTime? at =
            order.deliveredAt ?? order.statusTimes['DELIVERED'];
        return <Widget>[
          SizedBox(height: 14.h),
          _Banner(
            icon: PhosphorIconsFill.checkCircle,
            color: OV.green,
            bg: OV.greenSoft,
            title: at != null ? 'Delivered on ${shortDate(at)}' : 'Delivered',
            body: 'Your order has been delivered successfully.',
          ),
        ];
      case OrderPhase.cancelled:
        final DateTime? at =
            order.cancelledAt ?? order.statusTimes['CANCELLED'];
        final String reason = (order.cancelledReason ?? '').trim();
        return <Widget>[
          SizedBox(height: 14.h),
          _Banner(
            icon: PhosphorIconsFill.xCircle,
            color: OV.red,
            bg: OV.redSoft,
            title: at != null
                ? 'Cancelled on ${shortDate(at)}'
                : 'Order cancelled',
            body: reason.isNotEmpty
                ? reason
                : 'This order was cancelled and will not be delivered.',
          ),
        ];
      case OrderPhase.paymentFailed:
        return <Widget>[
          SizedBox(height: 14.h),
          _Banner(
            icon: PhosphorIconsFill.warningCircle,
            color: OV.red,
            bg: OV.redSoft,
            title: 'Payment was not completed',
            body: 'Your order is not confirmed. You can try payment again '
                'or choose a different method.',
          ),
          SizedBox(height: 16.h),
          _FailedStepper(
            at: order.cancelledAt ??
                order.statusTimes['CANCELLED'] ??
                order.createdAt,
          ),
        ];
      case OrderPhase.returnInProgress:
        final String s = request?.pickup?.status ?? '';
        final (String t, String b) = switch (s) {
          'PICKUP_SCHEDULED' => (
              'Return pickup scheduled',
              'Our courier partner will pick up your item soon.',
            ),
          'PICKED_UP' => (
              'Return picked up',
              'Our courier partner has picked up your item. '
                  'It will be inspected shortly.',
            ),
          'IN_TRANSIT' => (
              'Return in transit',
              'Your item is on its way back to the seller.',
            ),
          'RECEIVED' => (
              'Return received',
              'The seller has received your item and is inspecting it.',
            ),
          _ => (
              'Return requested',
              'Our team is reviewing your return request.',
            ),
        };
        return <Widget>[
          SizedBox(height: 14.h),
          _Banner(
            icon: PhosphorIconsRegular.arrowsClockwise,
            color: OV.amber,
            bg: OV.amberSoft,
            title: t,
            body: b,
          ),
        ];
      case OrderPhase.refunded:
        final double amount = request?.refundAmount ?? order.total;
        final String where = request?.refundTo == 'original'
            ? 'original payment method'
            : 'Dealkr Wallet';
        return <Widget>[
          SizedBox(height: 14.h),
          _Banner(
            icon: PhosphorIconsFill.checkCircle,
            color: OV.green,
            bg: OV.greenSoft,
            title: request?.refundTo == 'original'
                ? 'Refund sent'
                : 'Refund credited to wallet',
            body: 'We have refunded ${amount.toInrCurrency} to your $where.',
          ),
        ];
    }
  }

  List<Widget> _active() {
    final int idx = phase.stageIndex;
    final DateTime? eta = _eta;
    final String headline = switch (phase) {
      OrderPhase.placed => 'Your order is placed',
      OrderPhase.confirmed => 'Your order is confirmed',
      OrderPhase.packed => 'Your order is packed',
      OrderPhase.shipped => 'Your order is on the way',
      _ => 'Your order is out for delivery',
    };
    final String next = _stageLabels[idx + 1].replaceAll('\n', ' ');
    final String current = _stageLabels[idx].replaceAll('\n', ' ');
    final String note = switch (phase) {
      OrderPhase.placed => 'We have sent your order to the seller.',
      OrderPhase.confirmed => 'The seller has confirmed your order.',
      OrderPhase.packed => 'Your order is packed and ready for the courier.',
      OrderPhase.shipped =>
        'Your order has been shipped and is on its way to you.',
      _ => 'Your order is out for delivery today.',
    };
    return <Widget>[
      SizedBox(height: 14.h),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(headline, style: jakarta(25.sp, h: 1.15)),
                if (eta != null) ...<Widget>[
                  SizedBox(height: 6.h),
                  Text(
                    'Arriving by ${dayDate(eta)}',
                    style: dm(15.sp, color: AU.muted),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 10.w),
          CartArtImage(phase.art, size: 92.w, float: true),
        ],
      ),
      SizedBox(height: 14.h),
      _Stepper(current: idx),
      SizedBox(height: 16.h),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: OV.indigoBand,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: <Widget>[
            CartArtImage(CartArt.track, size: 36.w, float: true),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: current,
                          style: jakarta(14.5.sp),
                        ),
                        TextSpan(
                          text: '  ·  Next: $next',
                          style: dm(14.5.sp, color: AU.ink),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(note, style: dm(13.sp, color: AU.muted, h: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// Green / red / amber summary strip under the order number.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String body;

  CartArt _art() {
    final String t = title.toLowerCase();
    if (t.contains('refund')) return CartArt.refund;
    if (icon == PhosphorIconsFill.checkCircle) return CartArt.delivered;
    if (icon == PhosphorIconsFill.xCircle ||
        icon == PhosphorIconsFill.warningCircle) {
      return CartArt.cancelled;
    }
    return CartArt.returned;
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: <Widget>[
            CartArtImage(_art(), size: 46.w, float: true),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: jakarta(16.sp)),
                  SizedBox(height: 3.h),
                  Text(body, style: dm(13.sp, color: AU.muted, h: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Placed · Confirmed · Packed · Shipped · Out for delivery · Delivered.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final double big = 36.w, small = 24.w;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < 6; i++) ...<Widget>[
              SizedBox(
                width: big + 10,
                height: big + 10,
                child: Center(child: _dot(i, small, big)),
              ),
              if (i < 5)
                Expanded(
                  child: Container(
                    height: 3,
                    color: i < current ? AU.indigo : const Color(0xFFD9DDEA),
                  ),
                ),
            ],
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < 6; i++)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: i == 0
                      ? Alignment.topLeft
                      : i == 5
                          ? Alignment.topRight
                          : Alignment.topCenter,
                  child: Text(
                    _stageLabels[i],
                    textAlign: i == 0
                        ? TextAlign.left
                        : i == 5
                            ? TextAlign.right
                            : TextAlign.center,
                    style: i == current
                        ? jakarta(11.sp, color: AU.indigo, h: 1.25)
                        : dm(11.sp, color: AU.muted, h: 1.25),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dot(int i, double small, double big) {
    if (i == current) {
      return Container(
        width: big + 10,
        height: big + 10,
        decoration: BoxDecoration(
          color: AU.indigoSoft,
          shape: BoxShape.circle,
          border: Border.all(color: AU.indigo.withValues(alpha: .25), width: 1.5),
        ),
        child: Center(
            child: CartArtImage(kStageArt[i], size: big + 2, float: true)),
      );
    }
    if (i < current) {
      return Container(
        width: small,
        height: small,
        decoration:
            const BoxDecoration(color: AU.indigo, shape: BoxShape.circle),
        child: Icon(PhosphorIconsBold.check, size: 14.sp, color: Colors.white),
      );
    }
    return Container(
      width: small,
      height: small,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF9AA1B8), width: 1.6),
      ),
    );
  }
}

// ── Timeline card (+ shipping details) ───────────────────────────────────────

enum _Mark { done, current, upcoming, failed }

class _Step {
  const _Step(this.title, this.sub, this.mark);
  final String title;
  final String? sub;
  final _Mark mark;
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.order,
    required this.phase,
    required this.request,
    required this.shipments,
    required this.onCopyAwb,
  });

  final OrderEntity order;
  final OrderPhase phase;
  final RefundRequestStatusEntity? request;
  final List<OrderShipment> shipments;
  final ValueChanged<String> onCopyAwb;

  DateTime? _t(List<String> keys) {
    for (final String k in keys) {
      final DateTime? d = order.statusTimes[k];
      if (d != null) return d;
    }
    return null;
  }

  List<_Step> _steps() {
    final DateTime placed =
        _t(<String>['ORDER_PLACED', 'PENDING']) ?? order.createdAt;
    switch (phase) {
      case OrderPhase.placed:
      case OrderPhase.confirmed:
      case OrderPhase.packed:
      case OrderPhase.shipped:
      case OrderPhase.outForDelivery:
        final int cur = phase.stageIndex;
        final List<DateTime?> times = <DateTime?>[
          placed,
          _t(<String>['CONFIRMED', 'PREPARING']),
          _t(<String>['PACKED', 'READY_TO_SHIP']),
          _t(<String>['SHIPPED', 'PICKED_UP', 'IN_TRANSIT']),
          _t(<String>['OUT_FOR_DELIVERY']),
          null,
        ];
        DateTime? eta = order.estimatedDelivery;
        for (final OrderShipment s in shipments) {
          eta ??= s.estimatedDelivery;
        }
        const List<String> titles = <String>[
          'Order placed',
          'Confirmed',
          'Packed',
          'Shipped',
          'Out for delivery',
          'Delivered',
        ];
        return <_Step>[
          for (int i = 0; i < 6; i++)
            _Step(
              titles[i],
              times[i] != null && i <= cur
                  ? fullStamp(times[i]!)
                  : i == 5
                      ? (eta != null
                          ? 'Arriving by ${dayDate(eta)}'
                          : 'Expected soon')
                      : i > cur
                          ? 'Expected soon'
                          : null,
              i < cur
                  ? _Mark.done
                  : i == cur
                      ? _Mark.current
                      : _Mark.upcoming,
            ),
        ];
      case OrderPhase.delivered:
        final List<(String, DateTime?)> all = <(String, DateTime?)>[
          ('Order placed', placed),
          ('Confirmed', _t(<String>['CONFIRMED', 'PREPARING'])),
          ('Packed', _t(<String>['PACKED', 'READY_TO_SHIP'])),
          ('Shipped', _t(<String>['SHIPPED', 'PICKED_UP', 'IN_TRANSIT'])),
          ('Out for delivery', _t(<String>['OUT_FOR_DELIVERY'])),
          (
            'Delivered',
            order.deliveredAt ?? _t(<String>['DELIVERED']),
          ),
        ];
        return <_Step>[
          for (final (String, DateTime?) e in all)
            if (e.$2 != null || e.$1 == 'Delivered')
              _Step(
                e.$1,
                e.$2 != null ? fullStamp(e.$2!) : null,
                _Mark.done,
              ),
        ];
      case OrderPhase.cancelled:
        return <_Step>[
          _Step('Order placed', fullStamp(placed), _Mark.done),
          _Step(
            'Cancelled',
            (order.cancelledAt ?? _t(<String>['CANCELLED'])) != null
                ? fullStamp((order.cancelledAt ?? _t(<String>['CANCELLED']))!)
                : null,
            _Mark.failed,
          ),
        ];
      case OrderPhase.paymentFailed:
        return <_Step>[
          _Step(
            'Payment failed',
            fullStamp(order.cancelledAt ??
                _t(<String>['CANCELLED']) ??
                order.createdAt),
            _Mark.failed,
          ),
          const _Step('Confirming', null, _Mark.upcoming),
          const _Step('Packing', null, _Mark.upcoming),
          const _Step('Shipping', null, _Mark.upcoming),
          const _Step('Delivery', null, _Mark.upcoming),
        ];
      case OrderPhase.returnInProgress:
        final RefundRequestStatusEntity? r = request;
        final String ps = r?.pickup?.status ?? '';
        final bool pickedUp =
            ps == 'PICKED_UP' || ps == 'IN_TRANSIT' || ps == 'RECEIVED';
        final bool received = ps == 'RECEIVED';
        final DateTime? deliveredAt =
            order.deliveredAt ?? _t(<String>['DELIVERED']);
        return <_Step>[
          _Step('Order placed', fullStamp(placed), _Mark.done),
          if (deliveredAt != null)
            _Step('Delivered', fullStamp(deliveredAt), _Mark.done),
          if (r != null)
            _Step('Return requested', fullStamp(r.createdAt), _Mark.done),
          if (r?.returnApprovedAt != null)
            _Step(
                'Return approved', fullStamp(r!.returnApprovedAt!), _Mark.done),
          _Step(
            'Return picked up',
            r?.pickup?.pickedUpAt != null
                ? fullStamp(r!.pickup!.pickedUpAt!)
                : (r?.pickup?.scheduledAt != null
                    ? 'Scheduled ${shortStamp(r!.pickup!.scheduledAt!)}'
                    : 'Expected soon'),
            pickedUp
                ? _Mark.done
                : r?.pickup != null
                    ? _Mark.current
                    : _Mark.upcoming,
          ),
          _Step(
            'Inspection in progress',
            received ? 'In progress' : 'Expected soon',
            received ? _Mark.current : _Mark.upcoming,
          ),
          const _Step(
              'Refund to be initiated', 'Expected soon', _Mark.upcoming),
        ];
      case OrderPhase.refunded:
        final RefundRequestStatusEntity? r = request;
        final List<_Step> out = <_Step>[
          _Step('Order placed', fullStamp(placed), _Mark.done),
        ];
        final DateTime? cancelled =
            order.cancelledAt ?? _t(<String>['CANCELLED']);
        if (cancelled != null) {
          out.add(_Step('Cancelled', fullStamp(cancelled), _Mark.done));
        }
        if (r != null) {
          final DateTime? deliveredAt =
              order.deliveredAt ?? _t(<String>['DELIVERED']);
          if (deliveredAt != null) {
            out.add(_Step('Delivered', fullStamp(deliveredAt), _Mark.done));
          }
          out.add(
              _Step('Refund initiated', fullStamp(r.createdAt), _Mark.done));
          final DateTime? paid = r.refundedAt ?? r.resolvedAt;
          out.add(
            _Step(
              'Refund credited',
              paid != null ? fullStamp(paid) : null,
              _Mark.done,
            ),
          );
        } else {
          final DateTime? ref = _t(<String>['REFUNDED']);
          out
            ..add(_Step('Refund initiated', ref != null ? fullStamp(ref) : null,
                _Mark.done))
            ..add(_Step('Refund credited', ref != null ? fullStamp(ref) : null,
                _Mark.done));
        }
        return out;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_Step> steps = _steps();
    final OrderShipment? ship = shipments
        .where(
            (s) => (s.awb ?? '').isNotEmpty || (s.trackingUrl ?? '').isNotEmpty)
        .firstOrNull;
    final bool showShipping =
        ship != null && (phase.isActive || phase == OrderPhase.delivered);

    return OrderCardBox(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (phase.isActive)
            Text('Order timeline', style: jakarta(19.sp))
          else
            const SizedBox.shrink(),
          if (phase.isActive) SizedBox(height: 16.h),
          for (int i = 0; i < steps.length; i++)
            _TimelineRow(step: steps[i], last: i == steps.length - 1),
          if (showShipping) ...<Widget>[
            SizedBox(height: 6.h),
            const Divider(height: 1, color: OV.divider),
            SizedBox(height: 14.h),
            Text('Shipping details', style: dm(15.sp, color: AU.ink)),
            SizedBox(height: 12.h),
            Row(
              children: <Widget>[
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF1F7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsRegular.truck,
                    size: 26.sp,
                    color: AU.ink,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ship.courierName ?? ship.provider ?? 'Courier',
                        style: jakarta(17.sp),
                      ),
                      if ((ship.awb ?? '').isNotEmpty) ...<Widget>[
                        SizedBox(height: 2.h),
                        Text('Tracking ID', style: dm(12.5.sp, color: AU.grey)),
                        GestureDetector(
                          onTap: () => onCopyAwb(ship.awb!),
                          child: Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  ship.awb!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: dm(15.sp,
                                      w: FontWeight.w600, color: AU.ink),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Icon(
                                PhosphorIconsRegular.copy,
                                size: 17.sp,
                                color: AU.ink,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if ((ship.trackingUrl ?? '').isNotEmpty)
                  SizedBox(
                    width: 140.w,
                    child: OrderOutlineButton(
                      label: 'Track shipment',
                      icon: PhosphorIconsRegular.arrowSquareOut,
                      height: 44.h,
                      fontSize: 13.sp,
                      radius: 10.r,
                      onTap: () => launchUrl(
                        Uri.parse(ship.trackingUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.last});
  final _Step step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final bool done = step.mark == _Mark.done;
    final bool current = step.mark == _Mark.current;
    final bool failed = step.mark == _Mark.failed;
    final Color lineColor = done ? OV.green : const Color(0xFFD9DDEA);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 34.w,
            child: Column(
              children: <Widget>[
                _dot(done, current, failed),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: lineColor),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18.h, top: 2.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.title,
                    style: jakarta(
                      16.sp,
                      w: step.mark == _Mark.upcoming
                          ? FontWeight.w600
                          : FontWeight.w700,
                      color: failed ? OV.red : AU.ink,
                    ),
                  ),
                  if (step.sub != null) ...<Widget>[
                    SizedBox(height: 3.h),
                    Text(step.sub!, style: dm(14.sp, color: AU.muted)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  CartArt? _art() {
    final String t = step.title.toLowerCase();
    if (t.contains('refund')) return CartArt.refund;
    if (t.contains('cancel')) return CartArt.cancelled;
    if (t.contains('return') || t.contains('pickup')) return CartArt.returned;
    if (t.contains('out for delivery')) return CartArt.scooter;
    if (t.contains('delivered')) return CartArt.delivered;
    if (t.contains('shipped') || t.contains('on the way')) return CartArt.rocket;
    if (t.contains('packed')) return CartArt.packed;
    if (t.contains('confirm')) return CartArt.confirmed;
    if (t.contains('placed')) return CartArt.placed;
    return null;
  }

  Widget _dot(bool done, bool current, bool failed) {
    final double d = 34.w;
    final CartArt? art = _art();
    if (art != null) {
      final Widget img = CartArtImage(art, size: d - 4, float: current);
      return Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: failed
              ? OV.redSoft
              : current
                  ? AU.indigoSoft
                  : done
                      ? OV.greenSoft
                      : const Color(0xFFF1F3F9),
          shape: BoxShape.circle,
          border: current
              ? Border.all(color: AU.indigo.withValues(alpha: .35), width: 1.5)
              : null,
        ),
        child: Center(
          child: Opacity(
            opacity: (!done && !current && !failed) ? .45 : 1,
            child: img,
          ),
        ),
      );
    }
    final double e = 28.w;
    if (done) {
      return Container(
        width: e,
        height: e,
        decoration:
            const BoxDecoration(color: OV.green, shape: BoxShape.circle),
        child: Icon(PhosphorIconsBold.check, size: 16.sp, color: Colors.white),
      );
    }
    if (failed) {
      return Container(
        width: e,
        height: e,
        decoration: const BoxDecoration(color: OV.red, shape: BoxShape.circle),
        child: Icon(PhosphorIconsBold.x, size: 15.sp, color: Colors.white),
      );
    }
    return Container(
      width: e,
      height: e,
      decoration: BoxDecoration(
        color: current ? AU.indigo.withValues(alpha: 0.16) : Colors.white,
        shape: BoxShape.circle,
        border: current
            ? null
            : Border.all(color: const Color(0xFF9AA1B8), width: 1.6),
      ),
    );
  }
}

// ── Return details / Refund summary ──────────────────────────────────────────

class _ReturnDetails extends StatelessWidget {
  const _ReturnDetails({
    required this.order,
    required this.request,
    required this.onCopy,
  });
  final OrderEntity order;
  final RefundRequestStatusEntity request;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final List<OrderItemEntity> returned = request.items.isEmpty
        ? order.items
        : order.items.where((i) => request.items.contains(i.name)).toList();
    final OrderItemEntity? item = returned.isNotEmpty
        ? returned.first
        : (order.items.isNotEmpty ? order.items.first : null);
    final ReturnPickup? p = request.pickup;
    final String awb = p?.awb ?? '';
    return OrderCardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Return details', style: jakarta(19.sp)),
          SizedBox(height: 14.h),
          if (item != null)
            Row(
              children: <Widget>[
                OrderThumb(url: item.thumbnailUrl, size: 74.w),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(16.sp, h: 1.25),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Qty: ${item.quantity}',
                        style: dm(13.sp, color: AU.muted),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        item.total.toInrCurrency,
                        style: jakarta(17.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (p != null) ...<Widget>[
            SizedBox(height: 14.h),
            const Divider(height: 1, color: OV.divider),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _Labeled(
                    label: 'Pickup by',
                    value: p.courierName ?? p.provider ?? 'Courier partner',
                  ),
                ),
                if (awb.isNotEmpty)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onCopy(awb),
                      child: _Labeled(
                        label: 'Return tracking ID',
                        value: awb,
                        trailing: PhosphorIconsRegular.copy,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.value, this.trailing});
  final String label;
  final String value;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: dm(13.sp, color: AU.muted)),
          SizedBox(height: 3.h),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(15.sp, w: FontWeight.w600),
                ),
              ),
              if (trailing != null) ...<Widget>[
                SizedBox(width: 6.w),
                Icon(trailing, size: 17.sp, color: AU.indigo),
              ],
            ],
          ),
        ],
      );
}

class _RefundSummary extends StatelessWidget {
  const _RefundSummary({
    required this.order,
    required this.request,
    required this.onCopy,
    required this.onWallet,
  });
  final OrderEntity order;
  final RefundRequestStatusEntity? request;
  final ValueChanged<String> onCopy;
  final VoidCallback onWallet;

  @override
  Widget build(BuildContext context) {
    final RefundRequestStatusEntity? r = request;
    final double amount = r?.refundAmount ?? order.total;
    final bool toWallet = r == null || r.refundTo != 'original';
    final DateTime? when =
        r?.refundedAt ?? r?.resolvedAt ?? order.statusTimes['REFUNDED'];
    final String? ref = r?.refundReference;
    return OrderCardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Refund summary', style: jakarta(19.sp)),
          SizedBox(height: 14.h),
          _kv('Refund amount', amount.toInrCurrency, bold: true),
          _kv('Refund method',
              toWallet ? 'Dealkr Wallet' : 'Original payment'),
          if (when != null) _kv('Refund date', fullStamp(when)),
          if (ref != null && ref.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child:
                        Text('Reference ID', style: dm(14.sp, color: AU.muted)),
                  ),
                  GestureDetector(
                    onTap: () => onCopy(ref),
                    child: Row(
                      children: <Widget>[
                        Text(ref,
                            style:
                                dm(14.sp, color: AU.ink, w: FontWeight.w600)),
                        SizedBox(width: 6.w),
                        Icon(PhosphorIconsRegular.copy,
                            size: 17.sp, color: AU.indigo),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (toWallet) ...<Widget>[
            SizedBox(height: 4.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: OV.indigoBand,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(PhosphorIconsFill.info, size: 20.sp, color: AU.indigo),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'The amount has been added to your Dealkr Wallet '
                      'and can be used for your next order.',
                      style: dm(12.5.sp, color: AU.muted, h: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            OrderOutlineButton(
              label: 'View wallet balance',
              onTap: onWallet,
              height: 46.h,
              fontSize: 14.sp,
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(k, style: dm(14.sp, color: AU.muted))),
            Text(
              v,
              style: bold
                  ? jakarta(15.sp)
                  : dm(14.sp, color: AU.ink, w: FontWeight.w600),
            ),
          ],
        ),
      );
}

// ── Items ────────────────────────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.order,
    required this.phase,
    required this.shipments,
    required this.returnWindow,
    required this.onReview,
    required this.onBuyAgain,
    required this.buyAgainBusy,
    required this.onOpenProduct,
  });

  final OrderEntity order;
  final OrderPhase phase;
  final List<OrderShipment> shipments;
  final (ReturnPolicy, DateTime)? returnWindow;
  final VoidCallback onReview;
  final VoidCallback onBuyAgain;
  final bool buyAgainBusy;
  final ValueChanged<OrderItemEntity> onOpenProduct;

  String? get _seller {
    final Set<String> names = <String>{
      for (final OrderShipment s in shipments)
        if ((s.sellerName ?? '').isNotEmpty) s.sellerName!,
    };
    return names.length == 1 ? names.first : null;
  }

  @override
  Widget build(BuildContext context) {
    // The return-in-progress / refunded designs show the items card last-ish;
    // the Return details / Refund summary cards above already name the item.
    final bool delivered = phase == OrderPhase.delivered;
    final bool priceBelow = delivered || phase == OrderPhase.paymentFailed;
    final String? seller = _seller;
    return OrderCardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Items (${order.items.length})', style: jakarta(19.sp)),
          SizedBox(height: 12.h),
          for (int i = 0; i < order.items.length; i++) ...<Widget>[
            _ItemRow(
              item: order.items[i],
              seller: seller,
              showOff: priceBelow,
              onTap: () => onOpenProduct(order.items[i]),
            ),
            if (i < order.items.length - 1) SizedBox(height: 10.h),
          ],
          if (delivered) ...<Widget>[
            SizedBox(height: 12.h),
            const Divider(height: 1, color: OV.divider),
            SizedBox(height: 4.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: onReview,
                    icon: Icon(PhosphorIconsRegular.star, size: 20.sp),
                    label: Text('Write a review',
                        style: jakarta(14.sp,
                            w: FontWeight.w600, color: AU.indigo)),
                    style: TextButton.styleFrom(foregroundColor: AU.indigo),
                  ),
                ),
                Container(width: 1, height: 22.h, color: OV.divider),
                Expanded(
                  child: TextButton.icon(
                    onPressed: buyAgainBusy ? null : onBuyAgain,
                    icon: Icon(PhosphorIconsRegular.shoppingBag, size: 20.sp),
                    label: Text('Buy it again',
                        style: jakarta(14.sp,
                            w: FontWeight.w600, color: AU.indigo)),
                    style: TextButton.styleFrom(foregroundColor: AU.indigo),
                  ),
                ),
              ],
            ),
            if (returnWindow != null) ...<Widget>[
              SizedBox(height: 6.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: OV.greenSoft,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(PhosphorIconsFill.checkCircle,
                        size: 26.sp, color: OV.green),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Return available till ${shortDate(returnWindow!.$1.lastDate(returnWindow!.$2))}',
                            style: jakarta(14.sp),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'You can return this item within ${returnWindow!.$1.windowDays} days.',
                            style: dm(12.5.sp, color: AU.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (phase.isActive) ...<Widget>[
            SizedBox(height: 12.h),
            const Divider(height: 1, color: OV.divider),
            InkWell(
              onTap: buyAgainBusy ? null : onBuyAgain,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Row(
                  children: <Widget>[
                    Icon(PhosphorIconsRegular.shoppingBag,
                        size: 22.sp, color: AU.indigo),
                    SizedBox(width: 10.w),
                    Text('Buy it again',
                        style: jakarta(15.sp,
                            w: FontWeight.w600, color: AU.indigo)),
                    const Spacer(),
                    Icon(PhosphorIconsRegular.caretRight,
                        size: 18.sp, color: AU.ink),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.seller,
    required this.showOff,
    required this.onTap,
  });
  final OrderItemEntity item;
  final String? seller;
  final bool showOff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double? mrp = item.originalPrice;
    final bool hasMrp = mrp != null && mrp > item.price;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: OV.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OrderThumb(url: item.thumbnailUrl, size: 76.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: jakarta(16.sp, h: 1.25),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if (!showOff)
                        Text(item.total.toInrCurrency, style: jakarta(16.sp)),
                    ],
                  ),
                  if ((item.brand ?? '').isNotEmpty) ...<Widget>[
                    SizedBox(height: 3.h),
                    Text(item.brand!, style: dm(13.sp, color: AU.muted)),
                  ],
                  SizedBox(height: 3.h),
                  Text('Qty ${item.quantity}',
                      style: dm(13.sp, color: AU.muted)),
                  if (seller != null) ...<Widget>[
                    SizedBox(height: 3.h),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'Sold by $seller',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: dm(13.sp, color: AU.muted),
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Icon(PhosphorIconsFill.sealCheck,
                            size: 16.sp, color: AU.verified),
                      ],
                    ),
                  ],
                  if (showOff) ...<Widget>[
                    SizedBox(height: 6.h),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8.w,
                      children: <Widget>[
                        Text(item.total.toInrCurrency, style: jakarta(17.sp)),
                        if (hasMrp)
                          Text(
                            (mrp * item.quantity).toInrCurrency,
                            style: dm(12.5.sp, color: AU.grey).copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (hasMrp && item.discountPercent > 0)
                          OffChip(percent: item.discountPercent),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payment failed ───────────────────────────────────────────────────────────

class _PaymentFailedNote extends StatelessWidget {
  const _PaymentFailedNote({
    required this.order,
    required this.onRetry,
    required this.busy,
  });
  final OrderEntity order;
  final VoidCallback onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: OV.redSoft,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: OV.redBorder),
          ),
          child: Row(
            children: <Widget>[
              Icon(PhosphorIconsFill.warningCircle, size: 22.sp, color: OV.red),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'This order was cancelled because the payment was not completed.',
                  style: dm(13.sp, color: const Color(0xFF8B1E26), h: 1.35),
                ),
              ),
            ],
          ),
        ),
        OrderPrimaryButton(
          label: 'Try payment again',
          busy: busy,
          onTap: onRetry,
          height: 54.h,
        ),
        SizedBox(height: 12.h),
      ],
    );
  }
}

// ── Delivery, payment, options, help ─────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.order, required this.user});
  final OrderEntity order;
  final UserEntity? user;

  String _s(Map<String, dynamic> m, List<String> keys) {
    for (final String k in keys) {
      final Object? v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> a = order.deliveryAddress;
    final String name = _s(a, <String>['name']).isNotEmpty
        ? _s(a, <String>['name'])
        : (user?.name ?? '');
    final String phone = _s(a, <String>['phone']).isNotEmpty
        ? _s(a, <String>['phone'])
        : (user?.phone ?? '');
    final String label = _s(a, <String>['label']);
    final List<String> lines = <String>[
      _s(a, <String>['addressLine1', 'address_line1']),
      _s(a, <String>['addressLine2', 'address_line2']),
      <String>[
        _s(a, <String>['city']),
        _s(a, <String>['state']),
        _s(a, <String>['pincode']),
      ].where((e) => e.isNotEmpty).join(', '),
    ].where((e) => e.isNotEmpty).toList();

    return OrderCardBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44.w,
            height: 44.w,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F3F9),
              shape: BoxShape.circle,
            ),
            child:
                Icon(PhosphorIconsRegular.mapPin, size: 22.sp, color: AU.ink),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Delivery details', style: jakarta(19.sp)),
                SizedBox(height: 12.h),
                if (name.isNotEmpty || label.isNotEmpty)
                  Text(
                    <String>[
                      if (name.isNotEmpty) name,
                      if (label.isNotEmpty && name.isEmpty) label
                    ].join(' · '),
                    style: jakarta(16.sp),
                  ),
                if (name.isNotEmpty || label.isNotEmpty) SizedBox(height: 4.h),
                Text(
                  lines.join(', '),
                  style: dm(14.5.sp, color: AU.muted, h: 1.4),
                ),
                if (phone.isNotEmpty) ...<Widget>[
                  SizedBox(height: 4.h),
                  Text(phone, style: dm(14.5.sp, color: AU.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});
  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final double? mrp = orderMrp(order);
    final double itemsTotal =
        order.items.fold<double>(0, (s, i) => s + i.total);
    final double itemTotal = mrp ?? itemsTotal;
    final double productDiscount = mrp != null ? mrp - itemsTotal : 0;
    final bool paid = order.paymentStatus.toUpperCase() == 'PAID';
    final bool cod = order.paymentMethod.toUpperCase() == 'COD';
    final String method = cod ? 'Cash on delivery' : 'Online payment';
    final String state = switch (order.paymentStatus.toUpperCase()) {
      'PAID' => 'Paid',
      'REFUNDED' => 'Refunded',
      'FAILED' => 'Failed',
      'EXPIRED' => 'Expired',
      _ => 'Pending',
    };
    final Color stateColor = switch (state) {
      'Paid' || 'Refunded' => AU.greenText,
      'Failed' || 'Expired' => OV.red,
      _ => OV.amber,
    };

    Widget row(String k, Widget v) => Container(
          padding: EdgeInsets.symmetric(vertical: 11.h),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: OV.divider)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(k, style: dm(15.sp, color: AU.ink))),
              v,
            ],
          ),
        );

    return OrderCardBox(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Payment summary', style: jakarta(19.sp)),
          SizedBox(height: 6.h),
          row(
              'Item total',
              Text(itemTotal.toInrCurrency,
                  style: dm(15.sp, color: AU.ink, w: FontWeight.w500))),
          if (productDiscount > 0.5)
            row(
              'Product discount',
              Text(
                '-${productDiscount.toInrCurrency}',
                style: dm(15.sp, color: AU.greenText, w: FontWeight.w600),
              ),
            ),
          if (order.discount > 0.5)
            row(
              order.couponCode != null
                  ? 'Coupon (${order.couponCode})'
                  : 'Discount',
              Text(
                '-${order.discount.toInrCurrency}',
                style: dm(15.sp, color: AU.greenText, w: FontWeight.w600),
              ),
            ),
          row(
            'Delivery fee',
            order.deliveryFee > 0
                ? Text(order.deliveryFee.toInrCurrency,
                    style: dm(15.sp, color: AU.ink))
                : Text('FREE',
                    style: dm(15.sp, color: AU.greenText, w: FontWeight.w700)),
          ),
          if (order.platformFee > 0)
            row(
                'Platform fee',
                Text(order.platformFee.toInrCurrency,
                    style: dm(15.sp, color: AU.ink))),
          if (order.walletAmountUsed > 0)
            row(
              'Paid from wallet',
              Text(
                '-${order.walletAmountUsed.toInrCurrency}',
                style: dm(15.sp, color: AU.greenText, w: FontWeight.w600),
              ),
            ),
          row(
            paid ? 'Total paid' : 'Total payable',
            Text(order.total.toInrCurrency, style: jakarta(22.sp)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 13.h),
            child: Row(
              children: <Widget>[
                Expanded(
                  child:
                      Text('Payment method', style: dm(15.sp, color: AU.muted)),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                              text: '$method  •  ',
                              style:
                                  dm(15.sp, color: AU.ink, w: FontWeight.w600)),
                          TextSpan(
                              text: state,
                              style: dm(15.sp,
                                  color: stateColor, w: FontWeight.w700)),
                        ],
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
                if (paid) ...<Widget>[
                  SizedBox(width: 8.w),
                  Icon(PhosphorIconsFill.checkCircle,
                      size: 24.sp, color: OV.green),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreOptions extends StatelessWidget {
  const _MoreOptions({
    required this.phase,
    required this.cancelling,
    required this.downloading,
    required this.onInvoice,
    required this.onBuyAgain,
    required this.onPolicy,
    required this.onCancel,
  });
  final OrderPhase phase;
  final bool cancelling;
  final bool downloading;
  final VoidCallback onInvoice;
  final VoidCallback onBuyAgain;
  final VoidCallback onPolicy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bool cancellable = phase == OrderPhase.placed ||
        phase == OrderPhase.confirmed ||
        phase == OrderPhase.packed;
    final List<Widget> rows = <Widget>[
      _OptionRow(
        icon: PhosphorIconsRegular.fileText,
        title: 'Download invoice',
        sub: 'Get a copy of your invoice',
        busy: downloading,
        onTap: onInvoice,
      ),
      _OptionRow(
        icon: PhosphorIconsRegular.arrowCounterClockwise,
        title: 'Buy it again',
        sub: 'Order this item again',
        onTap: onBuyAgain,
      ),
      _OptionRow(
        icon: PhosphorIconsRegular.shieldCheck,
        title: 'Return policy',
        sub: 'View return and refund policy',
        onTap: onPolicy,
      ),
      if (cancellable)
        _OptionRow(
          icon: PhosphorIconsRegular.xCircle,
          title: 'Cancel order',
          sub: 'You can cancel until the order is shipped',
          busy: cancelling,
          danger: true,
          onTap: onCancel,
        ),
    ];
    return OrderCardBox(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('More options', style: jakarta(19.sp)),
          SizedBox(height: 4.h),
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 1, color: OV.divider),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.busy = false,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 28.sp, color: danger ? OV.red : AU.ink),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        style: jakarta(16.sp, color: danger ? OV.red : AU.ink)),
                    SizedBox(height: 2.h),
                    Text(sub, style: dm(13.5.sp, color: AU.muted)),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AU.indigo),
                )
              else
                Icon(PhosphorIconsRegular.caretRight,
                    size: 20.sp, color: AU.ink),
            ],
          ),
        ),
      );
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.onChat,
    required this.onTopic,
    required this.orderNumber,
  });
  final VoidCallback onChat;
  final ValueChanged<String> onTopic;
  final String orderNumber;

  @override
  Widget build(BuildContext context) {
    Widget chip(String t) => GestureDetector(
          onTap: () => onTopic(t),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F9),
              borderRadius: BorderRadius.circular(100.r),
              border: Border.all(color: OV.border),
            ),
            child: Text(t, style: dm(13.5.sp, color: AU.ink)),
          ),
        );
    return OrderCardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58.w,
                height: 58.w,
                decoration: const BoxDecoration(
                  color: AU.indigoSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(PhosphorIconsFill.headset,
                    size: 30.sp, color: AU.indigo),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Need help with this order?', style: jakarta(17.sp)),
                    SizedBox(height: 3.h),
                    Text(
                      "We'll include order #$orderNumber in your conversation.",
                      style: dm(13.5.sp, color: AU.muted, h: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          OrderOutlineButton(
            label: 'Chat with Support',
            icon: PhosphorIconsRegular.chatCircle,
            onTap: onChat,
            height: 50.h,
            fontSize: 16.sp,
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: <Widget>[
              chip('Where is my order?'),
              chip('Payment issue'),
              chip('Item missing or damaged'),
            ],
          ),
          SizedBox(height: 12.h),
          const Divider(height: 1, color: OV.divider),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('tel:${AppConstants.supportPhoneDialable}'),
                  ),
                  icon: Icon(PhosphorIconsRegular.phone, size: 22.sp),
                  label: Text('Call us',
                      style:
                          jakarta(15.sp, w: FontWeight.w600, color: AU.indigo)),
                  style: TextButton.styleFrom(
                    foregroundColor: AU.indigo,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
              Container(width: 1, height: 26.h, color: OV.divider),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                        'mailto:${AppConstants.supportEmail}?subject=Order%20$orderNumber'),
                  ),
                  icon: Icon(PhosphorIconsRegular.envelopeSimple, size: 22.sp),
                  label: Text('Email us',
                      style:
                          jakarta(15.sp, w: FontWeight.w600, color: AU.indigo)),
                  style: TextButton.styleFrom(
                    foregroundColor: AU.indigo,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Payment failed · Confirming · Packing · Shipping · Delivery (design 07, last phone).
class _FailedStepper extends StatelessWidget {
  const _FailedStepper({required this.at});
  final DateTime at;

  static const List<String> _labels = <String>[
    'Payment\nfailed',
    'Confirming',
    'Packing',
    'Shipping',
    'Delivery',
  ];

  @override
  Widget build(BuildContext context) {
    final double d = 22.w;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < 5; i++) ...<Widget>[
              Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  color: i == 0 ? Colors.white : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == 0 ? OV.red : const Color(0xFF9AA1B8),
                    width: i == 0 ? 2.4 : 1.6,
                  ),
                ),
                child: i == 0
                    ? Center(
                        child: Container(
                          width: d * 0.38,
                          height: d * 0.38,
                          decoration: const BoxDecoration(
                            color: OV.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              if (i < 4)
                Expanded(
                  child: Container(height: 2, color: const Color(0xFFD9DDEA)),
                ),
            ],
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < 5; i++)
              Expanded(
                child: Text(
                  _labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == 4
                          ? TextAlign.right
                          : TextAlign.center,
                  style: i == 0
                      ? jakarta(11.sp, color: AU.ink, h: 1.25)
                      : dm(11.sp, color: AU.muted, h: 1.25),
                ),
              ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(shortStamp(at), style: dm(12.sp, color: AU.muted)),
      ],
    );
  }
}

class _NeedHelpRow extends StatelessWidget {
  const _NeedHelpRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OrderCardBox(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: <Widget>[
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: const BoxDecoration(
                    color: AU.indigoSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(PhosphorIconsFill.headset,
                      size: 26.sp, color: AU.indigo),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Need help?', style: jakarta(16.sp)),
                      SizedBox(height: 2.h),
                      Text(
                        'Chat with our support team',
                        style: dm(13.5.sp, color: AU.muted),
                      ),
                    ],
                  ),
                ),
                Icon(PhosphorIconsRegular.caretRight,
                    size: 20.sp, color: AU.ink),
              ],
            ),
          ),
        ),
      );
}
