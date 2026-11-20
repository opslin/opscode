import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Step 5 — everything in one place before it is sent.
class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key, required this.rules});
  final AdRules rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(campaignDraftProvider);
    final wallet = ref.watch(adWalletProvider).asData?.value;
    final lowFunds = wallet != null &&
        d.dailyN != null &&
        wallet.balance < d.dailyN! * (1 + rules.gstPct / 100);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        HomeCard(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(d.name.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: heading(size: 18))),
              const SizedBox(width: 8),
              TargetingChip(d.targeting),
            ]),
            const Divider(height: 24),
            SummaryRow('Runs', dateRange(d.startsOn, d.endsOn)),
            if (d.runDays != null) SummaryRow('Duration', '${d.runDays} days'),
            SummaryRow('Daily budget', formatInr(d.dailyN ?? 0)),
            SummaryRow('Total budget',
                d.totalN == null ? 'No overall limit' : formatInr(d.totalN!)),
            SummaryRow('Max cost per click', inr2(d.bidN ?? 0)),
            SummaryRow('Products', '${d.products.length}'),
            if (d.isManual) SummaryRow('Keywords', '${d.positive.length}'),
          ]),
        ),
        const SizedBox(height: 14),
        HomeCard(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            for (final (i, p) in d.products.take(4).indexed)
              Padding(
                padding: EdgeInsets.only(
                    bottom:
                        i == (d.products.length > 4 ? 3 : d.products.length - 1)
                            ? 0
                            : 10),
                child: Row(children: [
                  ProductThumb(p.thumbnail, size: 44, radius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600))),
                ]),
              ),
            if (d.products.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('+ ${d.products.length - 4} more',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        AdNotice(
          title: rules.requiresApproval
              ? 'Reviewed before it goes live'
              : 'Goes live right away',
          message: rules.requiresApproval
              ? 'Dealkr checks every campaign first. You will see it as “In review” until it is approved.'
              : 'Your ads start on the start date as long as your ad wallet has money.',
          icon: rules.requiresApproval
              ? PhosphorIconsFill.shieldCheck
              : PhosphorIconsFill.rocketLaunch,
          color:
              rules.requiresApproval ? const Color(0xFFB45309) : AppColors.mint,
          bg: rules.requiresApproval ? AppColors.amberSoft : AppColors.mintSoft,
        ),
        if (lowFunds) ...[
          const SizedBox(height: 12),
          AdNotice(
            title: 'Add money to your ad wallet',
            message:
                'Your balance is ${formatInr(wallet.balance)}. Ads only run while the wallet has money, so top it up before the start date.',
            icon: PhosphorIconsFill.wallet,
            color: AppColors.rose,
            bg: AppColors.roseSoft,
            action: TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              onPressed: () => context.push(Routes.adWallet),
              child: const Text('Open ad wallet'),
            ),
          ),
        ],
      ],
    );
  }
}
