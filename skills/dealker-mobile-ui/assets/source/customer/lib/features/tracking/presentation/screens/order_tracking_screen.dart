import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/features/cart/presentation/widgets/cart_art.dart';
import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:dealker_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:dealker_app/features/refund_requests/presentation/widgets/return_ui.dart';
import 'package:dealker_app/features/tracking/data/shipment_repository.dart';

final Provider<ShipmentRepository> _shipmentRepositoryProvider =
    Provider<ShipmentRepository>(
  (Ref ref) => ShipmentRepository(ref.watch(dioClientProvider)),
);

final orderShipmentsProvider =
    FutureProvider.autoDispose.family<List<OrderShipment>, String>(
  (Ref ref, String orderId) =>
      ref.watch(_shipmentRepositoryProvider).forOrder(orderId),
);

const List<String> _steps = <String>[
  'Order\nPlaced',
  'Confirmed',
  'Packed',
  'Shipped',
  'Delivered',
];

/// "Track order": order steps plus the courier status of each parcel (Shiprocket / Porter / …).
/// Status and tracking link only — there is no rider and no live map.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(orderShipmentsProvider(widget.id));
      ref.invalidate(orderDetailProvider(widget.id));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Index of the last finished step, or -1 when the order was cancelled / refunded.
  static int _doneUpTo(OrderStatus s) => switch (s) {
        OrderStatus.PENDING => 0,
        OrderStatus.CONFIRMED => 1,
        OrderStatus.PREPARING || OrderStatus.PACKED => 2,
        OrderStatus.OUT_FOR_DELIVERY => 3,
        OrderStatus.DELIVERED => 4,
        _ => -1,
      };

  @override
  Widget build(BuildContext context) {
    final AsyncValue<OrderEntity> order =
        ref.watch(orderDetailProvider(widget.id));
    final AsyncValue<List<OrderShipment>> shipments =
        ref.watch(orderShipmentsProvider(widget.id));
    return ReturnScaffold(
      title: 'Track Order',
      child: RefreshIndicator(
        color: ReturnColors.indigo,
        onRefresh: () async {
          ref.invalidate(orderShipmentsProvider(widget.id));
          ref.invalidate(orderDetailProvider(widget.id));
          await ref.read(orderShipmentsProvider(widget.id).future);
        },
        child: order.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const DealkerPageLoader(),
          error: (Object e, StackTrace _) => ListView(
            children: <Widget>[
              SizedBox(height: 120.h),
              Center(
                child: Column(
                  children: <Widget>[
                    const Text('Could not load this order.'),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(orderDetailProvider(widget.id)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (OrderEntity o) => _body(o, shipments),
        ),
      ),
    );
  }

  Widget _body(OrderEntity o, AsyncValue<List<OrderShipment>> shipments) {
    final int done = _doneUpTo(o.status);
    final bool closed = done < 0;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: <Widget>[
        if (!closed) ...<Widget>[
          _TrackStepper(done: done),
          SizedBox(height: 16.h),
        ],
        ReturnCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: _orderInfo(o, closed, done)),
              SizedBox(width: 8.w),
              CartArtImage(_heroArt(o.status), size: 86.w, float: true),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        shipments.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: const DealkerPageLoader(),
          ),
          error: (Object e, StackTrace _) => const ReturnNote(
            icon: Icons.cloud_off_rounded,
            text: 'Could not load courier details. Pull down to retry.',
          ),
          data: (List<OrderShipment> list) => list.isEmpty
              ? ReturnNote(
                  icon: Icons.inventory_2_outlined,
                  text: closed
                      ? 'No courier details for this order.'
                      : 'Courier details will appear here once your order ships.',
                )
              : Column(
                  children: <Widget>[
                    for (final OrderShipment s in list) ...<Widget>[
                      _ShipmentCard(shipment: s, multi: list.length > 1),
                      SizedBox(height: 12.h),
                    ],
                  ],
                ),
        ),
      ],
    );
  }


  Widget _orderInfo(OrderEntity o, bool closed, int done) {
    return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Order ${o.orderNumber}',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                _headline(o),
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.4,
                  color: ReturnColors.muted,
                ),
              ),
              if (o.estimatedDelivery != null &&
                  !closed &&
                  done < 4) ...<Widget>[
                SizedBox(height: 10.h),
                Text(
                  'Expected by ${DateFormat('EEE, dd MMM').format(o.estimatedDelivery!.toLocal())}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: ReturnColors.indigo,
                  ),
                ),
              ],
            ],
          );
  }

  static CartArt _heroArt(OrderStatus s) => switch (s) {
        OrderStatus.PENDING => CartArt.placed,
        OrderStatus.CONFIRMED => CartArt.confirmed,
        OrderStatus.PREPARING || OrderStatus.PACKED => CartArt.packed,
        OrderStatus.OUT_FOR_DELIVERY => CartArt.rocket,
        OrderStatus.DELIVERED => CartArt.delivered,
        OrderStatus.CANCELLED => CartArt.cancelled,
        OrderStatus.REFUNDED => CartArt.refund,
      };

  String _headline(OrderEntity o) => switch (o.status) {
        OrderStatus.PENDING =>
          'We have received your order and are confirming it with the seller.',
        OrderStatus.CONFIRMED =>
          'Your order is confirmed. The seller is getting it ready.',
        OrderStatus.PREPARING => 'The seller is packing your order.',
        OrderStatus.PACKED =>
          'Your order is packed and waiting for the courier.',
        OrderStatus.OUT_FOR_DELIVERY => 'Your order is on its way to you.',
        OrderStatus.DELIVERED => 'Your order has been delivered.',
        OrderStatus.CANCELLED => 'This order was cancelled.',
        OrderStatus.REFUNDED => 'This order was returned and refunded.',
      };
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.shipment, required this.multi});

  final OrderShipment shipment;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final OrderShipment s = shipment;
    final bool bad =
        s.status == 'FAILED' || s.status == 'RTO' || s.status == 'CANCELLED';
    final bool delivered = s.status == 'DELIVERED';
    final Color tone = bad
        ? ReturnColors.red
        : delivered
            ? ReturnColors.green
            : ReturnColors.indigo;
    final String courier = (s.courierName ?? '').isNotEmpty
        ? s.courierName!
        : switch (s.provider) {
            'SHIPROCKET' => 'Shiprocket',
            'PORTER' => 'Porter',
            'BLUEDART' => 'Blue Dart',
            _ => 'Seller delivery',
          };
    return ReturnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CartArtImage(CartArt.truck, size: 30.sp, float: true),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  multi && s.sellerName != null
                      ? 'Parcel from ${s.sellerName}'
                      : 'Shipment',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: ReturnColors.ink,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  s.statusLabel,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _kv('Courier', courier),
          if (s.awb != null) _kv('Tracking ID', s.awb!),
          if (s.estimatedDelivery != null && !delivered)
            _kv(
              'Expected by',
              DateFormat('EEE, dd MMM').format(s.estimatedDelivery!),
            ),
          if (s.events.isNotEmpty) ...<Widget>[
            SizedBox(height: 8.h),
            const Divider(height: 1, color: ReturnColors.line),
            SizedBox(height: 10.h),
            for (final ShipmentEvent e in s.events.take(6))
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Icon(Icons.circle, size: 8.sp, color: tone),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (e.note ?? '').isNotEmpty
                                ? e.note!
                                : e.status.replaceAll('_', ' ').toLowerCase(),
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                              color: ReturnColors.ink,
                            ),
                          ),
                          Text(
                            <String>[
                              if (e.at != null) returnDate(e.at),
                              if ((e.location ?? '').isNotEmpty) e.location!,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: ReturnColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (s.trackingUrl != null) ...<Widget>[
            SizedBox(height: 6.h),
            ReturnPrimaryButton(
              label: 'Track on courier site',
              icon: Icons.open_in_new_rounded,
              outlined: true,
              onPressed: () => launchUrl(
                Uri.parse(s.trackingUrl!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: EdgeInsets.only(bottom: 4.h),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 92.w,
              child: Text(
                k,
                style: TextStyle(fontSize: 11.sp, color: ReturnColors.muted),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: ReturnColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
}

const List<CartArt> _stepArt = <CartArt>[
  CartArt.placed,
  CartArt.confirmed,
  CartArt.packed,
  CartArt.rocket,
  CartArt.delivered,
];

/// Five-step tracker where every step is a 3D icon: finished steps are full
/// colour with a green tick, the current step floats, upcoming ones are faded.
class _TrackStepper extends StatelessWidget {
  const _TrackStepper({required this.done});

  /// Index of the last finished step (-1 = none).
  final int done;

  @override
  Widget build(BuildContext context) {
    final int current = (done + 1).clamp(0, 4);
    return ReturnCard(
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(9, (int i) {
              if (i.isOdd) {
                final int left = i ~/ 2;
                return Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: left <= done
                          ? ReturnColors.green
                          : ReturnColors.line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }
              final int idx = i ~/ 2;
              final bool isDone = idx <= done;
              final bool isCurrent = idx == current && done < 4;
              return SizedBox(
                width: 46.w,
                height: 46.w,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? ReturnColors.greenSoft
                            : isCurrent
                                ? ReturnColors.indigoSoft
                                : const Color(0xFFF1F3F9),
                        border: isCurrent
                            ? Border.all(
                                color: ReturnColors.indigo.withValues(alpha: .3),
                                width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: (isDone || isCurrent) ? 1 : .4,
                          child: CartArtImage(_stepArt[idx],
                              size: 30.w, float: isCurrent),
                        ),
                      ),
                    ),
                    if (isDone)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 17.w,
                          height: 17.w,
                          decoration: BoxDecoration(
                            color: ReturnColors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Icon(Icons.check_rounded,
                              size: 11.sp, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          SizedBox(height: 8.h),
          Row(
            children: List<Widget>.generate(5, (int i) {
              final bool on = i == current && done < 4;
              return Expanded(
                child: Text(
                  _steps[i].replaceAll('\n', ' '),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10.5.sp,
                    height: 1.2,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    color: on ? ReturnColors.indigo : ReturnColors.muted,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
