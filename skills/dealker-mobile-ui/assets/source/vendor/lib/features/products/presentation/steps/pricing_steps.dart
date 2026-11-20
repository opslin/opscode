import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_draft.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';

/// Step 6 — B2B (wholesale) terms.
class B2bStep extends ConsumerWidget {
  const B2bStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);
    final w = d.wholesaleN;
    final m = d.moqN;
    final eff =
        (w != null && d.discount > 0) ? w * (100 - d.discount) / 100 : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        if (d.sellB2c && d.sellB2b)
          ChannelTabs(
              b2bSelected: true, onB2b: () {}, onB2c: () => n.go(AddStep.b2c)),
        if (d.sellB2c && d.sellB2b) const SizedBox(height: 18),
        Text('Wholesale terms', style: heading(size: 19)),
        const SizedBox(height: 4),
        const Text('What other vendors pay when they buy this product in bulk.',
            style: TextStyle(
                fontSize: 13.5, height: 1.35, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        const FieldLabel('Wholesale price (per unit)'),
        AuctionField(
          initial: d.wholesale,
          number: true,
          maxLength: 9,
          prefix: '₹',
          hint: '0',
          onChanged: (v) => n.set((x) => x.copyWith(wholesale: v)),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Minimum order quantity (MOQ)'),
        AuctionField(
          initial: d.moq,
          number: true,
          maxLength: 5,
          hint: '1',
          suffix: const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Align(
                widthFactor: 1,
                child: Text('units',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.textMuted))),
          ),
          onChanged: (v) => n.set((x) => x.copyWith(moq: v)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              d.singleUnit
                  ? 'Smallest order a buyer can place.'
                  : 'You have ${d.stock} units in stock. MOQ can’t be more than that.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Business discount'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in kDiscountChoices)
            _ChoicePill(
              label: p == 0 ? 'None' : '$p%',
              selected: d.discount == p,
              onTap: () => n.set((x) => x.copyWith(discount: p)),
            ),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Extra discount you offer buyers who order MOQ or more.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 18),
        const FieldLabel('B2B notes', optional: true),
        AuctionField(
          initial: d.b2bNotes,
          maxLines: 3,
          maxLength: 500,
          hint: 'e.g. Bulk orders available with extra discount.',
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => n.set((x) => x.copyWith(b2bNotes: v)),
        ),
        if (w != null && w > 0 && m != null && m > 0) ...[
          const SizedBox(height: 18),
          SectionCard(
            color: AppColors.roleB2bBg.withValues(alpha: 0.5),
            border: AppColors.roleB2b.withValues(alpha: 0.25),
            child: Column(children: [
              SummaryRow('Wholesale price', '${formatInr(w)} / unit'),
              SummaryRow('Minimum order', '$m ${m == 1 ? 'unit' : 'units'}'),
              SummaryRow('Smallest order value', formatInr(w * m)),
              if (eff != null)
                SummaryRow(
                    'With ${d.discount}% discount', '${formatInr(eff)} / unit',
                    valueColor: AppColors.mint),
            ]),
          ),
        ],
      ],
    );
  }
}

/// Step 7 — B2C (customer) price and policies.
class B2cStep extends ConsumerWidget {
  const B2cStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);
    final p = d.priceN;
    final mrp = d.mrpN;
    final off = discountLabel(p, mrp);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        if (d.sellB2c && d.sellB2b)
          ChannelTabs(
              b2bSelected: false, onB2b: () => n.go(AddStep.b2b), onB2c: () {}),
        if (d.sellB2c && d.sellB2b) const SizedBox(height: 18),
        Text('Customer price', style: heading(size: 19)),
        const SizedBox(height: 4),
        const Text('What customers pay in the Dealkr app.',
            style: TextStyle(
                fontSize: 13.5, height: 1.35, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        const FieldLabel('Selling price'),
        AuctionField(
          initial: d.price,
          number: true,
          maxLength: 9,
          prefix: '₹',
          hint: '0',
          onChanged: (v) => n.set((x) => x.copyWith(price: v)),
        ),
        const SizedBox(height: 14),
        const FieldLabel('MRP / original price', optional: true),
        AuctionField(
          initial: d.mrp,
          number: true,
          maxLength: 9,
          prefix: '₹',
          hint: '0',
          onChanged: (v) => n.set((x) => x.copyWith(mrp: v)),
        ),
        if (p != null && p > 0) ...[
          const SizedBox(height: 14),
          SectionCard(
            color: const Color(0xFFF7F9FE),
            child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text(formatInr(p), style: heading(size: 24)),
                  if (mrp != null && mrp > p) ...[
                    Text(formatInr(mrp),
                        style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.mintSoft,
                          borderRadius: BorderRadius.circular(7)),
                      child: Text(off,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mint)),
                    ),
                  ],
                ]),
          ),
        ],
        const SizedBox(height: 18),
        const FieldLabel('Warranty'),
        PickerField(
          value: d.warranty,
          icon: PhosphorIconsRegular.shieldCheck,
          onTap: () async {
            final v = await pickOption(context,
                title: 'Warranty',
                options: kWarrantyOptions,
                selected: d.warranty);
            if (v != null) n.set((x) => x.copyWith(warranty: v));
          },
        ),
        const SizedBox(height: 18),
        const FieldLabel('Return window'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in kReturnDayChoices)
            _ChoicePill(
              label: r == 0 ? 'No returns' : '$r days',
              selected: d.returnDays == r,
              onTap: () => n.set((x) => x.copyWith(returnDays: r)),
            ),
        ]),
        if (d.sellB2b &&
            d.wholesaleN != null &&
            p != null &&
            d.wholesaleN! > p) ...[
          const SizedBox(height: 16),
          NoteBanner.warning(
              'Your wholesale price (${formatInr(d.wholesaleN!)}) is higher than this selling price. Lower the wholesale price or raise this one.'),
        ],
      ],
    );
  }
}

/// B2B | B2C switch shown on both pricing steps when the product sells on both.
class ChannelTabs extends StatelessWidget {
  const ChannelTabs(
      {super.key,
      required this.b2bSelected,
      required this.onB2b,
      required this.onB2c});
  final bool b2bSelected;
  final VoidCallback onB2b;
  final VoidCallback onB2c;

  @override
  Widget build(BuildContext context) {
    Widget tab(String top, String sub, bool sel, VoidCallback tap) => Expanded(
          child: GestureDetector(
            onTap: tap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 58,
              decoration: BoxDecoration(
                color: sel ? kBlue : Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(top,
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: sel ? Colors.white : AppColors.navy)),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: sel ? Colors.white70 : AppColors.textMuted)),
                  ]),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFEFF3FB),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        tab('B2B', 'Business to Business', b2bSelected, onB2b),
        const SizedBox(width: 4),
        tab('B2C', 'Customer', !b2bSelected, onB2c),
      ]),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: selected ? kBlueSoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? kBlue : AppColors.border,
                width: selected ? 1.8 : 1.2),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? kBlue : AppColors.textSecondary)),
          ),
        ),
      );
}
