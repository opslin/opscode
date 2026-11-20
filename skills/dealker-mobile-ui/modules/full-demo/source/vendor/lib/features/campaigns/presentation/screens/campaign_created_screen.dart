import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Shown right after a campaign is created — says exactly what happens next.
class CampaignCreatedScreen extends StatelessWidget {
  const CampaignCreatedScreen({super.key, required this.campaign});
  final CampaignDetail campaign;

  @override
  Widget build(BuildContext context) {
    final c = campaign.item;
    final (title, body, icon, color, bg) = switch (c.status) {
      CampaignStatus.active => (
          'Campaign is live!',
          'Your ads can now appear to shoppers. Keep your ad wallet topped up so they keep running.',
          PhosphorIconsFill.rocketLaunch,
          AppColors.mint,
          AppColors.mintSoft
        ),
      CampaignStatus.pending => (
          'Submitted for approval',
          'Dealkr will review your campaign. Once approved it goes live on its start date — we will show it as “Live” here.',
          PhosphorIconsFill.hourglass,
          const Color(0xFFB45309),
          AppColors.amberSoft
        ),
      _ => (
          'Saved as draft',
          'Your campaign is saved. Open it any time to submit it for approval.',
          PhosphorIconsFill.floppyDisk,
          kAdBlue,
          kAdBlueSoft
        ),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
              children: [
                Center(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration:
                        BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Icon(icon, size: 50, color: color),
                  ),
                ),
                const SizedBox(height: 22),
                Text(title,
                    textAlign: TextAlign.center, style: heading(size: 26)),
                const SizedBox(height: 10),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                HomeCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Text(c.name, style: heading(size: 16))),
                      CampaignStatusPill(c.status),
                    ]),
                    const Divider(height: 22),
                    SummaryRow('Campaign ID', c.number),
                    SummaryRow('Runs', dateRange(c.startsOn, c.endsOn)),
                    SummaryRow('Daily budget', formatInr(c.dailyBudget)),
                    SummaryRow('Max cost per click', inr2(c.defaultBid)),
                    SummaryRow('Products', '${c.productCount}'),
                  ]),
                ),
              ],
            ),
          ),
          BottomActionBar(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AuctionButton(
                  label: 'View campaign',
                  trailing: PhosphorIconsBold.arrowRight,
                  onPressed: () {
                    context.go(Routes.campaigns);
                    context.push(Routes.campaignDetail(c.id));
                  }),
              const SizedBox(height: 8),
              AuctionButton(
                  label: 'Back to campaigns',
                  outlined: true,
                  onPressed: () => context.go(Routes.campaigns)),
            ]),
          ),
        ]),
      ),
    );
  }
}
