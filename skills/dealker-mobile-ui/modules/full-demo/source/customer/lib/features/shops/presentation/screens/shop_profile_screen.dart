import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dealker_app/shared/widgets/app_bottom_nav.dart' show StandaloneCartBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:dealker_app/features/shops/data/shop_summary.dart';
import 'package:dealker_app/features/shops/presentation/providers/shops_provider.dart';
import 'package:dealker_app/features/shops/presentation/widgets/shop_widgets.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';
import 'package:dealker_app/shared/widgets/dealker_product_grid.dart';
import 'package:dealker_app/shared/widgets/web_storefront_footer.dart';

enum _Tab { products, deals, about }

class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen(
      {required this.shopId, this.initialTab = 'products', super.key});

  final String shopId;

  /// 'products' (default), 'deals' or 'about' — lets a link open straight on Deals.
  final String initialTab;

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  late _Tab _tab = switch (widget.initialTab) {
    'deals' => _Tab.deals,
    'about' => _Tab.about,
    _ => _Tab.products,
  };
  String _category = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ShopProfile> async =
        ref.watch(shopProfileProvider(widget.shopId));
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: async.when(
              loading: () => const DealkerPageLoader(),
              error: (Object e, _) => _ErrorState(
                onRetry: () =>
                    ref.invalidate(shopProfileProvider(widget.shopId)),
              ),
              data: (ShopProfile p) => _content(context, p),
            ),
          ),
          // Shop pages sit on the root navigator, above the tab shell, so the
          // shell's milestone cart bar is hidden here — show our own.
          const StandaloneCartBar(),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, ShopProfile p) {
    final ShopSummary s = p.summary;
    final List<Color> pal = shopColors(s);
    final double top = MediaQuery.paddingOf(context).top;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(shopProfileProvider(widget.shopId));
        ref.invalidate(shopProductsProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: SizedBox(
              height: 150 + top + 42,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 150 + top,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color.lerp(pal.first, Colors.black, 0.35)!,
                            pal.first,
                            pal.last,
                          ],
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (s.bannerUrl != null)
                            AppImage(
                              imageUrl: s.bannerUrl!,
                              memCacheWidth: 1200,
                              memCacheHeight: 500,
                              placeholder: const SizedBox.shrink(),
                              errorWidget: const SizedBox.shrink(),
                            )
                          else
                            const _CoverArt(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: top + 8,
                    child: GestureDetector(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: kShopInk),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 150 + top - 34,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        ShopAvatar(shop: s, size: 76, ring: 4),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ShopFollowButton(
                              shop: s, height: 40, minWidth: 116),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            shopTitle(s),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: kShopInk,
                            ),
                          ),
                        ),
                        if (s.isVerified) ...<Widget>[
                          const SizedBox(width: 6),
                          const VerifiedTick(size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      <String>[
                        if (s.vendorName.isNotEmpty &&
                            s.vendorName != shopTitle(s))
                          'by ${s.vendorName}',
                        if (p.memberSince != null)
                          'Member since ${p.memberSince}',
                      ].join(' · '),
                      style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          color: kShopMuted),
                    ),
                    if (p.address.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 9),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.location_on_rounded,
                              size: 16, color: Color(0xFFE8175D)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              p.address,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                height: 1.35,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (p.summary.distanceKm != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF3FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.route_rounded,
                                size: 14, color: kShopBlue),
                            const SizedBox(width: 5),
                            Text(
                              '${p.summary.distanceKm! < 1 ? '${(p.summary.distanceKm! * 1000).round()} m' : '${p.summary.distanceKm!.toStringAsFixed(1)} km'} from you'
                              '${p.summary.distanceMinutes != null ? ' · ~${p.summary.distanceMinutes} min' : ''}',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kShopBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _Stats(p: p),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, 0),
              child: _Tabs(
                tab: _tab,
                deals: p.dealCount,
                onSelect: (_Tab t) => setState(() {
                  _tab = t;
                  _category = '';
                }),
              ),
            ),
          ),
          ..._tabBody(context, p),
          if (kIsWeb && MediaQuery.sizeOf(context).width >= 700)
            SliverToBoxAdapter(
                child: WebStorefrontFooter(onNavigate: context.go))
          else
            SliverToBoxAdapter(
                child: SizedBox(
                    height: 110 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }

  List<Widget> _tabBody(BuildContext context, ShopProfile p) {
    Widget pad(Widget w) => SliverToBoxAdapter(
          child: Transform.translate(offset: const Offset(0, 0), child: w),
        );
    switch (_tab) {
      case _Tab.about:
        return <Widget>[pad(_About(p: p))];
      case _Tab.deals:
        return <Widget>[
          pad(_DealsBanner(count: p.dealCount)),
          if (p.categories.isNotEmpty)
            pad(
              _CategoryPictures(
                categories: p.categories,
                selected: _category,
                onSelect: (String id) =>
                    setState(() => _category = id == _category ? '' : id),
              ),
            ),
          pad(_Heading(
            title: _category.isEmpty
                ? 'All deals'
                : p.categories
                    .firstWhere((ShopCategory c) => c.id == _category)
                    .name,
          )),
          _grid(p, deals: true),
        ];
      case _Tab.products:
        return <Widget>[
          if (p.categories.isNotEmpty)
            pad(
              _CategoryChips(
                total: p.summary.productCount,
                categories: p.categories,
                selected: _category,
                onSelect: (String id) => setState(() => _category = id),
              ),
            ),
          pad(_Heading(
            title: _category.isEmpty
                ? 'All products'
                : p.categories
                    .firstWhere((ShopCategory c) => c.id == _category)
                    .name,
          )),
          _grid(p, deals: false),
        ];
    }
  }

  Widget _grid(ShopProfile p, {required bool deals}) {
    final AsyncValue<List<ProductEntity>> async = ref.watch(
      shopProductsProvider(
          (shopId: widget.shopId, categoryId: _category, deals: deals)),
    );
    return SliverToBoxAdapter(
      child: Transform.translate(
        offset: const Offset(0, 0),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: const DealkerPageLoader(),
          ),
          error: (Object e, _) => _ErrorState(
            compact: true,
            onRetry: () => ref.invalidate(shopProductsProvider),
          ),
          data: (List<ProductEntity> list) {
            if (list.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Center(
                  child: Text(
                    deals
                        ? 'No deals in this category right now'
                        : 'No products here yet',
                    style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        color: kShopMuted),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  const double gap = 12;
                  final int columns =
                      productGridColumns(c.maxWidth, isWeb: kIsWeb);
                  final double w = (c.maxWidth - gap * (columns - 1)) / columns;
                  final DealkerCardSlots slots =
                      DealkerCardSlots.forProducts(list, w);
                  return Wrap(
                    spacing: gap,
                    runSpacing: 14,
                    children: <Widget>[
                      for (final ProductEntity pr in list)
                        DealkerProductCard(
                          product: pr,
                          width: w,
                          nameLines: slots.nameLines,
                          showSoldRow: slots.showSold,
                          showRatingRow: slots.showRating,
                          onTap: () => context.push('/product/${pr.id}'),
                          onOptionsTap: pr.hasMultipleOptions
                              ? () => showProductOptionsSheet(context, pr)
                              : null,
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CoverPainter());
}

class _CoverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint soft = Paint()..color = Colors.white.withValues(alpha: 0.10);
    canvas
      ..drawCircle(Offset(size.width * 0.86, size.height * 0.28),
          size.width * 0.34, soft)
      ..drawCircle(Offset(size.width * 0.12, size.height * 1.05),
          size.width * 0.30, soft)
      ..drawCircle(
        Offset(size.width * 0.62, size.height * 0.05),
        size.width * 0.12,
        Paint()..color = Colors.white.withValues(alpha: 0.07),
      );
  }

  @override
  bool shouldRepaint(_CoverPainter old) => false;
}

class _Stats extends StatelessWidget {
  const _Stats({required this.p});

  final ShopProfile p;

  @override
  Widget build(BuildContext context) {
    final ShopSummary s = p.summary;
    Widget cell(String top, String bottom, {bool last = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(right: BorderSide(color: Color(0xFFEEF0F5))),
            ),
            child: Column(
              children: <Widget>[
                Text(top,
                    style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kShopInk)),
                const SizedBox(height: 2),
                Text(bottom,
                    style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        color: kShopMuted)),
              ],
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F5)),
      ),
      child: Row(
        children: <Widget>[
          cell('${s.productCount}', 'Products'),
          cell(compactCount(s.followerCount), 'Followers'),
          cell(
            s.ratingCount > 0 ? '${s.rating.toStringAsFixed(1)} ★' : 'New',
            s.ratingCount > 0
                ? '${compactCount(s.ratingCount)} reviews'
                : 'No reviews yet',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab, required this.deals, required this.onSelect});

  final _Tab tab;
  final int deals;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(_Tab t, String label) {
      final bool on = t == tab;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(t),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: on ? kShopBlue : Colors.transparent, width: 3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              fontWeight: on ? FontWeight.w800 : FontWeight.w700,
              color: on ? kShopInk : kShopMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEF0F5)))),
      child: Row(
        children: <Widget>[
          item(_Tab.products, 'Products'),
          const SizedBox(width: 24),
          item(_Tab.deals, deals > 0 ? 'Deals ($deals)' : 'Deals'),
          const SizedBox(width: 24),
          item(_Tab.about, 'About'),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.total,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final int total;
  final List<ShopCategory> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget chip(String id, String label, int count) {
      final bool on = selected == id;
      return GestureDetector(
        onTap: () => onSelect(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF111111) : const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  color: on ? Colors.white70 : kShopMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          chip('', 'All', total),
          for (final ShopCategory c in categories) ...<Widget>[
            const SizedBox(width: 8),
            chip(c.id, c.name, c.count),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Text(
          title,
          style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kShopInk),
        ),
      );
}

class _DealsBanner extends StatelessWidget {
  const _DealsBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFFF3C4), Color(0xFFFFE184)]),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Deals from this shop',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kShopInk),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    count > 0
                        ? '$count products on offer right now'
                        : 'No offers right now — check back soon',
                    style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: Color(0xFF6B5A00)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.local_offer_rounded,
                size: 34, color: Color(0xFFB45309)),
          ],
        ),
      );
}

class _CategoryPictures extends StatelessWidget {
  const _CategoryPictures({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<ShopCategory> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          physics: const BouncingScrollPhysics(),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (BuildContext context, int i) {
            final ShopCategory c = categories[i];
            final bool on = c.id == selected;
            return GestureDetector(
              onTap: () => onSelect(c.id),
              child: SizedBox(
                width: 70,
                child: Column(
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 70,
                      height: 70,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: on
                            ? const Color(0xFFD8F4E8)
                            : const Color(0xFFF2F3F6),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: c.imageUrl == null
                          ? null
                          : AppImage(
                              imageUrl: c.imageUrl!,
                              memCacheWidth: 240,
                              memCacheHeight: 240,
                              fit: BoxFit.contain,
                              placeholder: const SizedBox.shrink(),
                              errorWidget: const SizedBox.shrink(),
                            ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: on
                            ? const Color(0xFF0E7C66)
                            : const Color(0xFF8A8F98),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _About extends StatelessWidget {
  const _About({required this.p});

  final ShopProfile p;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF3FF),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 18, color: kShopBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label,
                        style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            color: kShopMuted)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: kShopInk,
                            height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        );
    final ShopSummary s = p.summary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (p.description != null) ...<Widget>[
            Text(
              p.description!,
              style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF374151)),
            ),
            const SizedBox(height: 18),
          ],
          if (s.vendorName.isNotEmpty)
            row(Icons.storefront_rounded, 'Seller', s.vendorName),
          if (p.address.isNotEmpty)
            row(Icons.location_on_rounded, 'Address', p.address),
          if (p.memberSince != null)
            row(Icons.calendar_month_rounded, 'On Dealkr since',
                '${p.memberSince}'),
          row(
            Icons.star_rounded,
            'Rating',
            s.ratingCount > 0
                ? '${s.rating.toStringAsFixed(1)} out of 5 · ${compactCount(s.ratingCount)} reviews'
                : 'No reviews yet',
          ),
          row(Icons.people_alt_rounded, 'Followers',
              compactCount(s.followerCount)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, this.compact = false});

  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding:
              EdgeInsets.symmetric(vertical: compact ? 40 : 0, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Could not load this shop',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kShopInk),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}
