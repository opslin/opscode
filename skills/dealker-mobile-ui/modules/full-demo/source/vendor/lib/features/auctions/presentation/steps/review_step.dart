import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/application/create_draft.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/steps/settings_step.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';

/// Step 6 — read-only summary before publishing.
class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key, required this.rules, required this.busy});
  final AuctionRules rules;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(createDraftProvider);
    final n = ref.read(createDraftProvider.notifier);
    final p = d.product!;
    final cover = d.images.isNotEmpty ? d.images.first : p.thumbnail;

    String startText() => d.startNow
        ? (rules.requiresApproval ? 'After approval' : 'Immediately')
        : formatDateTime(d.startsAt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Review & Publish', style: heading(size: 20)),
        const SizedBox(height: 14),
        HomeCard(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              ProductThumb(cover, size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                      const SizedBox(height: 4),
                      AudienceChip(d.audience),
                    ]),
              ),
              IconButton(
                  onPressed: () => n.go(CreateStep.details),
                  icon: const Icon(PhosphorIconsRegular.pencilSimple,
                      size: 20, color: kAuctionBlue)),
            ]),
            const Divider(height: 22, color: AppColors.cardBorder),
            SummaryRow('Auction type', d.audience.short),
            if (d.isB2b) SummaryRow('Lot size', unitsLabel(d.quantityN ?? 1)),
            SummaryRow('Starting price', formatInr(d.startPriceN ?? 0)),
            SummaryRow('Reserve price',
                d.reserveN == null ? 'None' : formatInr(d.reserveN!)),
            if (d.buyNowN != null)
              SummaryRow('Buy-now price', formatInr(d.buyNowN!)),
            SummaryRow('Duration', durationLabel(d.durationHours)),
            SummaryRow('Start', startText()),
            SummaryRow(
                'Bid increment',
                d.bidIncrement == null
                    ? 'Automatic'
                    : formatInr(d.bidIncrement!)),
            SummaryRow('Registration fee', formatInr(d.feeN ?? 0)),
          ]),
        ),
        const SizedBox(height: 14),
        HomeCard(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('Media',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.navy))),
              GestureDetector(
                onTap: () => n.go(CreateStep.media),
                child: const Text('Edit',
                    style: TextStyle(
                        color: kAuctionBlue, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            if (d.images.isEmpty)
              const Text('Using the product’s listing photos.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted))
            else
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: d.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) =>
                      SizedBox(width: 56, child: MediaTile(d.images[i])),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _Pill(PhosphorIconsRegular.videoCamera,
                  d.videoUrl != null ? 'Video added' : 'No video',
                  on: d.videoUrl != null),
              _Pill(
                  PhosphorIconsRegular.sealCheck,
                  d.hasQc
                      ? 'QC report · ${d.qcChecks.values.where((v) => v).length} checks'
                      : 'No QC report',
                  on: d.hasQc),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => showTermsSheet(context, rules),
          child: HomeCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(PhosphorIconsRegular.fileText,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Terms & Conditions',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.navy))),
              const Text('View',
                  style: TextStyle(
                      color: kAuctionBlue, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        if (rules.requiresApproval) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(12)),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(PhosphorIconsFill.info,
                      size: 18, color: Color(0xFFB45309)),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Dealkr reviews new auctions first. Yours will go live as soon as it is approved.',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF7A4A07)))),
                ]),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label, {required this.on});
  final IconData icon;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: on ? kAuctionBlueSoft : const Color(0xFFF1F4FB),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: on ? kAuctionBlue : AppColors.textMuted),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: on ? kAuctionBlue : AppColors.textMuted)),
        ]),
      );
}
