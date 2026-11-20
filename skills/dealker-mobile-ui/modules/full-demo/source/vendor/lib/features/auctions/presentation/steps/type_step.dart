import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';

/// Step 1 — who may see and bid on this auction.
class TypeStep extends ConsumerWidget {
  const TypeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audience = ref.watch(createDraftProvider.select((d) => d.audience));
    final n = ref.read(createDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const HeroBanner(
          title: 'Start an auction',
          subtitle: 'Let buyers compete for your stock. Pick who can see and bid first.',
          art: 'assets/3d/profile/gavel.png',
          colors: [Color(0xFF6A4DF0), Color(0xFF3B26B8)],
        ),
        const SizedBox(height: 20),
        Text('Select Auction Type', style: heading(size: 17)),
        const SizedBox(height: 12),
        ArtOptionCard(
          art: 'assets/3d/new/cartons.png',
          title: AuctionAudience.b2b.short,
          subtitle: '${AuctionAudience.b2b.title} (${AuctionAudience.b2b.subtitle})',
          accent: AppColors.roleB2b,
          selected: audience == AuctionAudience.b2b,
          bullets: const [
            'Visible only to verified Dealkr vendors',
            'Sell a lot of many units in one auction',
            'Bids are for the whole lot',
          ],
          onTap: () => n.setAudience(AuctionAudience.b2b),
        ),
        const SizedBox(height: 14),
        ArtOptionCard(
          art: 'assets/3d/exchange/phone.png',
          title: AuctionAudience.b2c.short,
          subtitle: '${AuctionAudience.b2c.title} (${AuctionAudience.b2c.subtitle})',
          accent: AppColors.roleB2c,
          selected: audience == AuctionAudience.b2c,
          bullets: const [
            'Shown to customers in the Dealkr app',
            'One unit per auction',
            'Customers register and bid in real time',
          ],
          onTap: () => n.setAudience(AuctionAudience.b2c),
        ),
      ],
    );
  }
}
