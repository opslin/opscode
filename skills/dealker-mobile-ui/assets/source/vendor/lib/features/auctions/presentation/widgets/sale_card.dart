import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// What happens after the hammer falls: waiting for the buyer to pay, then
/// confirm → pack → ship. Shown on the seller's auction once it has a winner.
class SaleCard extends ConsumerStatefulWidget {
  const SaleCard({super.key, required this.auction});
  final AuctionItem auction;

  @override
  ConsumerState<SaleCard> createState() => _SaleCardState();
}

class _SaleCardState extends ConsumerState<SaleCard> {
  bool _busy = false;

  AuctionItem get a => widget.auction;

  void _refresh() {
    ref.invalidate(auctionDetailProvider(a.id));
    if (a.orderId != null) ref.invalidate(saleOrderProvider(a.orderId!));
  }

  Future<void> _status(SaleOrder o, String status, String done) async {
    setState(() => _busy = true);
    try {
      await ref.read(auctionRepositoryProvider).setSaleStatus(o.id, status);
      _refresh();
      if (mounted) showAppToast(context, done);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ship(SaleOrder o) async {
    final courier = TextEditingController();
    final awb = TextEditingController();
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
            18, 18, 18, 18 + MediaQuery.viewInsetsOf(c).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ship this order', style: heading(size: 18)),
              const SizedBox(height: 4),
              const Text(
                  'Enter how you are sending it. The buyer sees this tracking info.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 14),
              TextField(
                controller: courier,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Courier / delivery name (e.g. Blue Dart)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: awb,
                decoration: _dec('Tracking number (optional)'),
              ),
              const SizedBox(height: 16),
              AuctionButton(
                  label: 'Mark as shipped',
                  onPressed: () {
                    if (courier.text.trim().length < 2) return;
                    Navigator.pop(c, true);
                  }),
            ]),
      ),
    );
    if (go != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(auctionRepositoryProvider)
          .shipSale(o.id, courier: courier.text.trim(), awb: awb.text);
      _refresh();
      if (mounted) showAppToast(context, 'Marked as shipped.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF7F9FD),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final price = a.winningBid ?? a.currentPrice;
    final waiting = a.orderId == null;

    Widget head(IconData icon, Color color, String title, String sub) =>
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: heading(size: 15.5)),
              const SizedBox(height: 2),
              Text(sub,
                  style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.textSecondary)),
            ]),
          ),
        ]);

    if (waiting) {
      final due = a.paymentDeadline;
      return HomeCard(
        padding: const EdgeInsets.all(14),
        child: head(
          PhosphorIconsFill.hourglassMedium,
          const Color(0xFFB45309),
          'Sold to the top bidder at ${formatInr(price)}',
          due == null
              ? 'Waiting for the buyer to pay.'
              : 'Waiting for the buyer to pay by ${formatDateTime(due)}. If they miss it, the next bidder is offered the lot and you keep the forfeited fee share.',
        ),
      );
    }

    final order = ref.watch(saleOrderProvider(a.orderId!));
    return HomeCard(
      padding: const EdgeInsets.all(14),
      child: order.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(errorText(e, 'Could not load the order.'),
            style: const TextStyle(color: AppColors.rose)),
        data: (o) {
          if (o == null) {
            return head(
                PhosphorIconsFill.hourglassMedium,
                const Color(0xFFB45309),
                'Payment is being confirmed',
                'The buyer has started paying. The order appears here as soon as it is confirmed.');
          }
          final st = o.status.toUpperCase();
          final (label, color) = switch (st) {
            'ORDER_PLACED' => ('Paid — confirm the order', kAuctionBlue),
            'CONFIRMED' => ('Confirmed — pack it', kAuctionBlue),
            'PACKED' || 'READY_TO_SHIP' => (
                'Packed — ready to ship',
                kAuctionBlue
              ),
            'SHIPPED' || 'OUT_FOR_DELIVERY' => (
                'Shipped — on its way',
                AppColors.mint
              ),
            'DELIVERED' => ('Delivered', AppColors.mint),
            'CANCELLED' => ('Order cancelled', AppColors.rose),
            _ => ('Processing', AppColors.textSecondary),
          };
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                head(
                    st == 'DELIVERED'
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsFill.package,
                    color,
                    label,
                    'Order ${o.number} · sold at ${formatInr(price)}'),
                const SizedBox(height: 12),
                SummaryRow('Buyer pays', formatInr(a.amountDue ?? price)),
                if ((a.feeCredit ?? 0) > 0)
                  SummaryRow('Includes their registration fee',
                      formatInr(a.feeCredit!)),
                SummaryRow(
                    'Dealkr commission', '− ${formatInr(o.commission)}'),
                SummaryRow('You receive', formatInr(o.payable)),
                if (o.address.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Deliver to',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 3),
                  Text(
                      [
                        if (o.buyerName.isNotEmpty) o.buyerName,
                        o.address,
                        if (o.phone.isNotEmpty) o.phone,
                      ].join('\n'),
                      style: const TextStyle(
                          fontSize: 13.5, height: 1.4, color: AppColors.navy)),
                ],
                if (o.courier != null) ...[
                  const SizedBox(height: 8),
                  Text(
                      'Courier: ${o.courier}${o.awb != null ? ' · ${o.awb}' : ''}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
                if (st == 'SHIPPED' || st == 'OUT_FOR_DELIVERY') ...[
                  const SizedBox(height: 10),
                  const Text(
                      'Dealkr confirms delivery, then your payout is released.',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted)),
                ],
                if (const [
                  'ORDER_PLACED',
                  'CONFIRMED',
                  'PACKED',
                  'READY_TO_SHIP'
                ].contains(st)) ...[
                  const SizedBox(height: 14),
                  AuctionButton(
                    label: switch (st) {
                      'ORDER_PLACED' => 'Confirm order',
                      'CONFIRMED' => 'Mark as packed',
                      _ => 'Ship it',
                    },
                    loading: _busy,
                    onPressed: () => switch (st) {
                      'ORDER_PLACED' =>
                        _status(o, 'CONFIRMED', 'Order confirmed.'),
                      'CONFIRMED' => _status(o, 'PACKED', 'Marked as packed.'),
                      _ => _ship(o),
                    },
                  ),
                ],
              ]);
        },
      ),
    );
  }
}
