import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';

/// Step 2 — pick one of the vendor's own in-stock products.
class ProductStep extends ConsumerStatefulWidget {
  const ProductStep({super.key});

  @override
  ConsumerState<ProductStep> createState() => _ProductStepState();
}

class _ProductStepState extends ConsumerState<ProductStep> {
  String _q = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        ref.watch(createDraftProvider.select((d) => d.product?.id));
    final products = ref.watch(productSearchProvider(_q));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Select Product', style: heading(size: 20)),
          const SizedBox(height: 4),
          const Text('Choose the product from your inventory.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350),
                  () => setState(() => _q = v.trim()));
            },
            decoration: InputDecoration(
              hintText: 'Search product…',
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                  size: 20, color: AppColors.textMuted),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF4F6FB),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ]),
      ),
      Expanded(
        child: products.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
              message: errorText(e, 'Could not load your products.'),
              onRetry: () => ref.invalidate(productSearchProvider(_q))),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: PhosphorIconsRegular.package,
                  title: _q.isEmpty ? 'No products to auction' : 'No match',
                  message: _q.isEmpty
                      ? 'Only in-stock products that are not already in an auction can be listed.'
                      : 'Nothing in your inventory matches “$_q”.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final sel = p.id == selected;
                    return GestureDetector(
                      onTap: () =>
                          ref.read(createDraftProvider.notifier).pickProduct(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sel ? kAuctionBlueSoft : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: sel ? kAuctionBlue : AppColors.cardBorder,
                              width: sel ? 1.6 : 1.1),
                        ),
                        child: Row(children: [
                          ProductThumb(
                              p.thumbnail ??
                                  (p.images.isEmpty ? null : p.images.first),
                              size: 58),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy)),
                                  if (p.brand.isNotEmpty)
                                    Text(p.brand,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textMuted)),
                                  const SizedBox(height: 3),
                                  Text(
                                      '${formatInr(p.price)}  ·  ${p.stock} in stock',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary)),
                                ]),
                          ),
                          Icon(
                              sel
                                  ? PhosphorIconsFill.checkCircle
                                  : PhosphorIconsRegular.circle,
                              color:
                                  sel ? kAuctionBlue : AppColors.borderStrong,
                              size: 24),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}
