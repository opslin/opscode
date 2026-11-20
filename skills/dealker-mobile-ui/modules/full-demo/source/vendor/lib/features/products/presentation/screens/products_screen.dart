import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// "My Products" — every listing the vendor has, by approval state.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  ProductTab _tab = ProductTab.all;
  bool _searching = false;

  Future<void> _refresh() async {
    ref
      ..invalidate(myProductsProvider)
      ..invalidate(listingStatsProvider)
      ..invalidate(readinessProvider);
    await ref
        .read(myProductsProvider(_tab).future)
        .catchError((_) => const ListingPage(items: [], total: 0));
  }

  void _add(Readiness? r) {
    if (r != null && r.blocks) {
      showFailureDialog(context, (
        title: switch (r.issue) {
          ReadinessIssue.limitReached => 'Listing limit reached',
          ReadinessIssue.suspended => 'Account not active',
          _ => 'Complete your KYC first',
        },
        message: r.message
      ));
      return;
    }
    context.push(Routes.productAdd);
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(listingStatsProvider);
    final readiness = ref.watch(readinessProvider).asData?.value;
    final list = ref.watch(myProductsProvider(_tab));
    final s = stats.asData?.value;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AuctionAppBar(
        title: 'My Products',
        subtitle: s == null
            ? null
            : '${s.total} ${s.total == 1 ? 'product' : 'products'}',
        onBack: () => context.go(Routes.home),
        actions: [
          IconButton(
              tooltip: 'Search',
              onPressed: () {
                setState(() => _searching = !_searching);
                if (!_searching) {
                  ref.read(productSearchQueryProvider.notifier).set('');
                }
              },
              icon: Icon(
                  _searching
                      ? PhosphorIconsRegular.x
                      : PhosphorIconsRegular.magnifyingGlass,
                  color: AppColors.navy)),
          IconButton(
              tooltip: 'Bulk add',
              onPressed: () => readiness?.blocks == true
                  ? _add(readiness)
                  : context.push(Routes.productBulk),
              icon: const Icon(PhosphorIconsRegular.stack,
                  color: AppColors.navy)),
        ],
      ),
      bottomNavigationBar: const HomeBottomNav(current: NavTab.products),
      floatingActionButton: _AddFab(onTap: () => _add(readiness)),
      body: Column(children: [
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              autofocus: true,
              onChanged: (v) =>
                  ref.read(productSearchQueryProvider.notifier).set(v),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final (i, t) in ProductTab.values.indexed)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: i == ProductTab.values.length - 1 ? 0 : 8),
                  child: _TabPill(
                    label: t.label,
                    count: s == null ? null : t.count(s),
                    selected: _tab == t,
                    onTap: () => setState(() => _tab = t),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: list.when(
              skipLoadingOnReload: true,
              skipError: true,
              loading: () => const _Skeleton(),
              error: (e, _) => ListView(children: [
                SizedBox(
                  height: 420,
                  child: ErrorState(
                      message: errorText(e, 'Could not load your products.'),
                      onRetry: () => ref.invalidate(myProductsProvider)),
                ),
              ]),
              data: (page) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  if (readiness != null) ...[
                    ReadinessBanner(readiness),
                    const SizedBox(height: 12),
                  ],
                  if (page.items.isEmpty)
                    _Empty(
                        tab: _tab,
                        searching:
                            ref.watch(productSearchQueryProvider).isNotEmpty,
                        onAdd: () => _add(readiness))
                  else
                    for (final p in page.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProductRow(
                            p: p,
                            onTap: () =>
                                context.push(Routes.productDetail(p.id))),
                      ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _AddFab extends StatelessWidget {
  const _AddFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: kBlue,
        elevation: 4,
        shadowColor: kBlue.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(PhosphorIconsBold.plus, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Add Product',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5)),
            ]),
          ),
        ),
      );
}

class _TabPill extends StatelessWidget {
  const _TabPill(
      {required this.label,
      required this.count,
      required this.selected,
      required this.onTap});
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? kBlue : AppColors.border, width: 1.2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(count == null ? label : '$label ($count)',
                maxLines: 1,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.p, required this.onTap});
  final ListingCard p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final off = discountLabel(p.price, p.mrp);
    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnyImage(p.thumbnail, size: 76, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                    color: AppColors.navy)),
                          ),
                          const SizedBox(width: 8),
                          StatePill(p.state),
                        ]),
                    const SizedBox(height: 6),
                    if (p.sellB2c)
                      Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 6,
                          children: [
                            Text(formatInr(p.price), style: heading(size: 17)),
                            if (p.mrp != null && p.mrp! > p.price) ...[
                              Text(formatInr(p.mrp!),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      decoration: TextDecoration.lineThrough)),
                              Text(off,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.mint)),
                            ],
                          ]),
                    if (p.sellB2b)
                      Padding(
                        padding: EdgeInsets.only(top: p.sellB2c ? 3 : 0),
                        child: Text(
                            '${formatInr(p.wholesalePrice ?? p.price)} wholesale · MOQ ${p.moq}',
                            style: TextStyle(
                                fontSize: p.sellB2c ? 12.5 : 15,
                                fontWeight: p.sellB2c
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: AppColors.roleB2b)),
                      ),
                    const SizedBox(height: 7),
                    Row(children: [
                      ChannelChips(b2b: p.sellB2b, b2c: p.sellB2c),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                            p.stock == 0 ? 'No stock' : '${p.stock} in stock',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: p.stock == 0
                                    ? AppColors.rose
                                    : AppColors.textMuted)),
                      ),
                    ]),
                  ]),
            ),
          ]),
          if (p.state == ListingState.rejected &&
              p.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.roseSoft,
                  borderRadius: BorderRadius.circular(10)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(PhosphorIconsFill.warningCircle,
                    size: 16, color: AppColors.rose),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.rejectionReason!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, height: 1.35, color: AppColors.navy)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(
      {required this.tab, required this.searching, required this.onAdd});
  final ProductTab tab;
  final bool searching;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final first = tab == ProductTab.all && !searching;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ArtEmpty(
        art: searching
            ? 'assets/3d/sell/looking.png'
            : 'assets/3d/new/addbox.png',
        title: searching
            ? 'No products found'
            : first
                ? 'Add your first product'
                : 'No ${tab.label.toLowerCase()} products',
        message: searching
            ? 'Try a different name.'
            : first
                ? 'List a phone in a few steps: details, photos, a quick quality check and your price. Dealkr reviews it before it goes live.'
                : 'Products will show up here once they reach this stage.',
        action: first
            ? SizedBox(
                width: 200,
                child: AuctionButton(
                    label: 'Add Product',
                    icon: PhosphorIconsBold.plus,
                    height: 50,
                    onPressed: onAdd))
            : null,
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          for (var i = 0; i < 5; i++)
            Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F4FB),
                  borderRadius: BorderRadius.circular(16)),
            ),
        ],
      );
}
