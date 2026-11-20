import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/utils/extensions/double_extensions.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_theme.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/orders/presentation/providers/my_orders_provider.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_mini_tracker.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_ui.dart';
import 'package:dealker_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';

/// One order on My Orders (design `09-my-orders-list.webp`).
class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.row,
    required this.isReordering,
    required this.onOpen,
    required this.onTrack,
    required this.onReorder,
    required this.onReturn,
    super.key,
  });

  final OrderRow row;
  final bool isReordering;
  final VoidCallback onOpen;
  final VoidCallback onTrack;
  final VoidCallback onReorder;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final OrderEntity order = row.order;
    final RefundRequestStatusEntity? request = row.request;
    final OrderPhase phase = row.phase;
    final double? mrp = orderMrp(order);
    final int? off = orderOffPercent(order);
    final int count = order.itemCount;
    final String? brand =
        order.items.length == 1 ? order.items.first.brand : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onOpen,
        child: Container(
          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: OV.border),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x100A1B4D),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: OrderPill(phase: phase),
                      ),
                    ),
                  ),
                  Text(
                    shortDate(order.createdAt),
                    style: dm(13.sp, color: AU.muted),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 16.sp,
                    color: AU.ink,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OrderThumb(url: firstImage(order), size: 88.w),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          itemsTitle(order),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: jakarta(15.sp, h: 1.25),
                        ),
                        SizedBox(height: 5.h),
                        if (brand != null) ...<Widget>[
                          Text(
                            brand,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: dm(13.sp, color: AU.grey),
                          ),
                          SizedBox(height: 2.h),
                        ],
                        Text(
                          '$count item${count == 1 ? '' : 's'}',
                          style: dm(13.sp, color: AU.grey),
                        ),
                        SizedBox(height: 7.h),
                        _StatusLine(
                            order: order, phase: phase, request: request),
                      ],
                    ),
                  ),
                ],
              ),
              if (phase.isActive) ...<Widget>[
                SizedBox(height: 12.h),
                OrderMiniTracker(stage: phase.stageIndex),
              ],
              SizedBox(height: 12.h),
              const Divider(height: 1, color: OV.divider),
              SizedBox(height: 12.h),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7.w,
                      runSpacing: 4.h,
                      children: <Widget>[
                        Text(
                          order.total.toInrCurrency,
                          style: jakarta(20.sp),
                        ),
                        if (mrp != null)
                          Text(
                            mrp.toInrCurrency,
                            style: dm(13.sp, color: AU.grey).copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (off != null) OffChip(percent: off),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  SizedBox(
                    width: 108.w,
                    child: _action(phase),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(OrderPhase phase) {
    switch (phase) {
      case OrderPhase.placed:
      case OrderPhase.confirmed:
      case OrderPhase.packed:
      case OrderPhase.shipped:
      case OrderPhase.outForDelivery:
        return OrderPrimaryButton(
          label: 'Track Order',
          onTap: onTrack,
          height: 34.h,
          fontSize: 13.sp,
          radius: 9.r,
        );
      case OrderPhase.returnInProgress:
        return OrderPrimaryButton(
          label: 'Track Return',
          onTap: onReturn,
          height: 34.h,
          fontSize: 13.sp,
          radius: 9.r,
        );
      case OrderPhase.refunded:
        return OrderPrimaryButton(
          label: 'Refund Summary',
          onTap: onReturn,
          height: 34.h,
          fontSize: 12.sp,
          radius: 9.r,
        );
      case OrderPhase.delivered:
      case OrderPhase.cancelled:
      case OrderPhase.paymentFailed:
        return OrderOutlineButton(
          label: 'Reorder',
          onTap: onReorder,
          busy: isReordering,
          height: 34.h,
          fontSize: 13.sp,
          radius: 9.r,
        );
    }
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.order,
    required this.phase,
    required this.request,
  });
  final OrderEntity order;
  final OrderPhase phase;
  final RefundRequestStatusEntity? request;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = _content();
    return Row(
      children: <Widget>[
        CartArtImage(phase.art, size: 26.sp),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: jakarta(13.sp, w: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }

  (IconData, Color, String) _content() {
    switch (phase) {
      case OrderPhase.placed:
        return (
          PhosphorIconsRegular.package,
          AU.indigo,
          'Waiting for the seller',
        );
      case OrderPhase.confirmed:
        return (
          PhosphorIconsRegular.package,
          AU.indigo,
          'Seller confirmed your order',
        );
      case OrderPhase.packed:
        return (
          PhosphorIconsRegular.package,
          AU.indigo,
          'Packed, ready to ship',
        );
      case OrderPhase.shipped:
      case OrderPhase.outForDelivery:
        final DateTime? eta = order.estimatedDelivery;
        final String text = phase == OrderPhase.outForDelivery
            ? 'Out for delivery'
            : eta != null
                ? 'Arriving by ${dayDate(eta)}'
                : 'Shipped, on its way';
        return (truckIcon, AU.indigo, text);
      case OrderPhase.delivered:
        final DateTime? at =
            order.deliveredAt ?? order.statusTimes['DELIVERED'];
        return (
          PhosphorIconsFill.checkCircle,
          AU.greenText,
          at != null ? 'Delivered on ${dayMonth(at)}' : 'Delivered',
        );
      case OrderPhase.returnInProgress:
        final String s = request?.pickup?.status ?? '';
        final String text = switch (s) {
          'PICKUP_SCHEDULED' => 'Pickup scheduled',
          'PICKED_UP' => 'Pickup completed',
          'IN_TRANSIT' => 'Return in transit',
          'RECEIVED' => 'Return received',
          _ => 'Return request under review',
        };
        return (truckIcon, OV.amber, text);
      case OrderPhase.refunded:
        return (
          PhosphorIconsFill.checkCircle,
          AU.greenText,
          'Refund completed',
        );
      case OrderPhase.cancelled:
        final DateTime? at =
            order.cancelledAt ?? order.statusTimes['CANCELLED'];
        return (
          PhosphorIconsRegular.xCircle,
          OV.red,
          at != null ? 'Cancelled on ${dayMonth(at)}' : 'Cancelled',
        );
      case OrderPhase.paymentFailed:
        return (
          PhosphorIconsRegular.warningCircle,
          OV.red,
          'Payment was not completed',
        );
    }
  }
}
