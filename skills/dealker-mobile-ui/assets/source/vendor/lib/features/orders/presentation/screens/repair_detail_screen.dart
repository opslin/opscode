import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show
        AuctionAppBar,
        AuctionButton,
        BottomActionBar,
        ErrorState,
        SummaryRow,
        errorText,
        heading;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/orders/application/orders_providers.dart';
import 'package:dealker_vendor/features/orders/data/order_models.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/order_actions.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/order_ui.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

String _stage(String s) => switch (s) {
      'REQUESTED' || 'ACCEPTED' => 'NEW',
      'REPAIRED' || 'READY_FOR_DELIVERY' => 'SHIPPED',
      'COMPLETED' => 'DONE',
      'REJECTED' || 'CANCELLED' => 'CANCELLED',
      _ => 'ACTIVE',
    };

/// A repair job assigned to this service centre: device(s), customer, money and the next step.
/// Estimates and recording payments stay in the web dashboard; the steps below are one tap.
class RepairDetailScreen extends ConsumerStatefulWidget {
  const RepairDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RepairDetailScreen> createState() => _RepairDetailScreenState();
}

class _RepairDetailScreenState extends ConsumerState<RepairDetailScreen> {
  bool _busy = false;

  Future<void> _run(String key) async {
    setState(() => _busy = true);
    await runOrderAction(context, ref,
        kind: OrderKind.repair, id: widget.id, key: key);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _qc(RepairDetail r, bool passed) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(passed ? 'QC passed?' : 'QC failed — send back to repair?'),
        content: TextField(
            controller: note,
            maxLines: 2,
            decoration: InputDecoration(
                hintText: passed ? 'Note (optional)' : 'What is still wrong?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Back')),
          TextButton(
              onPressed: () {
                if (!passed && note.text.trim().length < 3) return;
                Navigator.pop(c, true);
              },
              child: Text(passed ? 'Record pass' : 'Send to rework')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).repairQc(widget.id,
          itemIds: [
            for (final d in r.devices)
              if (d.status.toUpperCase() == 'PENDING' || d.status.isEmpty) d.id
          ],
          passed: passed,
          note: note.text.trim().isEmpty ? null : note.text.trim());
      refreshOrders(ref, id: widget.id);
      if (mounted) {
        showAppToast(context, passed ? 'QC passed.' : 'Sent back to repair.');
      }
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(repairDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(
        title: 'Repair job',
        onBack: () => context.canPop() ? context.pop() : context.go('/orders'),
      ),
      body: d.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'Could not load this repair.'),
            onRetry: () => ref.invalidate(repairDetailProvider(widget.id))),
        data: _body,
      ),
    );
  }

  Widget _body(RepairDetail r) {
    final s = r.status.toUpperCase();
    final step = switch (s) {
      'ACCEPTED' => (key: 'receive', label: 'Receive device'),
      'ESTIMATE_APPROVED' => (key: 'start', label: 'Start repair'),
      'IN_REPAIR' => (key: 'send-to-qc', label: 'Send to QC'),
      'REPAIRED' || 'FAILED' || 'ESTIMATE_REJECTED' => (
          key: 'ready',
          label: 'Mark ready'
        ),
      'READY_FOR_DELIVERY' => (key: 'deliver', label: 'Hand over to customer'),
      _ => null,
    };
    final hint = switch (s) {
      'INSPECTION' =>
        'Inspect the device, then send the estimate from the Dealkr dashboard (Repairs → this job).',
      'ESTIMATE_SENT' => 'Waiting for the customer to approve the estimate.',
      'READY_FOR_DELIVERY' when r.due > 0 =>
        '${formatInr(r.due)} is still due. Record the payment in the dashboard before handing over.',
      _ => null,
    };
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(repairDetailProvider(widget.id));
            await ref.read(repairDetailProvider(widget.id).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              HomeCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const KindBadge(OrderKind.repair),
                  const SizedBox(width: 10),
                  Expanded(child: Text('#${r.code}', style: heading(size: 17))),
                  StatusPill(statusLabel(s), _stage(s)),
                ]),
              ),
              const SizedBox(height: 12),
              HomeCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer', style: heading(size: 15)),
                      const SizedBox(height: 6),
                      Text(
                          [r.customer, r.phone]
                              .where((e) => e.isNotEmpty)
                              .join('\n'),
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.navy)),
                      if (r.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(r.address,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ]),
              ),
              const SizedBox(height: 12),
              HomeCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Devices', style: heading(size: 15)),
                      const SizedBox(height: 6),
                      for (final dv in r.devices)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dv.name,
                                    style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy)),
                                if (dv.problem.isNotEmpty)
                                  Text(dv.problem,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary)),
                              ]),
                        ),
                      if (r.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(r.description,
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textSecondary)),
                      ],
                    ]),
              ),
              if (r.approvedTotal > 0) ...[
                const SizedBox(height: 12),
                HomeCard(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Column(children: [
                    SummaryRow('Approved amount', formatInr(r.approvedTotal)),
                    SummaryRow('Paid so far', formatInr(r.amountPaid)),
                    SummaryRow('Still due', formatInr(r.due)),
                    if (r.vendorPayable != null)
                      SummaryRow('You receive', formatInr(r.vendorPayable!)),
                  ]),
                ),
              ],
              if (hint != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.amberSoft,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(hint,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4, color: Color(0xFF7A4A07))),
                ),
              ],
            ],
          ),
        ),
      ),
      if (s == 'QC_PENDING')
        BottomActionBar(
          child: Row(children: [
            Expanded(
                child: AuctionButton(
                    label: 'QC failed',
                    outlined: true,
                    danger: true,
                    onPressed: _busy ? null : () => _qc(r, false))),
            const SizedBox(width: 10),
            Expanded(
                child: AuctionButton(
                    label: 'QC passed',
                    loading: _busy,
                    onPressed: () => _qc(r, true))),
          ]),
        )
      else if (step != null)
        BottomActionBar(
          child: AuctionButton(
              label: step.label,
              loading: _busy,
              onPressed: () => _run(step.key)),
        ),
    ]);
  }
}
