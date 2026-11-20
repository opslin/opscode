import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';

/// Step 3 — title, prices, lot size and when the auction starts.
class DetailsStep extends ConsumerWidget {
  const DetailsStep({super.key});

  Future<void> _pickStart(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final cur = ref.read(createDraftProvider).startsAt ??
        now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: cur.isBefore(now) ? now : cur,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(cur));
    if (time == null) return;
    ref.read(createDraftProvider.notifier).setStart(
        now: false,
        at: DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(createDraftProvider);
    final n = ref.read(createDraftProvider.notifier);
    final p = d.product!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFFF6F8FE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder)),
          child: Row(children: [
            ProductThumb(
                p.thumbnail ?? (p.images.isEmpty ? null : p.images.first),
                size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Row(children: [
                      AudienceChip(d.audience),
                      const SizedBox(width: 8),
                      Text('${p.stock} in stock',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted)),
                    ]),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Text('Auction Details', style: heading(size: 17)),
        const SizedBox(height: 12),
        const FieldLabel('Auction Title'),
        AuctionField(
            initial: d.title,
            maxLength: 200,
            hint: 'e.g. iPhone 15 Pro Max – Live Auction',
            onChanged: (v) => n.set(title: v)),
        const SizedBox(height: 14),
        if (d.isB2b) ...[
          const FieldLabel('Lot Size (units)'),
          AuctionField(
              initial: d.quantity,
              number: true,
              maxLength: 6,
              hint: 'Units in this lot',
              onChanged: (v) => n.set(quantity: v)),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
                'Bids and the final price are for the whole lot. Per-unit price is shown to bidders.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMuted, height: 1.35)),
          ),
          const SizedBox(height: 14),
        ],
        FieldLabel(d.isB2b ? 'Starting Price (whole lot)' : 'Starting Price'),
        AuctionField(
            initial: d.startPrice,
            number: true,
            maxLength: 9,
            prefix: '₹',
            hint: '0',
            onChanged: (v) => n.set(startPrice: v)),
        const SizedBox(height: 14),
        const FieldLabel('Reserve Price', optional: true),
        AuctionField(
            initial: d.reservePrice,
            number: true,
            maxLength: 9,
            prefix: '₹',
            hint: '0',
            onChanged: (v) => n.set(reservePrice: v)),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
              'Hidden from bidders — they only see “Reserve met”. If bidding stays below it, the auction ends unsold and all fees are refunded.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textMuted, height: 1.35)),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Start'),
        Segmented(
          labels: const ['Start now', 'Schedule'],
          index: d.startNow ? 0 : 1,
          onChanged: (i) =>
              i == 0 ? n.setStart(now: true) : _pickStart(context, ref),
        ),
        if (!d.startNow) ...[
          const SizedBox(height: 10),
          PickerField(
            icon: PhosphorIconsRegular.calendarBlank,
            value: formatDateTime(d.startsAt),
            onTap: () => _pickStart(context, ref),
          ),
        ],
      ],
    );
  }
}
