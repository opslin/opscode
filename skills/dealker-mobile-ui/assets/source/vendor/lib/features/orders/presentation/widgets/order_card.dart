import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show ProductThumb, formatDateTime;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/orders/data/order_models.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/order_actions.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/order_art.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/order_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// One row of the Orders list: what, who, how much, where it stands, and the next step in one tap.
class OrderCard extends ConsumerStatefulWidget {
  const OrderCard(this.row, {super.key});
  final OrderRow row;

  @override
  ConsumerState<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<OrderCard> {
  bool _busy = false;
  OrderRow get r => widget.row;

  void _open() => context.push(r.kind == OrderKind.repair
      ? Routes.repairDetail(r.id)
      : Routes.orderDetail(r.id));

  Future<void> _act() async {
    final n = r.next!;
    // Steps that need input (QC result, estimate) happen on the detail screen.
    if (n.dashboard || n.key == 'qc') {
      _open();
      return;
    }
    setState(() => _busy = true);
    await runOrderAction(context, ref, kind: r.kind, id: r.id, key: n.key);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final n = r.next;
    return GestureDetector(
      onTap: _open,
      child: HomeCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            KindBadge(r.kind),
            const SizedBox(width: 8),
            Expanded(
              child: Text('#${r.number}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ),
            if (r.kind != OrderKind.repair) ...[
              OrderArtImage(
                  OrderArt.forStatus(r.status,
                      awaitingPayment: r.awaitingPayment),
                  size: 26),
              const SizedBox(width: 6),
            ],
            StatusPill(
                statusLabel(r.status, awaitingPayment: r.awaitingPayment),
                r.awaitingPayment ? 'NEW' : r.stage),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            r.kind == OrderKind.repair
                ? Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                        color: kindColors(OrderKind.repair).bg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(PhosphorIconsFill.wrench,
                        color: kindColors(OrderKind.repair).fg, size: 26))
                : ProductThumb(r.thumbnail, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        r.quantity > 1 ? '${r.title} × ${r.quantity}' : r.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: AppColors.navy)),
                    const SizedBox(height: 3),
                    Text(
                        [
                          if (r.customer.isNotEmpty) r.customer,
                          if (r.channel == 'B2B') 'Business',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                    if (r.createdAt != null)
                      Text(formatDateTime(r.createdAt),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textMuted)),
                  ]),
            ),
            if (r.amount > 0)
              Text(formatInr(r.amount),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy)),
          ]),
          if (n != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                onPressed: _busy ? null : _act,
                style: FilledButton.styleFrom(
                    backgroundColor: n.dashboard
                        ? const Color(0xFFEFF1F6)
                        : kindColors(r.kind).fg,
                    foregroundColor:
                        n.dashboard ? AppColors.navy : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11))),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!n.dashboard && r.kind == OrderKind.product) ...[
                            Icon(_actionIcon(n.key), size: 18),
                            const SizedBox(width: 8),
                          ],
                          Text(
                              n.dashboard
                                  ? '${n.label} — open job'
                                  : (r.kind == OrderKind.product &&
                                          n.key == 'confirm'
                                      ? 'Accept order'
                                      : n.label),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

IconData _actionIcon(String key) => switch (key) {
      'confirm' => PhosphorIconsFill.checkCircle,
      'pack' => PhosphorIconsFill.package,
      'ship' => PhosphorIconsFill.paperPlaneTilt,
      _ => PhosphorIconsFill.arrowRight,
    };
