import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart'
    show kAdGradient;
import 'package:dealker_vendor/features/payouts/application/payout_providers.dart';
import 'package:dealker_vendor/features/payouts/data/payout_models.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

const _filters = <(String, String)>[
  ('All', ''),
  ('Paid', 'PAID'),
  ('Processing', 'PROCESSING'),
];

/// Money Dealkr has sent (or is sending) to the vendor's bank account.
class PayoutHistoryScreen extends ConsumerStatefulWidget {
  const PayoutHistoryScreen({super.key});

  @override
  ConsumerState<PayoutHistoryScreen> createState() =>
      _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends ConsumerState<PayoutHistoryScreen> {
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(payoutsProvider(_status));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AuctionAppBar(
          title: 'Payout History', subtitle: 'Transfers to your bank'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(payoutsProvider(_status));
          await ref.read(payoutsProvider(_status).future).catchError((_) =>
              const PayoutPage(items: [], summary: PayoutSummary(), total: 0));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _Summary(summary: page.asData?.value.summary),
            const SizedBox(height: 14),
            SizedBox(
              height: 38,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final (label, value) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == value,
                      onSelected: (_) => setState(() => _status = value),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            page.when(skipLoadingOnReload: true, skipError: true, 
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SizedBox(
                  height: 320,
                  child: ErrorState(
                      message: errorText(e, 'Could not load your payouts.'),
                      onRetry: () => ref.invalidate(payoutsProvider(_status)))),
              data: (p) => p.items.isEmpty
                  ? SizedBox(
                      height: 320,
                      child: EmptyState(
                        icon: PhosphorIconsRegular.bank,
                        title:
                            _status.isEmpty ? 'No payouts yet' : 'Nothing here',
                        message: _status.isEmpty
                            ? 'When Dealkr sends your sales earnings to your bank, each transfer shows up here with its bank reference.'
                            : 'No payouts with this status.',
                      ))
                  : Column(children: [for (final x in p.items) _PayoutCard(x)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final PayoutSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    Widget cell(String label, String value, String? sub, Color color) =>
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            if (sub != null)
              Text(sub,
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 11.5)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          gradient: kAdGradient, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        cell(
            'Paid out',
            s == null ? '—' : formatInr(s.paid),
            s == null
                ? null
                : '${s.paidCount} transfer${s.paidCount == 1 ? '' : 's'}',
            Colors.white),
        Container(width: 1, height: 52, color: Colors.white24),
        const SizedBox(width: 16),
        cell(
            'On the way',
            s == null ? '—' : formatInr(s.inProgress),
            s == null ? null : '${s.inProgressCount} in progress',
            const Color(0xFFFFD66B)),
      ]),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard(this.p);
  final Payout p;

  (Color, Color) get _colors => switch (p.status) {
        PayoutStatus.paid => (AppColors.success, const Color(0xFFE3F6EA)),
        PayoutStatus.processing || PayoutStatus.pending => (
            const Color(0xFFB45309),
            const Color(0xFFFFF1D6)
          ),
        _ => (AppColors.rose, AppColors.roseSoft),
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colors;
    final date =
        p.status == PayoutStatus.paid ? p.paidAt ?? p.createdAt : p.createdAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HomeCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.number, style: heading(size: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(20)),
              child: Text(p.status.label,
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(formatInr(p.amount),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text(
              date == null
                  ? ''
                  : '${p.status == PayoutStatus.paid ? 'Paid' : 'Requested'} ${formatDateTime(date)}',
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          if (p.utr != null) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: p.utr!));
                if (context.mounted) {
                  showAppToast(context, 'Bank reference copied.');
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FC),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(PhosphorIconsRegular.bank,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Bank ref (UTR): ${p.utr}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600))),
                  const Icon(PhosphorIconsRegular.copy,
                      size: 16, color: AppColors.textMuted),
                ]),
              ),
            ),
          ] else if (p.status == PayoutStatus.processing ||
              p.status == PayoutStatus.pending) ...[
            const SizedBox(height: 8),
            const Text('Bank reference appears here once the transfer is sent.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ],
        ]),
      ),
    );
  }
}
