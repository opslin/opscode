import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show
        AuctionAppBar,
        AuctionButton,
        BottomActionBar,
        ErrorState,
        ProductThumb,
        SummaryRow,
        errorText,
        formatDateTime,
        heading;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/orders/application/orders_providers.dart';
import 'package:dealker_vendor/features/orders/data/order_models.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/order_actions.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/order_art.dart';
import 'package:dealker_vendor/features/returns/presentation/order_returns_banner.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// A product or auction order: what was bought, who by, where to, the money, and the next step.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;

  ({String key, String label, IconData icon})? _next(OrderDetail o) {
    final s = o.status.toUpperCase();
    if (s == 'ORDER_PLACED' && o.canAct) {
      return (
        key: 'confirm',
        label: 'Accept order',
        icon: PhosphorIconsFill.checkCircle
      );
    }
    if (s == 'CONFIRMED') {
      return (
        key: 'pack',
        label: 'Mark as packed',
        icon: PhosphorIconsFill.package
      );
    }
    if (s == 'PACKED' || s == 'READY_TO_SHIP') {
      return (
        key: 'ship',
        label: 'Ship it',
        icon: PhosphorIconsFill.paperPlaneTilt
      );
    }
    return null;
  }

  Future<void> _run(String key) async {
    setState(() => _busy = true);
    await runOrderAction(context, ref,
        kind: OrderKind.product, id: widget.id, key: key);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel this order?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'The stock goes back on sale. If the buyer already paid online, Dealkr refunds them.'),
          const SizedBox(height: 10),
          TextField(
              controller: reason,
              decoration: const InputDecoration(hintText: 'Reason (required)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep order')),
          TextButton(
              onPressed: () {
                if (reason.text.trim().length < 3) return;
                Navigator.pop(c, true);
              },
              child: const Text('Cancel order',
                  style: TextStyle(color: AppColors.rose))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(ordersRepositoryProvider)
          .setStatus(widget.id, 'CANCELLED', reason: reason.text.trim());
      refreshOrders(ref, id: widget.id);
      if (mounted) showAppToast(context, 'Order cancelled.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(orderDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(
        title: 'Order details',
        onBack: () => context.canPop() ? context.pop() : context.go('/orders'),
      ),
      body: d.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'Could not load this order.'),
            onRetry: () => ref.invalidate(orderDetailProvider(widget.id))),
        data: _body,
      ),
    );
  }

  Widget _body(OrderDetail o) {
    final n = _next(o);
    final s = o.status.toUpperCase();
    final canCancel = const [
      'ORDER_PLACED',
      'CONFIRMED',
      'PACKED',
      'READY_TO_SHIP'
    ].contains(s);
    final awaiting = s == 'ORDER_PLACED' && !o.canAct;
    final info = _stageInfo(s, awaiting);
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(orderDetailProvider(widget.id));
            await ref.read(orderDetailProvider(widget.id).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Hero(o: o, info: info, status: s, awaiting: awaiting),
              const SizedBox(height: 12),
              if (!const ['CANCELLED', 'RETURNED'].contains(s))
                _Stepper(status: s),
              if (!const ['CANCELLED', 'RETURNED'].contains(s))
                const SizedBox(height: 12),
              OrderReturnsBanner(sellerOrderId: widget.id),
              if (info.todo != null) ...[
                _TodoCard(info: info),
                const SizedBox(height: 12),
              ],
              _SectionCard(
                title: 'Items to pack',
                art: OrderArt.parcelOpen,
                child: Column(children: [
                  for (final i in o.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        ProductThumb(i.image, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(i.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                      color: AppColors.navy)),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFEFF4FF),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                    'Qty ${i.quantity.toStringAsFixed(i.quantity % 1 == 0 ? 0 : 2)}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary)),
                              ),
                            ])),
                        Text(formatInr(i.subtotal),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Deliver to',
                art: OrderArt.user,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (o.buyer.isNotEmpty)
                        Text(o.buyer,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                      if (o.address.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(PhosphorIconsFill.mapPin,
                                  size: 17, color: AppColors.rose),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(o.address,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          height: 1.4,
                                          color: AppColors.textSecondary))),
                            ]),
                      ],
                      if (o.phone.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(PhosphorIconsFill.phone,
                              size: 17, color: AppColors.mint),
                          const SizedBox(width: 8),
                          Text(o.phone,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ]),
                      ],
                    ]),
              ),
              if (o.courier != null) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Shipment',
                  art: OrderArt.track,
                  child: Row(children: [
                    const Icon(PhosphorIconsFill.truck,
                        size: 22, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(o.courier!,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy)),
                          if (o.awb != null)
                            Text('Token  ${o.awb}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                        ])),
                    if (o.awb != null)
                      IconButton(
                        tooltip: 'Copy token',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: o.awb!));
                          showAppToast(context, 'Token copied.');
                        },
                        icon: const Icon(PhosphorIconsRegular.copy, size: 20),
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Your earnings',
                art: OrderArt.wallet,
                child: Column(children: [
                  SummaryRow('Order value', formatInr(o.subtotal)),
                  SummaryRow(
                      'Dealkr commission', '− ${formatInr(o.commission)}'),
                  if (o.shipping > 0)
                    SummaryRow('Shipping', '− ${formatInr(o.shipping)}'),
                  SummaryRow('You receive', formatInr(o.payable), bold: true),
                ]),
              ),
              if (s == 'SHIPPED' || s == 'OUT_FOR_DELIVERY') ...[
                const SizedBox(height: 12),
                const Text(
                    'Dealkr confirms delivery, then your payout is released.',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ],
              if (s == 'CANCELLED' && o.cancelReason != null) ...[
                const SizedBox(height: 12),
                Text('Cancelled: ${o.cancelReason}',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.rose)),
              ],
            ],
          ),
        ),
      ),
      if (n != null || canCancel)
        BottomActionBar(
          child: Row(children: [
            if (canCancel)
              Expanded(
                  child: AuctionButton(
                      label: 'Cancel',
                      outlined: true,
                      danger: true,
                      onPressed: _busy ? null : _cancel)),
            if (canCancel && n != null) const SizedBox(width: 10),
            if (n != null)
              Expanded(
                  flex: 2,
                  child: AuctionButton(
                      label: n.label,
                      icon: n.icon,
                      loading: _busy,
                      onPressed: () => _run(n.key))),
          ]),
        ),
    ]);
  }
}

// ── stage copy ───────────────────────────────────────────────────────────

class _StageInfo {
  const _StageInfo(this.art, this.title, this.sub, this.colors,
      {this.todo, this.todoTitle});
  final OrderArt art;
  final String title;
  final String sub;
  final List<Color> colors;
  final List<String>? todo;
  final String? todoTitle;
}

_StageInfo _stageInfo(String s, bool awaiting) {
  if (awaiting) {
    return const _StageInfo(
      OrderArt.pending,
      'Waiting for payment',
      'The buyer has not paid yet. You can accept the order as soon as the payment arrives.',
      [Color(0xFFF59E0B), Color(0xFFF97316)],
    );
  }
  return switch (s) {
    'ORDER_PLACED' => const _StageInfo(
        OrderArt.placed,
        'New order!',
        'A buyer is waiting. Accept it to start packing.',
        [Color(0xFF1F6FEB), Color(0xFF4F46E5)],
        todoTitle: 'Your next step: Accept',
        todo: [
          'Check you have the items in stock',
          'Tap “Accept order” - the buyer is told straight away',
        ],
      ),
    'CONFIRMED' => const _StageInfo(
        OrderArt.confirmed,
        'Accepted - pack it now',
        'The buyer knows you accepted. Pack the items carefully.',
        [Color(0xFF0EA5E9), Color(0xFF1F6FEB)],
        todoTitle: 'Your next step: Pack',
        todo: [
          'Pack every item below with its box and bill',
          'Tap “Mark as packed” when the parcel is sealed',
        ],
      ),
    'PACKED' || 'READY_TO_SHIP' => const _StageInfo(
        OrderArt.packed,
        'Packed - ready to ship',
        'Hand the parcel to Porter or any courier, then add the tracking token.',
        [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        todoTitle: 'Your next step: Ship',
        todo: [
          'Book Porter / a courier and hand over the parcel',
          'Tap “Ship it”, pick the courier and paste its token',
        ],
      ),
    'SHIPPED' => const _StageInfo(
        OrderArt.truck,
        'Shipped',
        'The parcel is on its way. The buyer can track it.',
        [Color(0xFF14B8A6), Color(0xFF0E9F8F)],
      ),
    'OUT_FOR_DELIVERY' => const _StageInfo(
        OrderArt.scooter,
        'Out for delivery',
        'It will reach the buyer today.',
        [Color(0xFF14B8A6), Color(0xFF0E9F8F)],
      ),
    'DELIVERED' || 'CLOSED' => const _StageInfo(
        OrderArt.delivered,
        'Delivered',
        'All done. Your payout is released by Dealkr.',
        [Color(0xFF22C55E), Color(0xFF16A34A)],
      ),
    'RETURNED' => const _StageInfo(
        OrderArt.returned,
        'Returned',
        'The buyer returned this order.',
        [Color(0xFF64748B), Color(0xFF475569)],
      ),
    _ => const _StageInfo(
        OrderArt.cancelled,
        'Cancelled',
        'This order was cancelled.',
        [Color(0xFFEF4444), Color(0xFFDC2626)],
      ),
  };
}

class _Hero extends StatelessWidget {
  const _Hero(
      {required this.o,
      required this.info,
      required this.status,
      required this.awaiting});
  final OrderDetail o;
  final _StageInfo info;
  final String status;
  final bool awaiting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: info.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: info.colors.last.withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  '#${o.parentNumber.isEmpty ? o.number : o.parentNumber}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            const SizedBox(height: 10),
            Text(info.title,
                style: const TextStyle(
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(info.sub,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.92))),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _HeroChip(
                  icon: PhosphorIconsFill.currencyInr,
                  text: 'You get ${formatInr(o.payable)}'),
              _HeroChip(
                  icon: o.paid
                      ? PhosphorIconsFill.sealCheck
                      : PhosphorIconsFill.money,
                  text: o.paid
                      ? 'Paid online'
                      : o.cod
                          ? 'Cash on delivery'
                          : 'Payment pending'),
            ]),
            const SizedBox(height: 8),
            Text('Placed ${formatDateTime(o.createdAt)}',
                style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.8))),
          ]),
        ),
        FloatingArt(info.art, size: 104),
      ]),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      );
}

/// Accept → Pack → Ship → Delivered, each as a 3D icon: done = colour + tick, now = pulsing, next = faded.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.status});
  final String status;

  static const _steps = [
    ('Accept', OrderArt.confirmed),
    ('Pack', OrderArt.packed),
    ('Ship', OrderArt.truck),
    ('Delivered', OrderArt.delivered),
  ];

  int get _done => switch (status) {
        'ORDER_PLACED' => 0,
        'CONFIRMED' => 1,
        'PACKED' || 'READY_TO_SHIP' => 2,
        'SHIPPED' || 'OUT_FOR_DELIVERY' => 3,
        _ => 4,
      };

  @override
  Widget build(BuildContext context) {
    final done = _done;
    return HomeCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: Row(children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < done
                        ? AppColors.mintSoft
                        : i == done
                            ? const Color(0xFFE9F1FF)
                            : const Color(0xFFF3F5FA),
                    border: Border.all(
                        color: i < done
                            ? AppColors.mint
                            : i == done
                                ? AppColors.primary
                                : Colors.transparent,
                        width: i == done ? 2.2 : 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                      opacity: i > done ? 0.35 : 1,
                      child: OrderArtImage(_steps[i].$2, size: 38)),
                ),
                if (i < done)
                  const Positioned(
                      right: -2,
                      bottom: -2,
                      child: Icon(PhosphorIconsFill.checkCircle,
                          size: 20, color: AppColors.mint)),
              ]),
              const SizedBox(height: 6),
              Text(_steps[i].$1,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == done ? FontWeight.w800 : FontWeight.w600,
                      color: i <= done ? AppColors.navy : AppColors.textMuted)),
            ]),
          ),
          if (i < _steps.length - 1)
            Container(
              width: 14,
              height: 3,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                  color: i < done ? AppColors.mint : const Color(0xFFE2E7F1),
                  borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ]),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.info});
  final _StageInfo info;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFCE7A8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(PhosphorIconsFill.lightbulb,
                size: 20, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Text(info.todoTitle ?? 'What to do',
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E))),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < info.todo!.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B), shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(info.todo![i],
                        style: const TextStyle(
                            fontSize: 13.2,
                            height: 1.35,
                            color: Color(0xFF78350F)))),
              ]),
            ),
        ]),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.art, required this.child});
  final String title;
  final OrderArt art;
  final Widget child;

  @override
  Widget build(BuildContext context) => HomeCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            OrderArtImage(art, size: 30),
            const SizedBox(width: 8),
            Text(title, style: heading(size: 15.5)),
          ]),
          const SizedBox(height: 8),
          child,
        ]),
      );
}
