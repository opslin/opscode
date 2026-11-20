import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/wholesale/application/cart_provider.dart';
import 'package:dealker_vendor/features/wholesale/application/wholesale_providers.dart';
import 'package:dealker_vendor/features/wholesale/data/wholesale_models.dart';
import 'package:dealker_vendor/features/wholesale/presentation/b2b_home_sections.dart';
import 'package:dealker_vendor/features/wholesale/presentation/cart_bar.dart';
import 'package:dealker_vendor/features/wholesale/presentation/wholesale_grid.dart';
import 'package:dealker_vendor/routing/route_names.dart';

const _sorts = <(String, String)>[
  ('newest', 'Newest'),
  ('price_low', 'Price: low to high'),
  ('price_high', 'Price: high to low'),
  ('stock', 'Most stock'),
];

String conditionLabel(String? c) => switch (c) {
      'NEW' => 'New',
      'OPEN_BOX' => 'Open box',
      'REFURBISHED' => 'Refurbished',
      'USED_LIKE_NEW' => 'Like new',
      'USED_GOOD' => 'Used · Good',
      'USED_FAIR' => 'Used · Fair',
      _ => c ?? '',
    };

/// B2B Marketplace: other verified vendors' wholesale stock, bought in bulk.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _search = TextEditingController();
  String _q = '';
  String _sort = 'newest';
  String? _brand;
  String? _condition;
  String? _cat; // chosen top-level category
  String? _sub; // chosen sub-category inside it
  bool _dealsOnly = false; // banner CTA: show only discounted listings
  // Last facets seen, so the pickers keep working while a new page loads.
  List<FacetOption> _brands = const [];
  List<FacetOption> _conditions = const [];
  // Last results shown, kept on screen (dimmed) while a new query loads.
  WholesalePage? _last;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? get _category => _sub ?? _cat;

  WholesaleQuery get _query => (
        search: _q,
        sort: _sort,
        brand: _brand,
        condition: _condition,
        category: _category,
        deals: _dealsOnly
      );

  /// The server's discounted listings (biggest first) inside the chosen category.
  WholesaleQuery get _dealsQuery => (
        search: '',
        sort: 'discount',
        brand: null,
        condition: null,
        category: _category,
        deals: true
      );

  bool get _filtered =>
      _brand != null || _condition != null || _q.isNotEmpty || _dealsOnly;

  Future<void> _refresh() async {
    ref.invalidate(wholesaleListProvider(_query));
    await ref
        .read(wholesaleListProvider(_query).future)
        .catchError((_) => const WholesalePage(items: [], total: 0));
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(wholesaleListProvider(_query));
    final cart = ref.watch(wholesaleCartProvider);
    final cats =
        ref.watch(wholesaleCategoriesProvider).asData?.value ?? const [];
    // The server already returns only discounted listings; the filter keeps this
    // right against a server that predates the `deals` parameter.
    final deals = [
      for (final i in ref
              .watch(wholesaleListProvider(_dealsQuery))
              .asData
              ?.value
              .items ??
          const <WholesaleItem>[])
        if ((i.discountPct ?? 0) > 0) i
    ];
    page.whenData((p) {
      _last = p;
      if (p.brands.isNotEmpty) _brands = p.brands;
      if (p.conditions.isNotEmpty) _conditions = p.conditions;
    });

    return Scaffold(
      backgroundColor: AppColors.canvas,
      bottomNavigationBar: const Column(mainAxisSize: MainAxisSize.min, children: [
        CartBar(safeBottom: false),
        HomeBottomNav(current: NavTab.marketplace),
      ]),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: RefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: MediaQuery.paddingOf(context).top,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                controller: _search,
                cartCount: cart.length,
                hasQuery: _q.isNotEmpty,
                onSubmit: (v) => setState(() => _q = v.trim()),
                onClear: () => setState(() {
                  _search.clear();
                  _q = '';
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                child: page.when(skipLoadingOnReload: true, skipError: true, 
                  loading: () => _last == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator()))
                      : Opacity(
                          opacity: 0.5, child: _body(_last!, cats, deals)),
                  error: (e, _) => SizedBox(
                      height: 360,
                      child: ErrorState(
                          message:
                              errorText(e, 'Could not load the marketplace.'),
                          onRetry: () =>
                              ref.invalidate(wholesaleListProvider(_query)))),
                  data: (p) => _body(p, cats, deals),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _browsing => _filtered || _cat != null;

  void _openAll({String? category, String sort = 'newest', bool deals = false, String? brand}) =>
      setState(() {
        _cat = category;
        _sub = null;
        _sort = sort;
        _dealsOnly = deals;
        _brand = brand;
      });

  List<B2bHeroPage> _heroPages(int topOff, int minMoq, int listings) => [
        B2bHeroPage(
          asset: 'assets/banners/b2b_hero_bulk.jpg',
          eyebrow: 'BULK DEALS',
          title: topOff > 0 ? 'Up to $topOff% off\nin bulk' : 'Buy stock\nin bulk',
          subtitle: minMoq > 0
              ? '$listings listings · MOQ from $minMoq units'
              : 'Verified wholesalers across India',
          cta: 'View deals',
          onTap: () => _openAll(deals: true),
        ),
        const B2bHeroPage(
          asset: 'assets/banners/b2b_hero_trust.jpg',
          eyebrow: 'VERIFIED SELLERS',
          title: 'GST invoice\non every order',
          subtitle: 'Payment is held safely until you receive the goods',
        ),
        B2bHeroPage(
          asset: 'assets/banners/b2b_hero_brands.jpg',
          eyebrow: 'TOP BRANDS',
          title: 'Brand fest\nfor your shop',
          subtitle: 'Apple, Samsung, Xiaomi and more at wholesale rates',
          cta: 'Shop brands',
          onTap: () => _openAll(sort: 'price_low'),
        ),
        B2bHeroPage(
          asset: 'assets/banners/b2b_hero_demand.jpg',
          eyebrow: "CAN'T FIND YOUR MODEL?",
          title: 'Post what\nyou need',
          subtitle: 'Sellers send you their best price',
          cta: 'Post a demand',
          onTap: () => context.push(Routes.demandPost),
        ),
      ];

  Widget _body(WholesalePage p, List<WholesaleCategory> cats,
      List<WholesaleItem> deals) {
    final topOff = deals.isEmpty ? 0 : (deals.first.discountPct ?? 0).round();
    final minMoq = p.items.isEmpty
        ? 0
        : p.items.map((i) => i.moq).reduce((a, b) => a < b ? a : b);
    const gap = SizedBox(height: 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_browsing) ...[
          B2bHeroCarousel(pages: _heroPages(topOff, minMoq, p.total)),
          const SizedBox(height: 14),
          const B2bTrustStrip(),
          gap,
        ],
        if (_conditions.isNotEmpty) ...[
          B2bConditionTabs(
              conditions: _conditions,
              selected: _condition,
              onSelect: (v) => setState(() => _condition = v)),
          gap,
        ],
        if (!_browsing && _conditions.isNotEmpty) ...[
          const B2bSectionTitle('Shop by condition'),
          const SizedBox(height: 12),
          B2bConditionTiles(
              conditions: _conditions, onSelect: (v) => setState(() => _condition = v)),
          gap,
        ],
        if (cats.isNotEmpty && !_filtered) ...[
          const B2bSectionTitle('Shop by category'),
          const SizedBox(height: 12),
          B2bCategoryGrid(
            cats: cats,
            selected: _cat,
            onTap: (c) => setState(() {
              _cat = _cat == c.id ? null : c.id;
              _sub = null;
              _brand = null;
            }),
          ),
          if (_cat != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (_) {
              final top = cats.firstWhere((c) => c.id == _cat, orElse: () => cats.first);
              if (top.children.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 36,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _Pill(label: 'All ${top.name}', selected: _sub == null, onTap: () => setState(() => _sub = null)),
                  for (final c in top.children)
                    _Pill(
                        label: '${c.name} (${c.count})',
                        selected: _sub == c.id,
                        onTap: () => setState(() => _sub = _sub == c.id ? null : c.id)),
                ]),
              );
            }),
          ],
          gap,
        ],
        if (deals.isNotEmpty && !_browsing) ...[
          B2bDealsRail(
              items: deals.take(8).toList(),
              topOff: topOff,
              onViewAll: () => _openAll(deals: true)),
          gap,
        ],
        if (_brands.isNotEmpty) ...[
          const B2bSectionTitle('Shop by brand'),
          const SizedBox(height: 12),
          B2bBrandRow(
              brands: _brands,
              selected: _brand,
              onTap: (b) => setState(() => _brand = _brand == b ? null : b)),
          gap,
        ],
        if (!_browsing) ...[
          B2bPromoBanner(
              page: B2bHeroPage(
            asset: 'assets/banners/b2b_hero_audio.jpg',
            eyebrow: 'ACCESSORIES',
            title: 'Audio & gear\nin bulk',
            subtitle: 'Headphones, watches, chargers',
            cta: 'Shop now',
            onTap: () => _openAll(sort: 'price_low'),
          )),
          gap,
          for (var i = 0; i < _brands.length && i < 2; i++) ...[
            B2bBrandSpotlight(
              brand: _brands[i].value,
              tint: const [Color(0xFFE3EAFF), Color(0xFFFFEFD9)][i],
              onSeeAll: () => _openAll(brand: _brands[i].value),
            ),
            gap,
          ],
          B2bPriceShop(items: p.items, onSeeAll: () => _openAll(sort: 'price_low')),
          gap,
          B2bPromoBanner(
              page: const B2bHeroPage(
            asset: 'assets/banners/b2b_hero_delivery.jpg',
            eyebrow: 'PAN-INDIA',
            title: 'Bulk orders at\nyour doorstep',
            subtitle: 'Track every parcel from seller to your shop',
          )),
          gap,
          if (cats.isNotEmpty) ...[
            B2bTopPicks(cats: cats, onSeeAll: (c) => _openAll(category: c)),
            gap,
          ],
          B2bPromoBanner(
              height: 172,
              page: B2bHeroPage(
                asset: 'assets/banners/b2b_hero_demand.jpg',
                eyebrow: 'NOT LISTED?',
                title: 'Tell sellers\nyour need',
                subtitle: 'Post a demand, get quotes',
                cta: 'Post a demand',
                onTap: () => context.push(Routes.demandPost),
              )),
          gap,
        ],
        if (_condition != null && _conditions.where((c) => _condition!.split(',').contains(c.value)).length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _Pill(
                  label: 'All grades',
                  selected: _condition!.contains(','),
                  onTap: () => setState(() => _condition = tierFilter(conditionTier(_condition!.split(',').first)))),
              for (final c in _conditions.where((c) => conditionTier(c.value) == conditionTier(_condition!.split(',').first)))
                _Pill(
                    label: '${conditionBadge(c.value)} (${c.count})',
                    selected: _condition == c.value,
                    onTap: () => setState(() => _condition = c.value)),
            ]),
          ),
          const SizedBox(height: 18),
        ],
        Row(children: [
          Expanded(
              child: Text(_browsing ? 'Results' : 'Fresh wholesale stock',
                  style: heading(size: 21, w: FontWeight.w800))),
          Text('${p.total} listing${p.total == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            if (_dealsOnly)
              _Pill(label: 'Deals only  ✕', selected: true, onTap: () => setState(() => _dealsOnly = false)),
            for (final (k, label) in _sorts)
              _Pill(label: label, selected: _sort == k, onTap: () => setState(() => _sort = k)),
          ]),
        ),
        const SizedBox(height: 12),
        if (p.items.isEmpty)
          SizedBox(
              height: 380,
              child: EmptyState(
                icon: PhosphorIconsRegular.storefront,
                title: _browsing ? 'Nothing matches' : 'No wholesale stock yet',
                message: _browsing
                    ? 'Try a different brand or word, or post a demand and let sellers come to you.'
                    : 'Vendors who list products for B2B appear here. Meanwhile, post what you need and sellers will quote.',
                action: TextButton(
                    onPressed: () => context.push(Routes.demandPost),
                    child: const Text('Post a demand')),
              ))
        else
          WholesaleGrid(items: p.items),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.cartCount,
    required this.hasQuery,
    required this.onSubmit,
    required this.onClear,
  });
  final TextEditingController controller;
  final int cartCount;
  final bool hasQuery;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 6, 14, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF5B4BEA)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(children: [
        Row(children: [
          IconButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.home),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
          Expanded(
            child: Text('B2B Marketplace',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    heading(size: 19, color: Colors.white, w: FontWeight.w800)),
          ),
          IconButton(
              tooltip: 'My wholesale orders',
              onPressed: () => context.push(Routes.wholesaleOrders),
              icon: const Icon(PhosphorIconsRegular.receipt,
                  color: Colors.white)),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.push(Routes.wholesaleCart),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              backgroundColor: AppColors.rose,
              child: const Icon(PhosphorIconsRegular.shoppingCart,
                  color: Colors.white),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmit,
            decoration: InputDecoration(
              hintText: 'Search phones, brands, sellers',
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(PhosphorIconsRegular.x),
                      onPressed: onClear)
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
      ]),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.cardBorder),
            ),
            child: Text(label,
                style: heading(
                    size: 12.5,
                    color: selected ? Colors.white : AppColors.textSecondary,
                    w: FontWeight.w700)),
          ),
        ),
      );
}

/// Hero banners (brand artwork, copy drawn here so the numbers stay live).
