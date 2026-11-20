import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/deals/application/deal_providers.dart';
import 'package:dealker_vendor/features/deals/data/deal_models.dart';
import 'package:dealker_vendor/routing/route_names.dart';

String tierLabel(String t) => switch (t) {
      'PAID' => 'Paid plan or higher',
      'PREMIUM' => 'Premium plan or higher',
      'UNLIMITED' => 'Unlimited plan',
      _ => 'Open to all vendors',
    };

/// Deals the platform opened to vendors: put your products in, get approved, sell at the deal price.
class DealsScreen extends ConsumerWidget {
  const DealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(openDealsProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AuctionAppBar(title: 'Deals', subtitle: 'Join platform sales with your products'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(openDealsProvider);
          await ref.read(openDealsProvider.future).catchError((_) => <OpenDeal>[]);
        },
        child: deals.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
              message: errorText(e, 'Could not load deals.'),
              onRetry: () => ref.invalidate(openDealsProvider)),
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                        'No open deals right now.\nWhen Dealkr runs a sale you can join, it shows up here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.4)),
                  )),
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [for (final d in list) _DealCard(d)],
                ),
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard(this.deal);
  final OpenDeal deal;

  @override
  Widget build(BuildContext context) {
    final live = deal.status == 'ACTIVE';
    return GestureDetector(
      onTap: () => context.push(Routes.dealView(deal.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(deal.name,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
            if (deal.discountPercent != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.roseSoft, borderRadius: BorderRadius.circular(99)),
                child: Text('${deal.discountPercent!.toStringAsFixed(deal.discountPercent! % 1 == 0 ? 0 : 1)}% OFF',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.rose)),
              ),
          ]),
          const SizedBox(height: 6),
          Text('${formatDateTime(deal.startsAt)}  →  ${formatDateTime(deal.endsAt)}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(tierLabel(deal.minTier), style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          if (deal.entryDeadline != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Join before ${formatDateTime(deal.entryDeadline)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ),
          const SizedBox(height: 12),
          Row(children: [
            _Chip(live ? 'Live now' : 'Open for entries', live ? AppColors.mintSoft : AppColors.violetSoft,
                live ? AppColors.mint : AppColors.violet),
            const SizedBox(width: 8),
            if (deal.myEntries > 0)
              _Chip('${deal.myEntries} of yours · ${deal.myApproved} approved', AppColors.amberSoft, const Color(0xFF8A5A00)),
            const Spacer(),
            Text(deal.canJoin ? 'View →' : 'Not available',
                style: TextStyle(fontWeight: FontWeight.w800, color: deal.canJoin ? AppColors.violet : AppColors.textMuted)),
          ]),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
      );
}
