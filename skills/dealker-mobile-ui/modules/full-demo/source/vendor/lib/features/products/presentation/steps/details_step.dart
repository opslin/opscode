import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/device_catalogue.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';

/// Step 1 — where to sell (B2B / B2C), product type and the basic details.
class DetailsStep extends ConsumerWidget {
  const DetailsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(addDraftProvider);
    final n = ref.read(addDraftProvider.notifier);
    final readiness = ref.watch(readinessProvider).asData?.value;
    final fk = '${d.type.key}-${d.brand}';
    final types = ref.watch(productTypesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        if (readiness != null) ...[
          ReadinessBanner(readiness),
          const SizedBox(height: 16),
        ],
        const HeroBanner(
          title: 'List a product',
          subtitle:
              'Add it once and sell to vendors in wholesale, to customers in retail, or both.',
          art: 'assets/3d/new/addbox.png',
          colors: [Color(0xFF3A63F0), Color(0xFF2038B8)],
          artSize: 104,
        ),
        const SizedBox(height: 20),
        Text('Sell this product to', style: heading(size: 17)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ArtChoiceTile(
              art: 'assets/3d/new/cartons.png',
              label: 'B2B',
              sub: 'Wholesale to vendors',
              selected: d.sellB2b,
              accent: AppColors.roleB2b,
              artSize: 58,
              onTap: () => n.setChannel(b2b: !d.sellB2b),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ArtChoiceTile(
              art: A3.shop(2),
              label: 'B2C',
              sub: 'Retail to customers',
              selected: d.sellB2c,
              accent: AppColors.roleB2c,
              artSize: 58,
              onTap: () => n.setChannel(b2c: !d.sellB2c),
            ),
          ),
        ]),
        if (d.sellB2b)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.roleB2c.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.roleB2c
                        .withValues(alpha: d.sellB2c ? 0.5 : 0.2)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Also sell to customers (B2C)  ·  Optional',
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                            d.sellB2c
                                ? 'This product will also show to customers. You will set a retail price next.'
                                : 'Off — only vendors can see this product. Customers will not.',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ]),
                ),
                Switch(
                  key: const Key('also-b2c-switch'),
                  value: d.sellB2c,
                  onChanged: (v) => n.setChannel(b2c: v),
                ),
              ]),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'Choose B2B to sell wholesale to vendors — retail to customers stays optional.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
        const SizedBox(height: 22),
        Text('Select Product Type', style: heading(size: 17)),
        const SizedBox(height: 10),
        // Existing categories only — vendors pick, they cannot add types.
        // Rows of four; the page itself scrolls when the list runs longer.
        for (final row in _rowsOf4(types))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: i < row.length
                      ? _TypeTile(
                          type: row[i],
                          selected: d.type == row[i],
                          onTap: () => n.setType(row[i]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ]),
          ),
        const SizedBox(height: 24),
        Text('Product Details', style: heading(size: 17)),
        const SizedBox(height: 12),
        const FieldLabel('Brand'),
        PickerField(
          value: d.brand.isEmpty ? null : d.brand,
          hint: 'Select brand',
          onTap: () async {
            final v = await pickOption(context,
                title: 'Select brand',
                options: await ref.read(deviceBrandsProvider(d.type).future),
                selected: d.brand,
                allowCustom: true,
                searchable: true);
            if (v != null) n.setBrand(v);
          },
        ),
        const SizedBox(height: 14),
        const FieldLabel('Model'),
        PickerField(
          value: d.model.isEmpty ? null : d.model,
          hint: d.brand.isEmpty ? 'Select a brand first' : 'Select model',
          onTap: () async {
            if (d.brand.isEmpty) {
              showFailureDialog(context, (
                title: 'Select a brand first',
                message: 'Choose the brand, then pick its model.'
              ));
              return;
            }
            final catalogue =
                await ref.read(deviceModelsProvider((d.type, d.brand)).future);
            if (!context.mounted) return;
            final v = await pickOption(context,
                title: 'Select model',
                options: catalogue.map((m) => m.name).toList(),
                selected: d.model,
                allowCustom: true,
                searchable: true);
            if (v != null) n.set((x) => x.copyWith(model: v));
          },
        ),
        if (d.type.hasStorage) ...[
          const SizedBox(height: 14),
          const FieldLabel('Storage'),
          PickerField(
            value: d.storage.isEmpty ? null : d.storage,
            hint: 'Select storage',
            onTap: () async {
              final catalogue = d.brand.isEmpty
                  ? const <DeviceModel>[]
                  : await ref
                      .read(deviceModelsProvider((d.type, d.brand)).future);
              if (!context.mounted) return;
              final v = await pickOption(context,
                  title: 'Select storage',
                  options: storagesFor(catalogue, d.model),
                  selected: d.storage,
                  allowCustom: true,
                  customLabel: 'Other');
              if (v != null) n.set((x) => x.copyWith(storage: v));
            },
          ),
        ],
        const SizedBox(height: 14),
        const FieldLabel('Condition'),
        Row(children: [
          for (final t in _tiers) ...[
            if (t != _tiers.first) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => n.set((x) => x.copyWith(condition: t.defaultCond)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: t.has(d.condition) ? t.color.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: t.has(d.condition) ? t.color : AppColors.cardBorder,
                        width: t.has(d.condition) ? 2 : 1),
                  ),
                  child: Column(children: [
                    Icon(t.icon, color: t.color, size: 22),
                    const SizedBox(height: 6),
                    Text(t.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: t.has(d.condition) ? t.color : AppColors.navy)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
        if (_tiers.firstWhere((t) => t.has(d.condition)).grades.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _tiers.firstWhere((t) => t.has(d.condition)).grades)
              _Pill(
                label: c.label,
                selected: d.condition == c,
                onTap: () => n.set((x) => x.copyWith(condition: c)),
              ),
          ]),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(d.condition.hint,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ),
        if (d.condition.isUsed) ...[
          const SizedBox(height: 14),
          const FieldLabel('Describe the condition'),
          AuctionField(
            fieldKey: ValueKey('notes-$fk'),
            initial: d.conditionNotes,
            maxLines: 3,
            maxLength: 500,
            hint: 'Scratches, dents, usage, battery…',
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => n.set((x) => x.copyWith(conditionNotes: v)),
          ),
        ],
        if (d.condition != ProductCondition.newItem) ...[
          const SizedBox(height: 14),
          const FieldLabel('How long has it been used?', optional: true),
          PickerField(
            value: d.usage.isEmpty ? null : d.usage,
            hint: 'Select usage',
            onTap: () async {
              final v = await pickOption(context,
                  title: 'Usage so far',
                  options: kUsageOptions,
                  selected: d.usage,
                  allowCustom: true,
                  customLabel: 'Other');
              if (v != null) n.set((x) => x.copyWith(usage: v));
            },
          ),
          const SizedBox(height: 14),
          const FieldLabel('Battery health %', optional: true),
          AuctionField(
            fieldKey: ValueKey('battery-${d.type.key}'),
            initial: d.battery,
            number: true,
            maxLength: 3,
            hint: 'e.g. 89 (Settings → Battery)',
            onChanged: (v) => n.set((x) => x.copyWith(battery: v)),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
                'Customers see this on the product page next to the condition.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMuted, height: 1.35)),
          ),
        ],
        const SizedBox(height: 14),
        FieldLabel(d.singleUnit ? 'Quantity' : 'Units available'),
        if (d.singleUnit)
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F6FC),
                borderRadius: BorderRadius.circular(12)),
            child: const Text(
                '1 unit — used phones sold to customers are listed one at a time.',
                style:
                    TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          )
        else
          AuctionField(
            initial: d.quantity,
            number: true,
            maxLength: 6,
            hint: '0',
            onChanged: (v) => n.set((x) => x.copyWith(quantity: v)),
          ),
        if (d.sellB2c && d.type.hasImei) ...[
          const SizedBox(height: 14),
          const FieldLabel('IMEI', optional: true),
          AuctionField(
            fieldKey: ValueKey('imei-${d.type.key}'),
            initial: d.imei,
            number: true,
            maxLength: 15,
            hint: '15-digit IMEI (dial *#06#)',
            onChanged: (v) => n.set((x) => x.copyWith(imei: v)),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
                'A valid IMEI helps the product pass Dealkr’s quality check faster.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMuted, height: 1.35)),
          ),
        ],
        const SizedBox(height: 14),
        const FieldLabel('What’s in the box', optional: true),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final item in inBoxFor(d.type))
            _Chip(
              label: item,
              selected: d.inBox.contains(item),
              onTap: () => n.set((x) => x.copyWith(
                  inBox: x.inBox.contains(item)
                      ? x.inBox.where((e) => e != item).toList()
                      : [...x.inBox, item])),
            ),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Tick everything the buyer will receive.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textMuted, height: 1.35)),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Description', optional: true),
        AuctionField(
          fieldKey: ValueKey('desc-$fk'),
          initial: d.description,
          maxLines: 3,
          maxLength: 1000,
          hint: 'Anything buyers should know',
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => n.set((x) => x.copyWith(description: v)),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
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

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kBlueSoft : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected ? kBlue : AppColors.border,
                width: selected ? 1.6 : 1.2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 16, color: kBlue),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? kBlue : AppColors.textSecondary)),
          ]),
        ),
      );
}

class _CondTier {
  const _CondTier(this.label, this.icon, this.color, this.grades);
  final String label;
  final IconData icon;
  final Color color;
  final List<ProductCondition> grades;
  bool has(ProductCondition c) => grades.contains(c);
  ProductCondition get defaultCond => grades.length > 2 ? grades[1] : grades.first;
}

const _tiers = [
  _CondTier('Brand new', Icons.auto_awesome_rounded, Color(0xFF14A241),
      [ProductCondition.newItem, ProductCondition.openBox]),
  _CondTier('Refurbished', Icons.autorenew_rounded, Color(0xFF1B5BF2),
      [ProductCondition.refurbished]),
  _CondTier('Used', Icons.sell_rounded, Color(0xFFD97706),
      [ProductCondition.likeNew, ProductCondition.good, ProductCondition.fair]),
];

List<List<ProductType>> _rowsOf4(List<ProductType> all) => [
      for (var i = 0; i < all.length; i += 4)
        all.sublist(i, i + 4 > all.length ? all.length : i + 4),
    ];

/// One product-type tile, same look as [ArtChoiceTile]: the built-ins use
/// the 3D art, other categories show their category image.
class _TypeTile extends StatelessWidget {
  const _TypeTile(
      {required this.type, required this.selected, required this.onTap});
  final ProductType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (type.builtIn) {
      return ArtChoiceTile(
        art: switch (type.key) {
          'mobile' => A3.exchange('phone'),
          'laptop' => A3.exchange('laptop'),
          'tablet' => A3.exchange('tablet'),
          _ => A3.exchange('headphones'),
        },
        label: type.label,
        selected: selected,
        artSize: 44,
        onTap: onTap,
      );
    }
    const accent = Color(0xFF2B55E6);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        height: 108,
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? accent : AppColors.cardBorder,
              width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: (selected ? accent : const Color(0xFF1B2A6B))
                    .withValues(alpha: selected ? 0.2 : 0.06),
                blurRadius: selected ? 14 : 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          Expanded(
              child: Center(
                  child: AnyImage(type.imageUrl,
                      size: 44, radius: 8, fit: BoxFit.contain))),
          const SizedBox(height: 6),
          Text(type.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : AppColors.textPrimary)),
        ]),
      ),
    );
  }
}
