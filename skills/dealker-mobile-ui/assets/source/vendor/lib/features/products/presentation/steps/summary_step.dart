import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_draft.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';

/// Step 8 — everything in one place before it goes for approval.
class SummaryStep extends ConsumerWidget {
  const SummaryStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);
    final checklist = {
      for (final i in checklistFor(d.type))
        i.label: d.checklist[i.label] ?? i.best
    };
    final good =
        checklistFor(d.type).where((i) => checklist[i.label] == i.best).length;
    final total = checklistFor(d.type).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        SectionCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnyImage(d.images.isEmpty ? null : d.images.first,
                size: 78, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: heading(size: 16)),
                    const SizedBox(height: 3),
                    Text('${d.brand} · ${d.condition.label}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    ChannelChips(b2b: d.sellB2b, b2c: d.sellB2c),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Head('Pricing',
                onEdit: () => n.go(d.sellB2c ? AddStep.b2c : AddStep.b2b)),
            if (d.sellB2c) ...[
              Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(formatInr(d.priceN ?? 0), style: heading(size: 22)),
                    if (d.mrpN != null && d.mrpN! > (d.priceN ?? 0)) ...[
                      Text(formatInr(d.mrpN!),
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough)),
                      Text('${d.discountPct}% OFF',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mint)),
                    ],
                    const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text('B2C',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted))),
                  ]),
              if (d.sellB2b) const SizedBox(height: 10),
            ],
            if (d.sellB2b)
              Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(formatInr(d.wholesaleN ?? 0),
                        style: heading(size: d.sellB2c ? 17 : 22)),
                    Text('wholesale · MOQ ${d.moqN ?? 1}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    if (d.discount > 0)
                      Text('${d.discount}% business discount',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mint,
                              fontWeight: FontWeight.w700)),
                  ]),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.cardBorder),
            SummaryRow('Units in stock', '${d.stock}'),
            if (d.usage.isNotEmpty && d.condition != ProductCondition.newItem)
              SummaryRow('Usage', d.usage),
            if (d.batteryN != null && d.condition != ProductCondition.newItem)
              SummaryRow('Battery health', '${d.batteryN}%'),
            if (d.inBox.isNotEmpty)
              SummaryRow('In the box', d.inBox.join(', ')),
            if (d.sellB2c) SummaryRow('Warranty', d.warranty),
            if (d.sellB2c)
              SummaryRow('Returns',
                  d.returnDays == 0 ? 'No returns' : '${d.returnDays} days'),
          ]),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Head('Media', onEdit: () => n.go(AddStep.media)),
            SizedBox(
              height: 62,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final u in d.images)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnyImage(u, size: 62, radius: 10)),
                if (d.hasVideo)
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(PhosphorIconsFill.play,
                        color: Colors.white, size: 24),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Head('Your quality check', onEdit: () => n.go(AddStep.checklist)),
            _QcLine('Physical check', '$good of $total perfect',
                ok: good == total),
            _QcLine('Photo QC',
                '${d.taggedAngles} sides · ${d.scratchChoice == true ? 'no scratches' : 'has marks'}',
                ok: d.frontBackTagged),
            _QcLine('Video QC', d.hasVideo ? 'Video added' : 'No video',
                ok: d.hasVideo, neutral: !d.hasVideo),
          ]),
        ),
        const SizedBox(height: 14),
        const NoteBanner(
            'Dealkr reviews every new product before it goes live. You’ll see its status in My Products — usually within 24 hours.',
            icon: PhosphorIconsFill.shieldCheck),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.title, {required this.onEdit});
  final String title;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(title, style: heading(size: 15.5))),
          GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('Edit',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kBlue)),
            ),
          ),
        ]),
      );
}

class _QcLine extends StatelessWidget {
  const _QcLine(this.label, this.value,
      {required this.ok, this.neutral = false});
  final String label;
  final String value;
  final bool ok;
  final bool neutral;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(
              neutral
                  ? PhosphorIconsRegular.minusCircle
                  : (ok
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsFill.warningCircle),
              size: 20,
              color: neutral
                  ? AppColors.textMuted
                  : (ok ? AppColors.mint : const Color(0xFFB45309))),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ),
        ]),
      );
}
