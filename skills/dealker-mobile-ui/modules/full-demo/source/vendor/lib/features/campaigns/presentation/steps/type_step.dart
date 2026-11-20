import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';

/// Step 1 — how shoppers will find the ad.
class TypeStep extends ConsumerWidget {
  const TypeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(campaignDraftProvider);
    final n = ref.read(campaignDraftProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const HeroBanner(
          title: 'Promote your products',
          subtitle:
              'Sponsored ads sit at the top of search in the Dealkr customer app. You pay only when a shopper taps your ad.',
          art: 'assets/3d/new/megaphone.png',
          colors: [Color(0xFF3A63F0), Color(0xFF2038B8)],
        ),
        const SizedBox(height: 20),
        Text('Choose how shoppers find you', style: heading(size: 16)),
        const SizedBox(height: 12),
        ArtOptionCard(
          art: A3.sell('hero'),
          title: 'Automatic',
          badge: 'Easiest',
          subtitle:
              'Dealkr matches your products to shoppers searching for similar items. Nothing else to set up.',
          selected: d.targeting == Targeting.auto,
          onTap: () => n.targeting(Targeting.auto),
        ),
        const SizedBox(height: 12),
        ArtOptionCard(
          art: A3.sell('check'),
          title: 'Keywords',
          badge: 'More control',
          subtitle:
              'You choose the exact words shoppers search for, and words to avoid. Best when you know your buyers.',
          selected: d.targeting == Targeting.manual,
          onTap: () => n.targeting(Targeting.manual),
        ),
        const SizedBox(height: 18),
        const AdNotice(
          title: 'Shown to customers',
          message:
              'Ads appear in the customer app only. Wholesale (B2B) listings are never advertised to shoppers.',
          icon: PhosphorIconsFill.storefront,
        ),
      ],
    );
  }
}
