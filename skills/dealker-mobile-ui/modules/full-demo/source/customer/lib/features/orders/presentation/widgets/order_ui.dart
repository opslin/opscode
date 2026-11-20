import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/features/orders/presentation/widgets/order_theme.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:dealker_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:dealker_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:dealker_app/shared/widgets/safe_product_image.dart';

/// Colours of My Orders / Order Details, measured from the approved design.
/// Shared base (ink, indigo, greens, ambers) comes from the auctions page [AU].
class OV {
  OV._();
  static const Color canvas = Color(0xFFF7F8FC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE9ECF4);
  static const Color divider = Color(0xFFEDEFF6);
  static const Color thumbBg = Color(0xFFF4F5FA);
  static const Color red = Color(0xFFE5232E);
  static const Color redSoft = Color(0xFFFDECEE);
  static const Color redBorder = Color(0xFFF9C9CD);
  static const Color green = Color(0xFF16A34A);
  static const Color greenSoft = Color(0xFFE6F6EC);
  static const Color amber = Color(0xFFB45F06);
  static const Color amberSoft = Color(0xFFFFF1D6);
  static const Color amberDot = Color(0xFFF59E0B);
  static const Color indigoBand = Color(0xFFF0EFFF);
}

/// Where an order is in its life, as the customer sees it.
enum OrderPhase {
  placed,
  confirmed,
  packed,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
  paymentFailed,
  returnInProgress,
  refunded,
}

OrderPhase orderPhase(OrderEntity o, {RefundRequestStatusEntity? request}) {
  final bool delivered = o.status == OrderStatus.DELIVERED ||
      const <String>['DELIVERED', 'COMPLETED', 'CLOSED'].contains(o.rawStatus);
  if (request != null && request.blocksNewRequest && !request.isRejected) {
    if (request.isApproved) return OrderPhase.refunded;
    if (request.isPending) return OrderPhase.returnInProgress;
  }
  switch (o.rawStatus) {
    case 'ORDER_PLACED':
    case 'PENDING':
      return OrderPhase.placed;
    case 'CONFIRMED':
    case 'PREPARING':
    case 'ACCEPTED':
      return OrderPhase.confirmed;
    case 'PACKED':
    case 'READY_TO_SHIP':
      return OrderPhase.packed;
    case 'SHIPPED':
    case 'PICKED_UP':
    case 'IN_TRANSIT':
      return OrderPhase.shipped;
    case 'OUT_FOR_DELIVERY':
      return OrderPhase.outForDelivery;
    case 'REFUNDED':
    case 'RETURNED':
      return OrderPhase.refunded;
    case 'RETURN_REQUESTED':
      return OrderPhase.returnInProgress;
    case 'CANCELLED':
      return o.isPaymentFailed
          ? OrderPhase.paymentFailed
          : OrderPhase.cancelled;
  }
  if (delivered) return OrderPhase.delivered;
  switch (o.status) {
    case OrderStatus.PENDING:
      return OrderPhase.placed;
    case OrderStatus.CONFIRMED:
    case OrderStatus.PREPARING:
      return OrderPhase.confirmed;
    case OrderStatus.PACKED:
      return OrderPhase.packed;
    case OrderStatus.OUT_FOR_DELIVERY:
      return OrderPhase.outForDelivery;
    case OrderStatus.DELIVERED:
      return OrderPhase.delivered;
    case OrderStatus.CANCELLED:
      return o.isPaymentFailed
          ? OrderPhase.paymentFailed
          : OrderPhase.cancelled;
    case OrderStatus.REFUNDED:
      return OrderPhase.refunded;
  }
}

/// Artwork for each of the six delivery stages (Placed → Delivered).
const List<CartArt> kStageArt = <CartArt>[
  CartArt.placed,
  CartArt.confirmed,
  CartArt.packed,
  CartArt.rocket,
  CartArt.scooter,
  CartArt.delivered,
];

extension OrderPhaseX on OrderPhase {
  CartArt get art => switch (this) {
        OrderPhase.placed => CartArt.placed,
        OrderPhase.confirmed => CartArt.confirmed,
        OrderPhase.packed => CartArt.packed,
        OrderPhase.shipped => CartArt.rocket,
        OrderPhase.outForDelivery => CartArt.scooter,
        OrderPhase.delivered => CartArt.delivered,
        OrderPhase.cancelled || OrderPhase.paymentFailed => CartArt.cancelled,
        OrderPhase.returnInProgress => CartArt.returned,
        OrderPhase.refunded => CartArt.refund,
      };

  String get pillLabel => switch (this) {
        OrderPhase.placed => 'Order placed',
        OrderPhase.confirmed => 'Confirmed',
        OrderPhase.packed => 'Packed',
        OrderPhase.shipped || OrderPhase.outForDelivery => 'On the way',
        OrderPhase.delivered => 'Delivered',
        OrderPhase.cancelled => 'Cancelled',
        OrderPhase.paymentFailed => 'Payment failed',
        OrderPhase.returnInProgress => 'Return in progress',
        OrderPhase.refunded => 'Refunded',
      };

  (Color fg, Color bg) get pillColors => switch (this) {
        OrderPhase.placed ||
        OrderPhase.confirmed ||
        OrderPhase.packed ||
        OrderPhase.shipped ||
        OrderPhase.outForDelivery =>
          (AU.indigo, AU.indigoSoft),
        OrderPhase.delivered || OrderPhase.refunded => (
            AU.greenText,
            AU.greenSoft
          ),
        OrderPhase.cancelled || OrderPhase.paymentFailed => (
            OV.red,
            OV.redSoft
          ),
        OrderPhase.returnInProgress => (OV.amber, OV.amberSoft),
      };

  Color get dot => switch (this) {
        OrderPhase.delivered || OrderPhase.refunded => OV.green,
        OrderPhase.cancelled || OrderPhase.paymentFailed => OV.red,
        OrderPhase.returnInProgress => OV.amberDot,
        _ => AU.indigo,
      };

  bool get isActive => switch (this) {
        OrderPhase.placed ||
        OrderPhase.confirmed ||
        OrderPhase.packed ||
        OrderPhase.shipped ||
        OrderPhase.outForDelivery =>
          true,
        _ => false,
      };

  bool get isReturnOrRefund =>
      this == OrderPhase.returnInProgress || this == OrderPhase.refunded;

  /// 0..5 across Placed · Confirmed · Packed · Shipped · Out for delivery · Delivered.
  int get stageIndex => switch (this) {
        OrderPhase.placed => 0,
        OrderPhase.confirmed => 1,
        OrderPhase.packed => 2,
        OrderPhase.shipped => 3,
        OrderPhase.outForDelivery => 4,
        _ => 5,
      };
}

/// Smallest filter that fits an order on the My Orders tabs.
enum OrdersTab { all, active, delivered, cancelled, returns }

extension OrdersTabX on OrdersTab {
  String get label => switch (this) {
        OrdersTab.all => 'All',
        OrdersTab.active => 'Active',
        OrdersTab.delivered => 'Delivered',
        OrdersTab.cancelled => 'Cancelled',
        OrdersTab.returns => 'Returns & Refunds',
      };

  bool matches(OrderPhase p) => switch (this) {
        OrdersTab.all => true,
        OrdersTab.active => p.isActive,
        OrdersTab.delivered => p == OrderPhase.delivered,
        OrdersTab.cancelled =>
          p == OrderPhase.cancelled || p == OrderPhase.paymentFailed,
        OrdersTab.returns => p.isReturnOrRefund,
      };
}

String shortDate(DateTime d) => DateFormat('dd MMM yyyy').format(d.toLocal());
String dayMonth(DateTime d) => DateFormat('d MMM').format(d.toLocal());
String dayDate(DateTime d) => DateFormat('EEE, d MMM').format(d.toLocal());
String fullStamp(DateTime d) =>
    DateFormat('dd MMM yyyy, h:mm a').format(d.toLocal());
String shortStamp(DateTime d) =>
    DateFormat('dd MMM, h:mm a').format(d.toLocal());

/// Σ list price × qty when every line has a real list price above its sale price.
double? orderMrp(OrderEntity o) {
  if (o.items.isEmpty) return null;
  double mrp = 0;
  for (final OrderItemEntity i in o.items) {
    final double? m = i.originalPrice;
    if (m == null || m <= i.price) return null;
    mrp += m * i.quantity;
  }
  return mrp;
}

int? orderOffPercent(OrderEntity o) {
  final double? mrp = orderMrp(o);
  if (mrp == null || mrp <= 0) return null;
  final double items = o.items.fold<double>(0, (s, i) => s + i.total);
  final int pct = ((1 - items / mrp) * 100).round();
  return pct > 0 ? pct : null;
}

String itemsTitle(OrderEntity o) {
  if (o.items.isEmpty) return 'Order items';
  if (o.items.length == 1) return o.items.first.name;
  return '${o.items.first.name} +${o.items.length - 1} more';
}

String? firstImage(OrderEntity o) {
  for (final OrderItemEntity i in o.items) {
    final String? u = i.thumbnailUrl;
    if (u != null && u.trim().isNotEmpty) return u;
  }
  return null;
}

// ── Small building blocks ────────────────────────────────────────────────────

/// Rounded status pill: a dot and the label ("On the way", "Delivered" …).
class OrderPill extends StatelessWidget {
  const OrderPill({required this.phase, this.large = false, super.key});
  final OrderPhase phase;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = phase.pillColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14.w : 12.w,
        vertical: large ? 9.h : 6.h,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(color: phase.dot, shape: BoxShape.circle),
          ),
          SizedBox(width: 7.w),
          Text(
            phase.pillLabel,
            style:
                jakarta(large ? 14.sp : 13.sp, w: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

class OrderThumb extends StatelessWidget {
  const OrderThumb({required this.url, required this.size, super.key});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          color: OV.thumbBg,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: SafeProductImage(
          url: url,
          size: size * 0.84,
          fit: BoxFit.contain,
          backgroundColor: Colors.transparent,
          iconSize: size * 0.3,
        ),
      );
}

/// Filled indigo button.
class OrderPrimaryButton extends StatelessWidget {
  const OrderPrimaryButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.height,
    this.fontSize,
    this.radius,
    super.key,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final double? height;
  final double? fontSize;
  final double? radius;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height ?? 52.h,
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AU.indigo,
            disabledBackgroundColor: AU.indigo.withValues(alpha: 0.6),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius ?? 12.r),
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: 22.sp, color: Colors.white),
                      SizedBox(width: 9.w),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: jakarta(
                            fontSize ?? 16.sp,
                            w: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
}

/// White button with an indigo outline and indigo label.
class OrderOutlineButton extends StatelessWidget {
  const OrderOutlineButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.height,
    this.fontSize,
    this.radius,
    super.key,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final double? height;
  final double? fontSize;
  final double? radius;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height ?? 50.h,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy ? null : onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: AU.indigo, width: 1.3),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius ?? 12.r),
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AU.indigo,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: 20.sp, color: AU.indigo),
                      SizedBox(width: 8.w),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: jakarta(
                            fontSize ?? 15.sp,
                            w: FontWeight.w700,
                            color: AU.indigo,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
}

/// Green "12% OFF" chip.
class OffChip extends StatelessWidget {
  const OffChip({required this.percent, super.key});
  final int percent;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: OV.greenSoft,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          '$percent% OFF',
          style: jakarta(12.sp, w: FontWeight.w700, color: AU.greenText),
        ),
      );
}

/// White rounded card used on Order Details.
class OrderCardBox extends StatelessWidget {
  const OrderCardBox({
    required this.child,
    this.padding,
    this.margin,
    super.key,
  });
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: margin ?? EdgeInsets.only(bottom: 12.h),
        padding: padding ?? EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: OV.card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: OV.border),
        ),
        child: child,
      );
}

IconData get truckIcon => PhosphorIconsRegular.truck;
