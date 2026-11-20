import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';

/// Step 2 — name, schedule and budget.
class DetailsStep extends ConsumerWidget {
  const DetailsStep({super.key, required this.rules});
  final AdRules rules;

  Future<DateTime?> _pick(BuildContext context, DateTime initial,
      {required DateTime first}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(campaignDraftProvider);
    final n = ref.read(campaignDraftProvider.notifier);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = d.startsOn ?? today;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const FieldLabel('Campaign name'),
        AuctionField(
          initial: d.name,
          hint: 'e.g. iPhone 15 — Diwali push',
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          onChanged: n.name,
        ),
        const SizedBox(height: 4),
        const Text('Only you can see this name.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Start date'),
              PickerField(
                value: formatDay(start),
                icon: PhosphorIconsRegular.calendarBlank,
                onTap: () async {
                  final p = await _pick(context, start, first: today);
                  if (p != null) {
                    n.starts(p);
                    if (d.endsOn != null && d.endsOn!.isBefore(p)) n.ends(null);
                  }
                },
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('End date', optional: true),
              PickerField(
                value: d.endsOn == null ? null : formatDay(d.endsOn),
                hint: 'No end date',
                icon: PhosphorIconsRegular.calendarCheck,
                onTap: () async {
                  final p =
                      await _pick(context, d.endsOn ?? start, first: start);
                  if (p != null) n.ends(p);
                },
              ),
            ]),
          ),
        ]),
        if (d.endsOn != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: () => n.ends(null),
                child: const Text('Remove end date')),
          ),
        const SizedBox(height: 12),
        const FieldLabel('Daily budget'),
        AuctionField(
          initial: d.dailyBudget,
          prefix: '₹',
          number: true,
          hint: 'Minimum ₹${_n(rules.minDailyBudget)}',
          onChanged: n.daily,
        ),
        const SizedBox(height: 6),
        const Text(
            'The most this campaign will spend in one day. It stops for the day when the budget is used.',
            style: TextStyle(
                fontSize: 12, height: 1.35, color: AppColors.textMuted)),
        const SizedBox(height: 16),
        const FieldLabel('Total budget', optional: true),
        AuctionField(
          initial: d.totalBudget,
          prefix: '₹',
          number: true,
          hint: 'No overall limit',
          onChanged: n.total,
        ),
        const SizedBox(height: 14),
        AdNotice(
          title: '${_n(rules.gstPct)}% GST is added to every click',
          message:
              'Your daily budget is the amount before GST. Money comes from your ad wallet.',
          icon: PhosphorIconsFill.receipt,
          color: const Color(0xFFB45309),
          bg: AppColors.amberSoft,
        ),
      ],
    );
  }
}

String _n(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
