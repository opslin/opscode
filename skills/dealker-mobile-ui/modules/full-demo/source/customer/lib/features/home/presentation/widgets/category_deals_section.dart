import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/features/products/data/models/product_model.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Defaults of the `category_deals` section ("Crazy deals for home needs"):
/// title + See All, a row of category picture tiles (the picked one is mint),
/// a sliding underline, and the Dealkr product boxes of that category.
/// Every key is editable in the dashboard theme builder.
const Map<String, dynamic> kCategoryDealsDefaults = <String, dynamic>{
  'title': 'Crazy deals for you',
  'see_all_label': 'See All',
  'empty_text': 'No deals here yet',
  'bg_color': '#FFFFFF',
  'text_color': '#1B1B1B',
  'muted_color': '#8A8F98',
  'accent_color': '#0E7C66',
  'tile_color': '#F2F3F6',
  'tile_selected_color': '#D8F4E8',
  'indicator_color': '#0E7C66',
  'see_all_bg_color': '#F0FBF8',
};

class _CatTab {
  const _CatTab(this.label, this.imageUrl, this.categoryId, this.products);
  final String label;
  final String imageUrl;
  final String? categoryId;
  final List<ProductEntity> products;
}

List<_CatTab> _parseTabs(Map<String, dynamic> config) {
  final Object? raw = config['tabs'];
  if (raw is! List) return const <_CatTab>[];
  final List<_CatTab> out = <_CatTab>[];
  for (final Object? t in raw) {
    if (t is! Map) continue;
    final String label = '${t['label'] ?? ''}'.trim();
    if (label.isEmpty) continue;
    final Object? ids = t['category_ids'];
    final List<ProductEntity> products = <ProductEntity>[];
    final Object? rawProducts = t['products'];
    if (rawProducts is List) {
      for (final Object? p in rawProducts) {
        if (p is! Map) continue;
        try {
          products.add(
            ProductModel.fromJson(Map<String, dynamic>.from(p)).toEntity(),
          );
        } catch (_) {
          // One unparseable product must not blank the tab.
        }
      }
    }
    out.add(
      _CatTab(
        label,
        '${t['image_url'] ?? ''}'.trim(),
        ids is List && ids.isNotEmpty ? '${ids.first}' : null,
        products,
      ),
    );
  }
  return out;
}

class CategoryDealsSection extends StatefulWidget {
  const CategoryDealsSection({required this.config, super.key});

  final Map<String, dynamic> config;

  @override
  State<CategoryDealsSection> createState() => _CategoryDealsSectionState();
}

class _CategoryDealsSectionState extends State<CategoryDealsSection> {
  int _tab = 0;

  static const double _tileW = 76;
  static const double _gap = 14;
  static const double _lead = 14;
  static const Duration _fade = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> cfg = widget.config;
    final List<_CatTab> tabs = _parseTabs(cfg);
    if (tabs.isEmpty) return const SizedBox.shrink();
    final int index = _tab.clamp(0, tabs.length - 1);
    final _CatTab tab = tabs[index];

    final Color bg = colorFrom(cfg, 'bg_color', Colors.white);
    final Color text = colorFrom(cfg, 'text_color', const Color(0xFF1B1B1B));
    final Color muted = colorFrom(cfg, 'muted_color', const Color(0xFF8A8F98));
    final Color accent = colorFrom(
      cfg,
      'accent_color',
      const Color(0xFF0E7C66),
    );
    final Color tile = colorFrom(cfg, 'tile_color', const Color(0xFFF2F3F6));
    final Color tileOn = colorFrom(
      cfg,
      'tile_selected_color',
      const Color(0xFFD8F4E8),
    );
    final Color indicator = colorFrom(
      cfg,
      'indicator_color',
      const Color(0xFF0E7C66),
    );
    final String seeAll = stringFrom(cfg, 'see_all_label', 'See All');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    stringFrom(cfg, 'title', 'Crazy deals for you'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: text,
                      height: 1.15,
                    ),
                  ),
                ),
                if (seeAll.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.push(
                      tab.categoryId == null
                          ? '/categories'
                          : '/categories/${tab.categoryId}/products',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: colorFrom(
                          cfg,
                          'see_all_bg_color',
                          const Color(0xFFF0FBF8),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            seeAll,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _lead),
              physics: const BouncingScrollPhysics(),
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: _gap),
              itemBuilder: (BuildContext context, int i) {
                final bool on = i == index;
                final _CatTab t = tabs[i];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _tab = i),
                  child: SizedBox(
                    width: _tileW,
                    child: Column(
                      children: <Widget>[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: _tileW,
                          height: _tileW,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: on ? tileOn : tile,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: t.imageUrl.isEmpty
                              ? null
                              : AppImage(
                                  imageUrl: t.imageUrl,
                                  memCacheWidth: 300,
                                  memCacheHeight: 300,
                                  fit: BoxFit.contain,
                                  placeholder: const SizedBox.shrink(),
                                  errorWidget: const SizedBox.shrink(),
                                ),
                        ),
                        const SizedBox(height: 7),
                        // Labels may be a little wider than the tile (the gap absorbs it).
                        SizedBox(
                          height: 34,
                          child: OverflowBox(
                            maxWidth: _tileW + _gap,
                            alignment: Alignment.topCenter,
                            child: Text(
                              t.label,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight:
                                    on ? FontWeight.w800 : FontWeight.w500,
                                color: on ? accent : muted,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 3,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 1.2,
                  child: ColoredBox(color: text.withValues(alpha: 0.1)),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  left: _lead + index * (_tileW + _gap) - 4,
                  bottom: 0,
                  width: _tileW + 8,
                  height: 3,
                  child: ColoredBox(color: indicator),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: _fade,
            transitionBuilder: (Widget child, Animation<double> a) =>
                FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
            child: tab.products.isEmpty
                ? Padding(
                    key: ValueKey<String>('empty-$index'),
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 14,
                    ),
                    child: Center(
                      child: Text(
                        stringFrom(cfg, 'empty_text', 'No deals here yet'),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ),
                  )
                : DealerProductRail(
                    key: ValueKey<String>('rail-$index'),
                    products: tab.products,
                    seeAllLabel: '',
                    seeAllRoute: null,
                  ),
          ),
        ],
      ),
    );
  }
}
