import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart'
    show formatInr, heading;
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart'
    show AnyImage;
import 'package:dealker_vendor/features/wholesale/application/wholesale_providers.dart';
import 'package:dealker_vendor/features/wholesale/data/wholesale_models.dart';
import 'package:dealker_vendor/features/wholesale/presentation/wholesale_grid.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// Sections of the B2B marketplace home. Same visual language as the customer app's store home
/// (hero carousel, trust strip, category tiles, gradient deal rail, brand spotlight, shop-by-price,
/// tabbed top picks, promo banners) but fed by the wholesale shelf: bulk price, MOQ, GST invoice.

String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

/// Illustration for a category, by name (assets/categories/).
String? categoryAsset(String name) {
  final n = name.toLowerCase();
  if (n.contains('headphone')) return 'headphones';
  if (n.contains('earbud')) return 'earbuds';
  if (n.contains('speaker')) return 'speaker';
  if (n.contains('watch') || n.contains('wear')) return 'smartwatch';
  if (n.contains('power bank')) return 'powerbank';
  if (n.contains('charger') || n.contains('adapter')) return 'charger';
  if (n.contains('phone') || n.contains('mobile')) return 'smartphones';
  if (n.contains('tablet') || n.contains('ipad')) return 'tablets';
  if (n.contains('laptop') || n.contains('computer')) return 'laptop';
  if (n.contains('electronic')) return 'laptop';
  return null;
}

/// Brand logo asset path by brand name (assets/brands/SLUG.png); the tile falls back to the name when missing.
String brandAssetPath(String brand) {
  final s = _slug(brand);
  return 'assets/brands/${s == 'redmi' ? 'redmi' : s}.png';
}

Widget brandLogo(String brand, {double height = 28, double? width}) => Image.asset(
      brandAssetPath(brand),
      height: height,
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(brand,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: heading(size: 13, w: FontWeight.w800)),
    );

/// Section title: big heading, optional pill badge, hairline rule — as in the customer app.
class B2bSectionTitle extends StatelessWidget {
  const B2bSectionTitle(this.title,
      {super.key, this.badge, this.subtitle, this.trailing, this.color = AppColors.navy});
  final String title;
  final String? badge;
  final String? subtitle;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title,
                maxLines: 1,
                softWrap: false,
                style: heading(size: 21, color: color, w: FontWeight.w800)),
            if (badge != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFDDE6FF),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(badge!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF2B2FD6))),
              ),
            ],
            const SizedBox(width: 10),
            Expanded(
                flex: 1,
                child: Container(height: 1.2, color: color.withValues(alpha: 0.12))),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ],
      );
}

// ── Hero carousel ──────────────────────────────────────────────────────────

class B2bHeroPage {
  const B2bHeroPage(
      {required this.asset,
      required this.eyebrow,
      required this.title,
      required this.subtitle,
      this.cta,
      this.onTap});
  final String asset;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String? cta;
  final VoidCallback? onTap;
}

class B2bHeroCarousel extends StatefulWidget {
  const B2bHeroCarousel({super.key, required this.pages});
  final List<B2bHeroPage> pages;

  @override
  State<B2bHeroCarousel> createState() => _B2bHeroCarouselState();
}

class _B2bHeroCarouselState extends State<B2bHeroCarousel> {
  final _ctl = PageController(viewportFraction: 0.93);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_ctl.hasClients || widget.pages.length < 2) return;
      _ctl.animateToPage((_page + 1) % widget.pages.length,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    return Column(children: [
      SizedBox(
        height: 176,
        child: PageView.builder(
          controller: _ctl,
          itemCount: pages.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _HeroSlide(page: pages[i])),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < pages.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: i == _page ? 20 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
                color: i == _page ? AppColors.primary : AppColors.cardBorder,
                borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    ]);
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.page});
  final B2bHeroPage page;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: page.onTap,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(page.asset, fit: BoxFit.cover, alignment: Alignment.centerRight),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(page.eyebrow,
                    style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.amber)),
                const SizedBox(height: 6),
                SizedBox(
                  width: 128,
                  child: Text(page.title,
                      style: heading(size: 17.5, color: Colors.white, w: FontWeight.w800)),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 122,
                  child: Text(page.subtitle,
                      maxLines: 2,
                      style: TextStyle(
                          fontSize: 10.5,
                          height: 1.3,
                          color: Colors.white.withValues(alpha: 0.88))),
                ),
                if (page.cta != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.amber, borderRadius: BorderRadius.circular(10)),
                    child: Text(page.cta!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                  ),
                ],
              ],
            ),
          ),
        ]),
      );
}

// ── Trust strip (the B2B counterpart of the customer app's ₹0 FEES strip) ───

class B2bTrustStrip extends StatelessWidget {
  const B2bTrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('GST invoice', 'on every order', Icons.receipt_long_rounded),
      ('Escrow pay', 'held till delivery', Icons.lock_rounded),
      ('Verified', 'wholesale sellers', Icons.verified_rounded),
      ('Pan-India', 'bulk delivery', Icons.local_shipping_rounded),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        for (final (a, b, icon) in items)
          Expanded(
            child: Column(children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(height: 5),
              Text(a,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.navy)),
              Text(b,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
            ]),
          ),
      ]),
    );
  }
}

// ── Shop by category ───────────────────────────────────────────────────────

class B2bCategoryGrid extends StatelessWidget {
  const B2bCategoryGrid(
      {super.key, required this.cats, required this.selected, required this.onTap});
  final List<WholesaleCategory> cats;
  final String? selected;
  final ValueChanged<WholesaleCategory> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 10.0;
        final w = (c.maxWidth - gap * 3) / 4;
        return Wrap(spacing: gap, runSpacing: 14, children: [
          for (final cat in cats)
            GestureDetector(
              onTap: () => onTap(cat),
              child: SizedBox(
                width: w,
                child: Column(children: [
                  Container(
                    width: w,
                    height: w,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: selected == cat.id ? AppColors.primary : Colors.transparent,
                          width: 2),
                    ),
                    child: _catImage(cat),
                  ),
                  const SizedBox(height: 6),
                  Text(cat.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, color: AppColors.navy)),
                ]),
              ),
            ),
        ]);
      });

  Widget _catImage(WholesaleCategory c) {
    final asset = categoryAsset(c.name);
    if (asset != null) {
      return Image.asset('assets/categories/$asset.png', fit: BoxFit.contain);
    }
    return AnyImage(c.imageUrl, fit: BoxFit.contain, radius: 0);
  }
}

// ── Bulk-deals rail: gradient header + white cards ─────────────────────────

class B2bDealsRail extends StatelessWidget {
  const B2bDealsRail(
      {super.key, required this.items, required this.topOff, required this.onViewAll});
  final List<WholesaleItem> items;
  final int topOff;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1740E6), Color(0xFF5B21D6)]),
        ),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Top bulk deals',
                    style: heading(size: 22, color: Colors.white, w: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('Best wholesale prices this week',
                    style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
              ]),
            ),
            Transform.rotate(
              angle: -0.07,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))]),
                child: Column(children: [
                  const Text('BULK PRICE',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.navy)),
                  Text(topOff > 0 ? 'UP TO $topOff% OFF' : 'DEALS',
                      style: heading(size: 13, w: FontWeight.w900)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          WholesaleHRow(items: items),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onViewAll,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('View all deals',
                    style: heading(size: 15, w: FontWeight.w800)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.navy),
              ]),
            ),
          ),
        ]),
      );
}

// ── Brand tiles + spotlight ────────────────────────────────────────────────

class B2bBrandRow extends StatelessWidget {
  const B2bBrandRow(
      {super.key, required this.brands, required this.selected, required this.onTap});
  final List<FacetOption> brands;
  final String? selected;
  final ValueChanged<String> onTap;

  static const _tints = [
    Color(0xFFE5EEFF), Color(0xFFEEEBFF), Color(0xFFFFEBD6),
    Color(0xFFDDF6F2), Color(0xFFFFE3E3), Color(0xFFFFF1CF),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: brands.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final b = brands[i];
            final on = selected == b.value;
            return GestureDetector(
              onTap: () => onTap(b.value),
              child: Container(
                width: 98,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _tints[i % _tints.length],
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: on ? AppColors.primary : Colors.transparent, width: 2),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(child: Center(child: brandLogo(b.value, height: 34, width: 70))),
                  Text('${b.count} listing${b.count == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                ]),
              ),
            );
          },
        ),
      );
}

/// One brand as a hero block: logo + tagline, a featured listing, then more from the brand.
class B2bBrandSpotlight extends ConsumerWidget {
  const B2bBrandSpotlight({super.key, required this.brand, this.tint = const Color(0xFFE3EAFF), required this.onSeeAll});
  final String brand;
  final Color tint;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = (search: '', sort: 'newest', brand: brand, condition: null, category: null, deals: false);
    final items = ref.watch(wholesaleListProvider(q)).asData?.value.items ?? const <WholesaleItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final first = items.first;
    final rest = items.skip(1).take(8).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: brandLogo(brand, height: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(brand, style: heading(size: 24, w: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text('Bulk offers · Verified sellers',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ]),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text('See all ›',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
        ]),
        const SizedBox(height: 12),
        _Feature(item: first),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('More from $brand', style: heading(size: 16, w: FontWeight.w800)),
          const SizedBox(height: 10),
          WholesaleHRow(items: rest),
        ],
      ]),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.item});
  final WholesaleItem item;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push(Routes.wholesaleView(item.id)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white)),
          child: Row(children: [
            Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: AnyImage(item.thumbnail, fit: BoxFit.contain, radius: 0),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: heading(size: 15.5, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('MOQ ${item.moq} units${item.storage != null ? ' · ${item.storage}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.navy, width: 1.4)),
                    child: Text('${formatInr(item.price)} / unit',
                        style: heading(size: 15, w: FontWeight.w900)),
                  ),
                  if ((item.discountPct ?? 0) > 0)
                    Text('${item.discountPct!.round()}% OFF',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.mint)),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

// ── Shop by price ──────────────────────────────────────────────────────────

class B2bPriceShop extends StatefulWidget {
  const B2bPriceShop({super.key, required this.items, required this.onSeeAll});
  final List<WholesaleItem> items;
  final VoidCallback onSeeAll;

  @override
  State<B2bPriceShop> createState() => _B2bPriceShopState();
}

class _B2bPriceShopState extends State<B2bPriceShop> {
  static const _limits = [2000, 5000, 15000, 30000, 60000];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    // pick the first tab that has stock so the section never opens empty
    final within = [
      for (final l in _limits) widget.items.where((i) => i.price <= l).toList()
    ];
    final idx = within[_tab].isNotEmpty ? _tab : within.indexWhere((l) => l.isNotEmpty);
    if (idx < 0) return const SizedBox.shrink();
    final shown = within[idx].take(4).toList();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: B2bSectionTitle('Shop by price', badge: 'PER UNIT'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _limits.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final on = i == idx;
              return GestureDetector(
                onTap: within[i].isEmpty ? null : () => setState(() => _tab = i),
                child: Opacity(
                  opacity: within[i].isEmpty ? 0.4 : 1,
                  child: Container(
                    width: 92,
                    decoration: BoxDecoration(
                        color: on ? const Color(0xFFDDE6FF) : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Under',
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: on ? const Color(0xFF2B2FD6) : AppColors.textSecondary)),
                      Text(formatInr(_limits[i]),
                          style: heading(
                              size: 18,
                              color: on ? const Color(0xFF2B2FD6) : AppColors.navy,
                              w: FontWeight.w900)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: WholesaleGrid(items: shown)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _SeeAll(label: 'See all', onTap: widget.onSeeAll),
        ),
      ]),
    );
  }
}

class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: const Color(0xFFF1F3F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: heading(size: 16, w: FontWeight.w800)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_right_rounded, size: 22, color: AppColors.navy),
          ]),
        ),
      );
}

// ── Top picks: tabs by category ────────────────────────────────────────────

class B2bTopPicks extends ConsumerStatefulWidget {
  const B2bTopPicks({super.key, required this.cats, required this.onSeeAll});
  final List<WholesaleCategory> cats;
  final ValueChanged<String?> onSeeAll;

  @override
  ConsumerState<B2bTopPicks> createState() => _B2bTopPicksState();
}

class _B2bTopPicksState extends ConsumerState<B2bTopPicks> {
  int _tab = 0; // 0 = trending (all), then categories

  @override
  Widget build(BuildContext context) {
    final cats = widget.cats.take(4).toList();
    final catId = _tab == 0 ? null : cats[(_tab - 1).clamp(0, cats.length - 1)].id;
    final q = (search: '', sort: _tab == 0 ? 'stock' : 'newest', brand: null, condition: null, category: catId, deals: false);
    final items = ref.watch(wholesaleListProvider(q)).asData?.value.items ?? const <WholesaleItem>[];
    final labels = ['Trending', for (final c in cats) c.name];
    const gold = Color(0xFFB8893B);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Top picks for your shop', style: heading(size: 22, color: gold, w: FontWeight.w800)),
      const SizedBox(height: 3),
      const Text('Fast-moving wholesale stock this week',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      const SizedBox(height: 12),
      SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final on = i == _tab;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFFDF0DC) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: on ? gold : Colors.transparent, width: 1.4),
                ),
                child: Text(labels[i],
                    style: heading(size: 15, color: on ? gold : AppColors.navy, w: FontWeight.w700)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: Text('No stock here yet', style: TextStyle(color: AppColors.textMuted))),
        )
      else
        WholesaleGrid(items: items.take(4).toList()),
      const SizedBox(height: 12),
      _SeeAll(label: 'See all', onTap: () => widget.onSeeAll(catId)),
    ]);
  }
}

// ── Full-width promo banner ────────────────────────────────────────────────

class B2bPromoBanner extends StatelessWidget {
  const B2bPromoBanner({super.key, required this.page, this.height = 172});
  final B2bHeroPage page;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: _HeroSlide(page: page)),
      );
}

// ── Condition: tabs + "shop by condition" tiles ────────────────────────────

int _tierCount(List<FacetOption> conds, ConditionTier t) =>
    conds.where((c) => conditionTier(c.value) == t).fold(0, (n, c) => n + c.count);

/// All · Brand new · Refurbished · Used, with listing counts. `selected` is the active server filter value.
class B2bConditionTabs extends StatelessWidget {
  const B2bConditionTabs(
      {super.key, required this.conditions, required this.selected, required this.onSelect});
  final List<FacetOption> conditions;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final total = conditions.fold<int>(0, (n, c) => n + c.count);
    Widget tab(String label, int count, String? value, Color color) {
      final on = selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => onSelect(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: on ? color : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: on ? color : AppColors.cardBorder),
            ),
            child: Row(children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : AppColors.navy)),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text('$count',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white70 : AppColors.textMuted)),
              ],
            ]),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        tab('All', total, null, AppColors.navy),
        tab('Brand new', _tierCount(conditions, ConditionTier.brandNew), tierFilter(ConditionTier.brandNew), const Color(0xFF14A241)),
        tab('Refurbished', _tierCount(conditions, ConditionTier.refurbished), tierFilter(ConditionTier.refurbished), const Color(0xFF1B5BF2)),
        tab('Used', _tierCount(conditions, ConditionTier.used), tierFilter(ConditionTier.used), const Color(0xFFD97706)),
      ]),
    );
  }
}

class B2bConditionTiles extends StatelessWidget {
  const B2bConditionTiles({super.key, required this.conditions, required this.onSelect});
  final List<FacetOption> conditions;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const tiles = [
      (ConditionTier.brandNew, 'Brand new', 'Sealed · full warranty', Icons.auto_awesome_rounded, Color(0xFF14A241), Color(0xFFE3F7EA)),
      (ConditionTier.refurbished, 'Refurbished', 'Tested & restored', Icons.autorenew_rounded, Color(0xFF1B5BF2), Color(0xFFE5EEFF)),
      (ConditionTier.used, 'Used', 'Graded · best value', Icons.sell_rounded, Color(0xFFD97706), Color(0xFFFFF1CF)),
    ];
    return Row(children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => onSelect(tierFilter(tiles[i].$1)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: tiles[i].$6, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: tiles[i].$5, shape: BoxShape.circle),
                  child: Icon(tiles[i].$4, size: 19, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(tiles[i].$2, style: heading(size: 15, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(tiles[i].$3,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 10.5, height: 1.25, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('${_tierCount(conditions, tiles[i].$1)} listings',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tiles[i].$5)),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }
}
