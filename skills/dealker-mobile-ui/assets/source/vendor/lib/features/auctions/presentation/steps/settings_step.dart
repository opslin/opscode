import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/application/create_draft.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';

/// Step 4 — audience, bid increment, duration, registration fee, terms.
class SettingsStep extends ConsumerWidget {
  const SettingsStep({super.key, required this.rules});
  final AuctionRules rules;

  Future<T?> _sheet<T>(BuildContext context, String title,
      List<(String, T)> options, T? current) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: heading(size: 18))),
            const SizedBox(height: 8),
            for (final (label, value) in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.navy)),
                trailing: value == current
                    ? const Icon(PhosphorIconsFill.checkCircle,
                        color: kAuctionBlue)
                    : null,
                onTap: () => Navigator.pop(c, value),
              ),
          ]),
        ),
      ),
    );
  }

  List<int> get _durations => durationChoices
      .where((h) =>
          h * 60 >= rules.minDurationMinutes && h <= rules.maxDurationDays * 24)
      .toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(createDraftProvider);
    final n = ref.read(createDraftProvider.notifier);
    final maxFee = rules.maxFeeFor(d.startPriceN ?? 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Auction Settings', style: heading(size: 20)),
        const SizedBox(height: 16),
        const FieldLabel('Target Audience'),
        Segmented(
          labels: const ['B2B', 'B2C'],
          index: d.isB2b ? 0 : 1,
          onChanged: (i) =>
              n.setAudience(i == 0 ? AuctionAudience.b2b : AuctionAudience.b2c),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              d.isB2b
                  ? 'Only verified vendors can see and bid.'
                  : 'Customers in the Dealkr app can see and bid.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Bid Increment'),
        PickerField(
          value: d.bidIncrement == null
              ? 'Automatic (recommended)'
              : formatInr(d.bidIncrement!),
          onTap: () async {
            // 0 = automatic; a dismissed sheet returns null and changes nothing.
            final r = await _sheet<num>(
                context,
                'Bid increment',
                [
                  ('Automatic (recommended)', 0),
                  for (final v in incrementChoices) (formatInr(v), v),
                ],
                d.bidIncrement ?? 0);
            if (r != null) n.setIncrement(r == 0 ? null : r);
          },
        ),
        const SizedBox(height: 14),
        const FieldLabel('Duration'),
        PickerField(
          value: durationLabel(d.durationHours),
          onTap: () async {
            final r = await _sheet<int>(
                context,
                'Duration',
                [for (final h in _durations) (durationLabel(h), h)],
                d.durationHours);
            if (r != null) n.setDuration(r);
          },
        ),
        const SizedBox(height: 14),
        const FieldLabel('Registration Fee'),
        AuctionField(
            initial: d.registrationFee,
            number: true,
            maxLength: 6,
            prefix: '₹',
            hint: '${rules.minFee.toInt()}',
            onChanged: (v) => n.set(registrationFee: v)),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              'Each bidder pays this to join. Allowed: ${formatInr(rules.minFee)} – ${formatInr(maxFee < rules.minFee ? rules.minFee : maxFee)}. The winner gets it deducted from their price.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted, height: 1.35)),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Buy-now Price', optional: true),
        AuctionField(
            initial: d.buyNowPrice,
            number: true,
            maxLength: 9,
            prefix: '₹',
            hint: '0',
            onChanged: (v) => n.set(buyNowPrice: v)),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Offered only until the first bid is placed.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => showTermsSheet(context, rules),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.2)),
            child: Row(children: [
              const Icon(PhosphorIconsRegular.fileText,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Terms & Conditions',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy))),
              const Icon(PhosphorIconsRegular.caretRight,
                  size: 18, color: AppColors.textSecondary),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Plain-language rules drawn from the platform's live settings.
void showTermsSheet(BuildContext context, AuctionRules r) {
  final lines = <(IconData, String)>[
    if (r.requiresApproval)
      (
        PhosphorIconsRegular.seal,
        'Your auction goes live after Dealkr approves it.'
      ),
    (
      PhosphorIconsRegular.timer,
      'A bid in the last ${r.antiSnipeWindowSec ~/ 60} min extends the auction by ${r.antiSnipeExtendSec ~/ 60} min, so nobody can snipe at the last second.'
    ),
    (
      PhosphorIconsRegular.coins,
      'Bidders pay the registration fee to join. The winner pays the final price minus that fee.'
    ),
    if (r.vendorSharePct > 0)
      (
        PhosphorIconsRegular.handCoins,
        'You receive ${r.vendorSharePct.toInt()}% of fees forfeited by bidders who do not win.'
      ),
    (
      PhosphorIconsRegular.arrowCounterClockwise,
      'If the reserve is not met or you cancel, every bidder’s fee is refunded in full.'
    ),
    (
      PhosphorIconsRegular.hourglass,
      'The winner has ${r.paymentWindowHours} hours to pay. If they miss it, the next bidder is offered the lot.'
    ),
    (
      PhosphorIconsRegular.prohibit,
      'You can cancel before it starts, or while live if nobody has bid yet.'
    ),
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('Terms & Conditions', style: heading(size: 19))),
          const SizedBox(height: 14),
          for (final (icon, text) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: kAuctionBlueSoft,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: kAuctionBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(text,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: AppColors.textSecondary))),
              ]),
            ),
          const SizedBox(height: 4),
          AuctionButton(label: 'Got it', onPressed: () => Navigator.pop(c)),
        ]),
      ),
    ),
  );
}
