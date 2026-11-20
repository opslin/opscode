import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';

/// Step 3 — which of the vendor's live products to advertise.
class ProductsStep extends ConsumerStatefulWidget {
  const ProductsStep({super.key, required this.rules});
  final AdRules rules;

  @override
  ConsumerState<ProductsStep> createState() => _ProductsStepState();
}

class _ProductsStepState extends ConsumerState<ProductsStep> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(campaignDraftProvider);
    final n = ref.read(campaignDraftProvider.notifier);
    final list = ref.watch(adProductSearchProvider(_q));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _q = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search your products',
            prefixIcon:
                const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF3F6FC),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
        child: Row(children: [
          Expanded(
            child: Text(
                d.products.isEmpty
                    ? 'Tap products to select them'
                    : '${d.products.length} selected',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: d.products.isEmpty ? AppColors.textMuted : kAdBlue)),
          ),
          Text('Up to ${widget.rules.maxProducts}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      ),
      Expanded(
        child: list.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
              message: errorText(e, 'Could not load your products.'),
              onRetry: () => ref.invalidate(adProductSearchProvider)),
          data: (items) => items.isEmpty
              ? EmptyState(
                  icon: PhosphorIconsRegular.cube,
                  title: _q.isEmpty ? 'No live products yet' : 'No match',
                  message: _q.isEmpty
                      ? 'Only approved, in-stock products can be advertised. Add a product and wait for approval first.'
                      : 'Try a different name or brand.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = items[i];
                    final on = d.products.any((x) => x.id == p.id);
                    return _ProductTile(
                      p: p,
                      selected: on,
                      onTap: () {
                        if (!on &&
                            d.products.length >= widget.rules.maxProducts) {
                          return;
                        }
                        n.toggleProduct(p);
                      },
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile(
      {required this.p, required this.selected, required this.onTap});
  final AdProduct p;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? kAdBlueSoft : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? kAdBlue : AppColors.cardBorder,
                width: selected ? 1.6 : 1.2),
          ),
          child: Row(children: [
            ProductThumb(p.thumbnail, size: 58),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.25)),
                    const SizedBox(height: 4),
                    Text(
                        [
                          if (p.price != null) formatInr(p.price!),
                          '${p.stock} in stock',
                        ].join('  ·  '),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ]),
            ),
            const SizedBox(width: 8),
            Icon(
                selected
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsRegular.circle,
                color: selected ? kAdBlue : AppColors.border,
                size: 24),
          ]),
        ),
      );
}
