import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/features/shops/data/shop_summary.dart';
import 'package:dealker_app/features/shops/presentation/providers/shops_provider.dart';
import 'package:dealker_app/features/shops/presentation/widgets/shop_widgets.dart';
import 'package:dealker_app/shared/widgets/web_storefront_footer.dart';

enum _Filter { all, following, near, top }

class ShopsListScreen extends ConsumerStatefulWidget {
  const ShopsListScreen({super.key});

  @override
  ConsumerState<ShopsListScreen> createState() => _ShopsListScreenState();
}

class _ShopsListScreenState extends ConsumerState<ShopsListScreen> {
  _Filter _filter = _Filter.all;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ShopSummary>> async =
        ref.watch(nearbyShopsProvider(30));
    final Map<String, bool> follows = ref.watch(shopFollowProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 16, 4),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                          color: Color(0xFFF2F4F8), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: kShopInk),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Shops',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: kShopInk),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                onChanged: (String v) =>
                    setState(() => _q = v.trim().toLowerCase()),
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search shops',
                  hintStyle: const TextStyle(color: Color(0xFF8A8F98)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF8A8F98)),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F8),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  for (final (_Filter f, String label) in <(_Filter, String)>[
                    (_Filter.all, 'All'),
                    (_Filter.following, 'Following'),
                    (_Filter.near, 'Near me'),
                    (_Filter.top, 'Top rated'),
                  ]) ...<Widget>[
                    GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _filter == f
                              ? const Color(0xFF111111)
                              : const Color(0xFFF2F4F8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _filter == f
                                ? Colors.white
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const DealkerPageLoader(),
                error: (Object e, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(nearbyShopsProvider),
                    child: const Text('Could not load shops. Try again'),
                  ),
                ),
                data: (List<ShopSummary> all) {
                  List<ShopSummary> list = all.where((ShopSummary s) {
                    if (_q.isNotEmpty &&
                        !('${s.name} ${s.vendorName} ${s.city}'
                            .toLowerCase()
                            .contains(_q))) {
                      return false;
                    }
                    if (_filter == _Filter.following)
                      return follows[s.id] ?? s.isFollowing;
                    return true;
                  }).toList();
                  if (_filter == _Filter.near) {
                    list = list
                        .where((ShopSummary s) => s.distanceKm != null)
                        .toList()
                      ..sort((ShopSummary a, ShopSummary b) =>
                          a.distanceKm!.compareTo(b.distanceKm!));
                  } else if (_filter == _Filter.top) {
                    list = List<ShopSummary>.of(list)
                      ..sort((ShopSummary a, ShopSummary b) =>
                          b.rating.compareTo(a.rating));
                  }
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          switch (_filter) {
                            _Filter.following =>
                              'You are not following any shop yet',
                            _Filter.near =>
                              'Add a delivery address to see how far shops are',
                            _ => 'No shops found',
                          },
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13.5,
                              color: kShopMuted),
                        ),
                      ),
                    );
                  }
                  if (kIsWeb && MediaQuery.sizeOf(context).width >= 700) {
                    return LayoutBuilder(builder: (context, constraints) {
                      final inset = ((constraints.maxWidth - 1200) / 2)
                          .clamp(0.0, double.infinity);
                      return CustomScrollView(slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                              inset + 16, 16, inset + 16, 32),
                          sliver: SliverGrid.builder(
                            itemCount: list.length,
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 420,
                              mainAxisExtent: 100,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemBuilder: (context, i) => Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side:
                                    const BorderSide(color: Color(0xFFE8EBF0)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _Row(shop: list[i]),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: WebStorefrontFooter(onNavigate: context.go),
                        ),
                      ]);
                    });
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Color(0xFFF0F2F7)),
                    itemBuilder: (BuildContext context, int i) =>
                        _Row(shop: list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.shop});

  final ShopSummary shop;

  @override
  Widget build(BuildContext context) {
    final String sub = <String>[
      if (shop.vendorName.isNotEmpty && shop.vendorName != shopTitle(shop))
        'by ${shop.vendorName}',
      if (shop.distanceKm != null)
        '${shop.distanceKm!.toStringAsFixed(1)} km'
      else if (shop.city.isNotEmpty)
        shop.city,
    ].join(' · ');
    return InkWell(
      onTap: () => context.push('/shop/${shop.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            ShopAvatar(shop: shop, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          shopTitle(shop),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: kShopInk),
                        ),
                      ),
                      if (shop.isVerified) ...<Widget>[
                        const SizedBox(width: 4),
                        const VerifiedTick(size: 15)
                      ],
                    ],
                  ),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              color: kShopMuted)),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      if (shop.ratingCount > 0) ...<Widget>[
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFF14B8A6)),
                        const SizedBox(width: 2),
                        Text(
                          '${shop.rating.toStringAsFixed(1)} (${compactCount(shop.ratingCount)})',
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: kShopInk),
                        ),
                        const Text('  ·  ',
                            style: TextStyle(color: kShopMuted)),
                      ],
                      Text('${shop.productCount} products',
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              color: kShopMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ShopFollowButton(
                shop: shop, height: 32, minWidth: 92, fontSize: 12),
          ],
        ),
      ),
    );
  }
}
