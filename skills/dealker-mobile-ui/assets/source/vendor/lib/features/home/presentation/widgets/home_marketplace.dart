import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/wholesale/application/wholesale_providers.dart';
import 'package:dealker_vendor/features/wholesale/presentation/wholesale_grid.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// B2B Marketplace preview on the home: other vendors' wholesale stock (never
/// the vendor's own listings), with a way into the full marketplace.
class HomeMarketplace extends ConsumerWidget {
  const HomeMarketplace({super.key});

  static const _query = (
    search: '',
    sort: 'newest',
    brand: null,
    condition: null,
    category: null,
    deals: false
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(wholesaleListProvider(_query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: SectionTitle(
              title: 'B2B Marketplace',
              onViewAll: () => context.push(Routes.wholesale)),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text('Buy stock in bulk from verified vendors',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 12),
        page.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Row(children: [
            Expanded(child: SkeletonBox(height: 250)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 250)),
          ]),
          error: (e, _) => InlineError(
              message:
                  e is Failure ? e.message : 'Could not load the marketplace.',
              onRetry: () => ref.invalidate(wholesaleListProvider)),
          data: (p) {
            if (p.items.isEmpty) {
              return HomeCard(
                child: Column(children: [
                  const EmptyLine('No wholesale stock from other vendors yet.'),
                  OutlinedButton(
                      onPressed: () => context.push(Routes.demandPost),
                      child: const Text('Post what you need')),
                ]),
              );
            }
            return Column(children: [
              WholesaleHRow(items: p.items.take(8).toList()),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => context.push(Routes.wholesale),
                  icon: const Icon(PhosphorIconsFill.storefront, size: 20),
                  label: Text('Browse all ${p.total} wholesale listings',
                      style: heading(
                          size: 14, color: Colors.white, w: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ]);
          },
        ),
      ],
    );
  }
}
