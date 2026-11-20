import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/order_sheets.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/invoice_sheet.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

/// Order tracking for both sides of a deal: Offer accepted → Payment → Packing → Pickup / Dispatch →
/// Delivered → Payment released. Buyer and seller each get the next action they need.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Status changes on the other side show up without the vendor pulling to refresh.
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_busy && screenActive(context)) {
        ref.invalidate(orderDetailProvider(widget.id));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _changed() {
    refreshDemand(ref);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _changed();
      showAppToast(context, done);
    } catch (e) {
      if (mounted) {
        showAppToast(context, errorText(e, 'Something went wrong.'),
            error: true, bottom: 100);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The seller's own invoice must be on file before packing or dispatching. False = vendor backed out.
  Future<bool> _ensureInvoice(OrderDetail d) async {
    if (d.order.hasInvoice) return true;
    final up = await showInvoiceSheet(context, orderNumber: d.order.orderNumber);
    if (up == null || !mounted) return false;
    try {
      await ref
          .read(demandRepositoryProvider)
          .uploadOrderInvoice(d.order.id, up.file, number: up.number);
      return true;
    } catch (e) {
      if (mounted) {
        showAppToast(context, errorText(e, 'Could not upload the invoice.'),
            error: true, bottom: 100);
      }
      return false;
    }
  }

  Future<void> _packDevice(OrderDetail d, int unitNo, bool packed) async {
    try {
      await ref.read(demandRepositoryProvider).packDevice(d.order.id, unitNo, packed);
      ref.invalidate(orderDetailProvider(d.order.id));
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e, 'Could not update this device.'), error: true);
    }
  }

  Future<void> _pack(OrderDetail d) async {
    if (!await _ensureInvoice(d) || !mounted) return;
    await _run(
        () => ref
            .read(demandRepositoryProvider)
            .setOrderStatus(d.order.id, {'status': 'PACKED'}),
        'Marked as packed. The buyer is notified.');
  }

  Future<void> _dispatch(OrderDetail d) async {
    if (!await _ensureInvoice(d) || !mounted) return;
    final body = await showDispatchSheet(context,
        order: d.order, requirement: d.requirement);
    if (body == null || !mounted) return;
    await _run(
        () =>
            ref.read(demandRepositoryProvider).setOrderStatus(d.order.id, body),
        body['fulfilmentType'] == 'PICKUP'
            ? 'Pickup scheduled. The buyer is notified.'
            : 'Dispatched. The buyer can follow the tracking ID.');
  }

  Future<void> _delivered(OrderDetail d) async {
    final ok = await confirmAction(context,
        title: 'Mark as delivered?',
        message:
            'Only do this once the courier has handed the order over. The buyer will then confirm what they received.',
        confirmLabel: 'Yes, delivered');
    if (!ok || !mounted) return;
    await _run(
        () => ref
            .read(demandRepositoryProvider)
            .setOrderStatus(d.order.id, {'status': 'DELIVERED'}),
        'Marked as delivered.');
  }

  Future<void> _cancel(OrderDetail d) async {
    final reason = await showCancelOrderSheet(context, order: d.order);
    if (reason == null || !mounted) return;
    await _run(
        () =>
            ref.read(demandRepositoryProvider).cancelOrder(d.order.id, reason),
        'Order cancelled. The buyer has been refunded.');
  }

  Future<void> _receive(OrderDetail d) async {
    final res = await showReceiveSheet(context, order: d.order);
    if (res == null || !mounted) return;
    await _run(
      () => ref.read(demandRepositoryProvider).receive(d.order.id,
          quantity: res.quantity, ok: res.ok, note: res.note),
      res.ok
          ? 'Receipt confirmed. Payment released to the seller.'
          : 'Issue reported. Dealkr will review it and get back to you.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(orderDetailProvider(widget.id));
    return detail.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => Scaffold(
        backgroundColor: const Color(0xFFF6F8FE),
        appBar: const AuctionAppBar(title: 'Order Tracking'),
        body: ListView(padding: const EdgeInsets.all(16), children: const [
          CardSkeleton(height: 130),
          CardSkeleton(height: 320),
          CardSkeleton()
        ]),
      ),
      error: (e, _) => Scaffold(
        appBar: const AuctionAppBar(title: 'Order Tracking'),
        body: ErrorState(
            message: errorText(e, 'Could not load this order.'),
            onRetry: () => ref.invalidate(orderDetailProvider(widget.id))),
      ),
      data: _content,
    );
  }

  Widget _content(OrderDetail d) {
    final o = d.order;
    final buyer = d.isBuyer;
    final bar = _actions(d);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(title: 'Order Tracking', subtitle: o.orderNumber),
      bottomNavigationBar: bar,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(orderDetailProvider(o.id));
          await ref.read(orderDetailProvider(o.id).future).catchError((_) => d);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (o.status == OrderStatus.completed)
              _DoneCard(d: d)
            else
              _Summary(d: d),
            const SizedBox(height: 12),
            if (_banner(d) case final b?) ...[b, const SizedBox(height: 12)],
            Section(
              title: 'Order progress',
              child: StepTimeline(steps: _steps(d)),
            ),
            if (d.devices.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Devices(d: d, onToggle: (n, v) => _packDevice(d, n, v)),
            ],
            const SizedBox(height: 12),
            _Handover(d: d),
            _Party(d: d),
            const SizedBox(height: 12),
            _Money(d: d, buyer: buyer),
            if (d.events.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Activity(events: d.events)
            ],
          ],
        ),
      ),
    );
  }

  // ── bottom actions ───────────────────────────────────────────────

  Widget? _actions(OrderDetail d) {
    final o = d.order;
    if (d.isBuyer) {
      if (o.status == OrderStatus.pendingPayment) {
        return BottomActionBar(
          child: AuctionButton(
            label: 'Pay ${formatInr(o.subtotal)}',
            icon: PhosphorIconsBold.lockKey,
            onPressed: () async {
              await context.push(Routes.demandPay(o.requirementId));
              if (mounted) refreshDemand(ref);
            },
          ),
        );
      }
      if (o.status == OrderStatus.dispatched ||
          o.status == OrderStatus.delivered) {
        return BottomActionBar(
          child: AuctionButton(
              label: 'Confirm receipt',
              icon: PhosphorIconsBold.checkCircle,
              loading: _busy,
              onPressed: () => _receive(d)),
        );
      }
      return null;
    }
    // seller
    switch (o.status) {
      case OrderStatus.paid:
        return BottomActionBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                  child: AuctionButton(
                      label: 'Mark packed',
                      outlined: true,
                      height: 50,
                      loading: _busy,
                      onPressed: () => _pack(d))),
              const SizedBox(width: 10),
              Expanded(
                  flex: 2,
                  child: AuctionButton(
                      label: 'Dispatch / pickup',
                      icon: PhosphorIconsBold.truck,
                      height: 50,
                      loading: _busy,
                      onPressed: () => _dispatch(d))),
            ]),
            TextButton(
              onPressed: _busy ? null : () => _cancel(d),
              child: const Text('Can’t fulfil — cancel & refund buyer',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.rose,
                      fontSize: 13.5)),
            ),
          ]),
        );
      case OrderStatus.packed:
        return BottomActionBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AuctionButton(
                label: 'Dispatch / pickup',
                icon: PhosphorIconsBold.truck,
                loading: _busy,
                onPressed: () => _dispatch(d)),
            TextButton(
              onPressed: _busy ? null : () => _cancel(d),
              child: const Text('Can’t fulfil — cancel & refund buyer',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.rose,
                      fontSize: 13.5)),
            ),
          ]),
        );
      case OrderStatus.dispatched:
        if (o.isPickup) return null; // the buyer confirms when they collect it
        return BottomActionBar(
          child: AuctionButton(
              label: 'Mark as delivered',
              icon: PhosphorIconsBold.checkCircle,
              outlined: true,
              loading: _busy,
              onPressed: () => _delivered(d)),
        );
      default:
        return null;
    }
  }

  // ── contextual banner ───────────────────────────────────────────

  Widget? _banner(OrderDetail d) {
    final o = d.order;
    final buyer = d.isBuyer;
    switch (o.status) {
      case OrderStatus.pendingPayment:
        return Notice(
          icon: PhosphorIconsFill.hourglassMedium,
          title: buyer ? 'Payment due' : 'Waiting for the buyer’s payment',
          text: buyer
              ? 'Pay ${formatInr(o.subtotal)} to confirm this order. It is held safely until you receive it.'
              : 'You can pack and dispatch once ${o.buyerName} pays into escrow.',
          color: kAmberText,
          bg: AppColors.amberSoft,
        );
      case OrderStatus.paid:
        return Notice(
          icon: PhosphorIconsFill.shieldCheck,
          title: buyer ? 'Payment secured' : 'Payment is in escrow — pack it',
          text: buyer
              ? 'The seller has been asked to pack and ${d.requirement.fulfilmentPref == 'PICKUP' ? 'schedule a pickup' : 'dispatch'}.'
              : 'Pack the order and dispatch it, or schedule a pickup for the buyer.',
          color: kDemandBlue,
          bg: kDemandBlueSoft,
        );
      case OrderStatus.dispatched:
        if (o.isPickup) {
          return Notice(
            icon: PhosphorIconsFill.storefront,
            title: buyer ? 'Ready for pickup' : 'Pickup scheduled',
            text: buyer
                ? 'Collect it on ${dateTimeShort(o.pickupAt)}. Confirm receipt once you have checked the pieces.'
                : 'The buyer collects it on ${dateTimeShort(o.pickupAt)}. They confirm receipt at pickup and your payment is released.',
            color: kDemandBlue,
            bg: kDemandBlueSoft,
          );
        }
        return Notice(
          icon: PhosphorIconsFill.truck,
          title: buyer ? 'On the way' : 'Dispatched',
          text: buyer
              ? 'Track it with ${o.courierName ?? 'the courier'} using the tracking ID below. Confirm receipt when it arrives.'
              : 'Once the courier delivers it, mark it as delivered. The buyer then confirms and your payment is released.',
          color: kDemandBlue,
          bg: kDemandBlueSoft,
        );
      case OrderStatus.delivered:
        return Notice(
          icon: PhosphorIconsFill.package,
          title: buyer
              ? 'Delivered — please confirm'
              : 'Delivered — waiting for the buyer',
          text: buyer
              ? 'Check what you received and confirm, or report a problem.'
              : 'Your payment is released as soon as ${o.buyerName} confirms the pieces.',
          color: AppColors.mint,
          bg: AppColors.mintSoft,
        );
      case OrderStatus.disputed:
        return Notice(
          icon: PhosphorIconsFill.flag,
          title: 'Issue reported — Dealkr is reviewing',
          text: [
            if (o.disputeReason != null) '“${o.disputeReason}”.',
            'The payment stays in escrow until Dealkr decides whether to release it, refund it, or split it.',
          ].join(' '),
          color: AppColors.rose,
          bg: AppColors.roseSoft,
        );
      case OrderStatus.cancelled:
        return Notice(
          icon: PhosphorIconsFill.xCircle,
          title: 'Order cancelled',
          text: [
            if (o.cancelReason != null) 'Reason: ${o.cancelReason}.',
            if (o.paymentStatus == 'REFUNDED') 'The buyer was refunded in full.'
          ].join(' '),
          color: AppColors.textSecondary,
          bg: kGreySoft,
        );
      case OrderStatus.refunded:
        return Notice(
          icon: PhosphorIconsFill.arrowUUpLeft,
          title: 'Refunded',
          text: buyer
              ? 'Your payment was returned to your wallet.'
              : 'Dealkr refunded the buyer after reviewing the issue.',
          color: AppColors.textSecondary,
          bg: kGreySoft,
        );
      default:
        return null;
    }
  }

  // ── timeline ────────────────────────────────────────────────────

  List<TimelineStep> _steps(OrderDetail d) {
    final o = d.order;
    final buyer = d.isBuyer;
    final cancelled =
        o.status == OrderStatus.cancelled || o.status == OrderStatus.refunded;
    final paid = o.paidAt != null;
    final packed = o.packedAt != null || o.dispatchedAt != null;
    final sent = o.dispatchedAt != null;
    final received = o.receivedAt != null ||
        o.deliveredAt != null ||
        o.status == OrderStatus.completed;
    final released = o.status == OrderStatus.completed;
    final disputed = o.status == OrderStatus.disputed;
    final method = o.paymentMethod == 'WALLET'
        ? 'Dealkr wallet'
        : (o.paymentMethod ?? 'Payment');

    bool cur(bool done, bool prev) => !done && prev && !cancelled;

    final steps = <TimelineStep>[
      TimelineStep(
        title: 'Offer accepted',
        subtitle: buyer
            ? '${o.sellerName} · ${pcs(o.quantity)} at ${formatInr(o.unitPrice)}'
            : '${o.buyerName} chose your offer',
        time: o.createdAt,
        done: true,
      ),
      TimelineStep(
        title: paid ? 'Payment done' : 'Payment',
        subtitle: paid
            ? '${formatInr(o.subtotal)} held in escrow · $method'
            : (cancelled
                ? null
                : (buyer
                    ? 'Pay to confirm the order'
                    : 'Waiting for the buyer')),
        time: o.paidAt,
        done: paid,
        current: cur(paid, true),
      ),
      TimelineStep(
        title: packed ? 'Packed & ready' : 'Processing',
        subtitle: packed
            ? 'Seller has packed the order'
            : (paid && !cancelled ? 'Seller is packing the order' : null),
        time: o.packedAt,
        done: packed,
        current: cur(packed, paid),
      ),
      TimelineStep(
        title: o.isPickup
            ? 'Pickup scheduled'
            : (sent ? 'Dispatched' : 'Pickup / dispatch'),
        subtitle: sent
            ? (o.isPickup
                ? [
                    dateTimeShort(o.pickupAt),
                    if (o.pickupNote != null) o.pickupNote!
                  ].join(' · ')
                : [
                    if (o.courierName != null) o.courierName!,
                    if (o.awb != null) 'Tracking ID ${o.awb}'
                  ].join(' · '))
            : (paid && !cancelled
                ? 'Waiting for the seller to ${buyer ? 'dispatch' : 'dispatch or schedule pickup'}'
                : null),
        time: o.dispatchedAt,
        done: sent,
        current: cur(sent, packed),
        trailing: sent && !o.isPickup && o.awb != null
            ? GestureDetector(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: o.trackingUrl ?? o.awb!));
                  showAppToast(
                      context,
                      o.trackingUrl != null
                          ? 'Tracking link copied.'
                          : 'Tracking ID copied.');
                },
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIconsRegular.copy, size: 14, color: kDemandBlue),
                  SizedBox(width: 4),
                  Text('Copy',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: kDemandBlue)),
                ]),
              )
            : null,
      ),
      TimelineStep(
        title:
            disputed ? 'Issue reported' : (received ? 'Received' : 'Delivered'),
        subtitle: disputed
            ? o.disputeReason
            : (received
                ? (o.receivedQuantity != null
                    ? '${o.receivedQuantity} of ${o.quantity} pcs received'
                    : 'Delivered')
                : (sent && !cancelled
                    ? (buyer
                        ? 'Confirm once you have it'
                        : 'Waiting for the buyer to confirm')
                    : null)),
        time: o.receivedAt ?? o.deliveredAt,
        done: received && !disputed,
        current: disputed || cur(received, sent),
      ),
      TimelineStep(
        title: released ? 'Payment released' : 'Settlement',
        subtitle: released
            ? (buyer
                ? '${o.sellerName} has been paid'
                : '${formatInr(o.releasedAmount ?? o.sellerPayable)} credited to your wallet')
            : (cancelled
                ? null
                : (buyer
                    ? 'Seller is paid after you confirm'
                    : 'Credited to your wallet after the buyer confirms')),
        done: released,
        current: false,
      ),
    ];
    if (cancelled) {
      return [
        steps.first,
        if (paid) steps[1],
        TimelineStep(
            title: o.status == OrderStatus.refunded
                ? 'Refunded'
                : 'Order cancelled',
            subtitle: o.cancelReason,
            done: true),
      ];
    }
    return steps;
  }
}

// ── blocks ───────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.d});
  final OrderDetail d;

  @override
  Widget build(BuildContext context) {
    final o = d.order;
    return Section(
      child: Column(children: [
        Row(children: [
          Expanded(
              child: Text('Order #${o.orderNumber}', style: heading(size: 16))),
          OrderStatusPill(o, buyer: d.isBuyer),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          ProductThumb(d.requirement.thumbnail, size: 58, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(requirementTitle(d.requirement),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: heading(size: 15.5)),
              const SizedBox(height: 3),
              Text('${pcs(o.quantity)} × ${formatInr(o.unitPrice)}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ]),
          ),
          Text(formatInr(o.subtotal),
              style: heading(size: 18, w: FontWeight.w800)),
        ]),
      ]),
    );
  }
}

/// "Order Delivered!" — the finished-deal card with the settlement.
class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.d});
  final OrderDetail d;

  @override
  Widget build(BuildContext context) {
    final o = d.order;
    final amount =
        d.isBuyer ? o.subtotal : (o.releasedAmount ?? o.sellerPayable);
    return Section(
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
              color: AppColors.mint, shape: BoxShape.circle),
          child: const Icon(PhosphorIconsBold.check,
              color: Colors.white, size: 34),
        ),
        const SizedBox(height: 12),
        Text('Order delivered!', style: heading(size: 22)),
        const SizedBox(height: 4),
        Text(
            '${requirementTitle(d.requirement)} · ${pcs(o.receivedQuantity ?? o.quantity)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13.5, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.mintSoft,
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(PhosphorIconsFill.wallet,
                color: AppColors.mint, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                d.isBuyer
                    ? 'Payment released to ${o.sellerName}'
                    : 'Credited to your wallet',
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy),
              ),
            ),
            Text(formatInr(amount),
                style: heading(
                    size: 18, color: AppColors.mint, w: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}

/// Where and how the goods change hands: pickup slot / courier, tracking ID.
class _Handover extends StatelessWidget {
  const _Handover({required this.d});
  final OrderDetail d;

  @override
  Widget build(BuildContext context) {
    final o = d.order;
    if (o.dispatchedAt == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Section(
        title: o.isPickup ? 'Pickup' : 'Shipment',
        child: o.isPickup
            ? Column(children: [
                KV('When', dateTimeShort(o.pickupAt)),
                if (d.seller.place != null) KV('Where', d.seller.place!),
                if (o.pickupNote != null) KV('Note', o.pickupNote!),
              ])
            : Column(children: [
                KV('Courier', o.courierName ?? '—'),
                KV('Tracking ID', o.awb ?? '—'),
                if (o.trackingUrl != null)
                  KV('Tracking link', o.trackingUrl!, valueColor: kDemandBlue),
              ]),
      ),
    );
  }
}

class _Party extends StatelessWidget {
  const _Party({required this.d});
  final OrderDetail d;

  @override
  Widget build(BuildContext context) {
    final p = d.counterparty;
    final paid = d.order.paidAt != null;
    final delivery = d.requirement.deliveryCity;
    return Section(
      title: d.isBuyer ? 'Seller' : 'Buyer',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Initials(p.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: heading(size: 15.5)),
              const SizedBox(height: 2),
              const Row(children: [
                Icon(PhosphorIconsFill.sealCheck,
                    size: 14, color: AppColors.mint),
                SizedBox(width: 4),
                Text('Verified Dealkr vendor',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ]),
            ]),
          ),
        ]),
        if (paid && p.phone != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: p.phone!));
              showAppToast(context, 'Phone number copied.');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FE),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(PhosphorIconsRegular.phone,
                    size: 18, color: kDemandBlue),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(p.phone!,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy))),
                const Text('Copy',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kDemandBlue)),
              ]),
            ),
          ),
        ],
        if (d.isBuyer && p.place != null && paid) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(PhosphorIconsRegular.mapPin,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
                child: Text(p.place!,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary))),
          ]),
        ],
        if (!d.isBuyer && delivery != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(PhosphorIconsRegular.mapPin,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
                'Deliver to $delivery${d.requirement.deliveryPincode == null ? '' : ' ${d.requirement.deliveryPincode}'}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ]),
        ],
        if (!paid)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Contact details are shared once the order is paid.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
      ]),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.d, required this.buyer});
  final OrderDetail d;
  final bool buyer;

  @override
  Widget build(BuildContext context) {
    final o = d.order;
    final held = o.paymentStatus == 'ESCROW_HELD';
    final pct = o.commissionPercent == o.commissionPercent.roundToDouble()
        ? o.commissionPercent.toStringAsFixed(0)
        : o.commissionPercent.toStringAsFixed(1);
    return Section(
      title: 'Payment & settlement',
      trailing: o.paymentStatus == 'UNPAID'
          ? null
          : Pill(
              held
                  ? 'Held in escrow'
                  : (o.paymentStatus == 'RELEASED' ? 'Released' : 'Refunded'),
              fg: held
                  ? kDemandBlue
                  : (o.paymentStatus == 'RELEASED'
                      ? AppColors.mint
                      : AppColors.textSecondary),
              bg: held
                  ? kDemandBlueSoft
                  : (o.paymentStatus == 'RELEASED'
                      ? AppColors.mintSoft
                      : kGreySoft),
            ),
      child: Column(children: [
        KV('${pcs(o.quantity)} × ${formatInr(o.unitPrice)}',
            formatInr(o.subtotal)),
        if (!buyer) ...[
          KV('Dealkr fee ($pct%)', '− ${formatInr(o.commissionAmount)}'),
          const Divider(height: 16, color: AppColors.cardBorder),
          KV('You receive', formatInr(o.sellerPayable),
              bold: true, valueColor: AppColors.mint),
        ] else ...[
          const Divider(height: 16, color: AppColors.cardBorder),
          KV('Total', formatInr(o.subtotal), bold: true),
          if (d.payment != null)
            KV(
                'Paid with',
                d.payment!.method == 'WALLET'
                    ? 'Dealkr wallet'
                    : d.payment!.method),
        ],
      ]),
    );
  }
}

class _Activity extends StatelessWidget {
  const _Activity({required this.events});
  final List<DemandEvent> events;

  static String _label(String t) => switch (t) {
        'POSTED' => 'Requirement posted',
        'AWARDED' => 'Offer accepted',
        'PAID' => 'Payment secured in escrow',
        'PACKED' => 'Packed',
        'DISPATCHED' => 'Dispatched / pickup scheduled',
        'DELIVERED' => 'Marked as delivered',
        'RECEIVED' => 'Receipt confirmed',
        'DISPUTED' => 'Issue reported',
        'DISPUTE_RESOLVED' => 'Dispute resolved',
        'ORDER_CANCELLED' => 'Order cancelled',
        _ => t
            .replaceAll('_', ' ')
            .toLowerCase()
            .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase()),
      };

  @override
  Widget build(BuildContext context) => Section(
        title: 'Activity',
        child: Column(children: [
          for (final e in events.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5, right: 10),
                    decoration: const BoxDecoration(
                        color: AppColors.borderStrong, shape: BoxShape.circle)),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_label(e.type),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                        if (e.note != null)
                          Text(e.note!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: AppColors.textSecondary)),
                      ]),
                ),
                Text(dateTimeShort(e.at),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ]),
            ),
        ]),
      );
}

/// Devices in this order. The seller ticks each one as it is packed; a packed device is locked for every other buyer.
class _Devices extends StatelessWidget {
  const _Devices({required this.d, required this.onToggle});
  final OrderDetail d;
  final void Function(int unitNo, bool packed) onToggle;

  @override
  Widget build(BuildContext context) {
    final packed = d.devices.where((x) => x.packed).length;
    final canPack = d.isSeller && (d.order.status == OrderStatus.paid || d.order.status == OrderStatus.packed);
    return Section(
      title: 'Devices in this order (${d.devices.length})',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(canPack ? '$packed of ${d.devices.length} packed. Tick each device when it is in the box.' : '$packed of ${d.devices.length} packed.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final x in d.devices)
            GestureDetector(
              onTap: canPack && x.status != 'SOLD' ? () => onToggle(x.unitNo, !x.packed) : null,
              child: Container(
                width: 104,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: x.packed ? AppColors.mintSoft : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: x.packed ? AppColors.mint : AppColors.cardBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(x.packed ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 16, color: x.packed ? AppColors.mint : AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text('Device ${x.unitNo}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ]),
                  const SizedBox(height: 4),
                  Text(x.packed ? 'Packed' : 'To pack', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: x.packed ? AppColors.mint : const Color(0xFFB45309))),
                  Text('QC ${x.score}${x.defects > 0 ? ' · ${x.defects} issue${x.defects == 1 ? '' : 's'}' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}
