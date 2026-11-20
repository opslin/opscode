import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/features/shops/data/shop_summary.dart';
import 'package:dealker_app/features/shops/presentation/providers/shops_provider.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/wide_storefront_scope.dart';

/// Defaults of the `shops_nearby` section ("Shops (Nearby 12)"): a compact,
/// swipeable row of vendor shops with a one-tap Follow. Every key is editable
/// in the dashboard theme builder.
const Map<String, dynamic> kShopsNearbyDefaults = <String, dynamic>{
  'title': 'Shops',
  'view_all_label': 'View all →',
  'max_shops': 12,
  'bg_color': '#FFFFFF',
  'text_color': '#0F1E4D',
  'muted_color': '#6B7280',
  'accent_color': '#1D4ED8',
  'accent_soft_color': '#EEF3FF',
  'card_border_color': '#E7EEFB',
};

/// Shops without an uploaded logo get one of nine 3D storefronts, picked by a
/// stable hash of the shop id so a shop always keeps the same one.
Widget _shopArt(String id, {double size = 54}) {
  int h = 0;
  for (final int c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return Image.asset(
    'assets/shops/shop${h % 9 + 1}.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
  );
}

class ShopsNearbySection extends ConsumerStatefulWidget {
  const ShopsNearbySection({required this.config, super.key});

  final Map<String, dynamic> config;

  @override
  ConsumerState<ShopsNearbySection> createState() => _ShopsNearbySectionState();
}

class _ShopsNearbySectionState extends ConsumerState<ShopsNearbySection> {
  final ScrollController _scroll = ScrollController();
  double _page = 0;

  static const double _cardW = 118;
  static const double _gap = 10;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final double p = _scroll.offset / ((_cardW + _gap) * 3);
      if ((p - _page).abs() > 0.02) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> cfg = widget.config;
    final int limit =
        (cfg['max_shops'] is num ? (cfg['max_shops'] as num).toInt() : 12)
            .clamp(1, 30);
    final List<ShopSummary> shops =
        ref.watch(nearbyShopsProvider(limit)).asData?.value ??
            const <ShopSummary>[];
    if (shops.isEmpty) return const SizedBox.shrink();

    final Color bg = colorFrom(cfg, 'bg_color', Colors.white);
    final Color text = colorFrom(cfg, 'text_color', const Color(0xFF0F1E4D));
    final Color muted = colorFrom(cfg, 'muted_color', const Color(0xFF6B7280));
    final Color accent = colorFrom(
      cfg,
      'accent_color',
      const Color(0xFF1D4ED8),
    );
    final bool wideWeb = kIsWeb && WideStorefrontScope.isActive(context);
    final bool nearby = shops.any((ShopSummary s) => s.distanceKm != null);
    final int pages = (shops.length / 3).ceil().clamp(1, 6);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorFrom(cfg, 'card_border_color', const Color(0xFFE7EEFB)),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                Image.asset(
                  'assets/shops/shop1.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: stringFrom(cfg, 'title', 'Shops'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: text,
                          ),
                        ),
                        TextSpan(
                          text: nearby
                              ? '  (Nearby ${shops.length})'
                              : '  (${shops.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans'),
                  ),
                ),
                const Spacer(),
                if (stringFrom(cfg, 'view_all_label', '').isNotEmpty)
                  GestureDetector(
                    onTap: () => context.push('/shops'),
                    child: Text(
                      stringFrom(cfg, 'view_all_label', 'View all →'),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (wideWeb)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: LayoutBuilder(builder: (context, constraints) {
                final columns =
                    (constraints.maxWidth / 155).floor().clamp(2, 6);
                final width =
                    (constraints.maxWidth - _gap * (columns - 1)) / columns;
                return Wrap(spacing: _gap, runSpacing: _gap, children: [
                  for (var i = 0; i < shops.length; i++)
                    SizedBox(
                        height: 184,
                        width: width,
                        child: _ShopCard(
                            shop: shops[i],
                            index: i,
                            width: width,
                            config: cfg)),
                ]);
              }),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                physics: const BouncingScrollPhysics(),
                itemCount: shops.length,
                separatorBuilder: (_, __) => const SizedBox(width: _gap),
                itemBuilder: (BuildContext context, int i) => _ShopCard(
                  shop: shops[i],
                  index: i,
                  width: _cardW,
                  config: cfg,
                ),
              ),
            ),
          if (!wideWeb && pages > 1) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < pages; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _page.round().clamp(0, pages - 1) == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _page.round().clamp(0, pages - 1) == i
                          ? accent
                          : accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopCard extends ConsumerWidget {
  const _ShopCard({
    required this.shop,
    required this.index,
    required this.width,
    required this.config,
  });

  final ShopSummary shop;
  final int index;
  final double width;
  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color text = colorFrom(config, 'text_color', const Color(0xFF0F1E4D));
    final Color muted = colorFrom(
      config,
      'muted_color',
      const Color(0xFF6B7280),
    );
    final Color accent = colorFrom(
      config,
      'accent_color',
      const Color(0xFF1D4ED8),
    );
    final Color soft = colorFrom(
      config,
      'accent_soft_color',
      const Color(0xFFEEF3FF),
    );
    final bool following = ref.watch(
      shopFollowProvider.select(
        (Map<String, bool> m) => m[shop.id] ?? shop.isFollowing,
      ),
    );
    // "CityMobiles — Siliguri" reads better as "CityMobiles" (the city is shown below).
    final String title = shop.vendorName.isNotEmpty &&
            shop.name.toLowerCase().startsWith(shop.vendorName.toLowerCase())
        ? shop.vendorName
        : shop.name;
    final String sub = shop.distanceKm != null
        ? '${shop.distanceKm!.toStringAsFixed(1)} km'
        : (shop.city.isNotEmpty ? shop.city : '${shop.productCount} items');

    return GestureDetector(
      onTap: () => context.push('/shop/${shop.id}'),
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorFrom(
              config,
              'card_border_color',
              const Color(0xFFE7EEFB),
            ),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (shop.logoUrl != null)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFE3E8F3),
                        width: 1.2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AppImage(
                      imageUrl: shop.logoUrl!,
                      memCacheWidth: 200,
                      memCacheHeight: 200,
                      fit: BoxFit.cover,
                      placeholder: const SizedBox.shrink(),
                      errorWidget: _shopArt(shop.id),
                    ),
                  )
                else
                  _shopArt(shop.id),
                if (shop.isVerified)
                  Positioned(
                    right: -2,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: Color(0xFF001F5F),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: text,
              ),
            ),
            const SizedBox(height: 2),
            if (shop.ratingCount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    shop.rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: text,
                    ),
                  ),
                  const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: Color(0xFF14B8A6),
                  ),
                  Text(
                    ' (${compactCount(shop.ratingCount)})',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10.5,
                      color: muted,
                    ),
                  ),
                ],
              )
            else
              Text(
                'New on Dealkr',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            const SizedBox(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.location_on_rounded, size: 11, color: muted),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10.5,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  ref.read(shopFollowProvider.notifier).toggle(context, shop),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 26,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: following ? const Color(0xFFF1F3F8) : Colors.white,
                  border: Border.all(
                    color: following ? const Color(0xFFF1F3F8) : accent,
                    width: 1.3,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  following ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: following ? const Color(0xFF6B7280) : accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
