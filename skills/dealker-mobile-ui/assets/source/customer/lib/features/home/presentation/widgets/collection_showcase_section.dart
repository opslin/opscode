import 'package:flutter/material.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/features/products/data/models/product_model.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';

/// Defaults of the `collection_showcase` section (the "Rakhi Picks" style:
/// title artwork, text tabs, the Dealkr product box, See All). Every key is
/// editable in the dashboard theme builder.
const Map<String, dynamic> kCollectionShowcaseDefaults = <String, dynamic>{
  'title': 'Collection',
  'title_image_url': '',
  'subtitle': '',
  'see_all_label': 'See All',
  'empty_text': 'Nothing here yet',
  'bg_color': '#FFFFFF',
  'accent_color': '#B8863B',
  'accent_soft_color': '#FBEBCB',
  'text_color': '#2B2E4E',
  'muted_color': '#6F6F6F',
};

class _CollectionTab {
  const _CollectionTab(this.label, this.categoryId, this.products);
  final String label;
  final String? categoryId;
  final List<ProductEntity> products;
}

List<_CollectionTab> _parseTabs(Map<String, dynamic> config) {
  final Object? raw = config['tabs'];
  if (raw is! List) return const <_CollectionTab>[];
  final List<_CollectionTab> out = <_CollectionTab>[];
  for (final Object? t in raw) {
    if (t is! Map) continue;
    final String label = '${t['label'] ?? ''}'.trim();
    if (label.isEmpty) continue;
    final Object? ids = t['category_ids'];
    final String? categoryId =
        ids is List && ids.isNotEmpty ? '${ids.first}' : null;
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
    out.add(_CollectionTab(label, categoryId, products));
  }
  return out;
}

class CollectionShowcaseSection extends StatefulWidget {
  const CollectionShowcaseSection({required this.config, super.key});

  final Map<String, dynamic> config;

  @override
  State<CollectionShowcaseSection> createState() =>
      _CollectionShowcaseSectionState();
}

class _CollectionShowcaseSectionState extends State<CollectionShowcaseSection> {
  int _tab = 0;

  static const double _h = 44;
  static const double _lead = 14;
  static const double _padX = 18;
  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> cfg = widget.config;
    final List<_CollectionTab> tabs = _parseTabs(cfg);
    if (tabs.isEmpty) return const SizedBox.shrink();
    final int index = _tab.clamp(0, tabs.length - 1);
    final _CollectionTab tab = tabs[index];

    final Color bg = colorFrom(cfg, 'bg_color', Colors.white);
    final Color accent = colorFrom(
      cfg,
      'accent_color',
      const Color(0xFFB8863B),
    );
    final Color soft = colorFrom(
      cfg,
      'accent_soft_color',
      const Color(0xFFFBEBCB),
    );
    final Color text = colorFrom(cfg, 'text_color', const Color(0xFF2B2E4E));
    final Color muted = colorFrom(cfg, 'muted_color', const Color(0xFF6F6F6F));

    // Tab widths follow their labels, like the reference.
    final List<double> widths = tabs.map((_CollectionTab t) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: t.label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final double w = tp.width + _padX * 2;
      tp.dispose();
      return w;
    }).toList(growable: false);
    final List<double> lefts = <double>[];
    double x = _lead;
    for (final double w in widths) {
      lefts.add(x);
      x += w + _gap;
    }
    final double contentW = x - _gap + _lead;

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
          TabbedSectionHeader(
            title: stringFrom(cfg, 'title', 'Collection'),
            titleImageUrl: stringFrom(cfg, 'title_image_url', ''),
            subtitle: stringFrom(cfg, 'subtitle', ''),
            titleColor: accent,
            subtitleColor: text,
            titleSize: 22,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double w =
                  contentW < box.maxWidth ? box.maxWidth : contentW;
              return SizedBox(
                height: _h,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: w,
                    height: _h,
                    child: CustomPaint(
                      painter: TabStripPainter(
                        left: lefts[index],
                        width: widths[index],
                        accent: accent,
                        soft: soft,
                      ),
                      child: Stack(
                        children: <Widget>[
                          for (int i = 0; i < tabs.length; i++)
                            Positioned(
                              left: lefts[i],
                              top: 0,
                              width: widths[i],
                              height: _h,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _tab = i),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      tabs[i].label,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: i == index ? accent : text,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          if (tab.products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
              child: Center(
                child: Text(
                  stringFrom(cfg, 'empty_text', 'Nothing here yet'),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
            )
          else
            DealerProductRail(
              key: ValueKey<int>(index),
              products: tab.products,
              seeAllLabel: stringFrom(cfg, 'see_all_label', 'See All'),
              seeAllRoute: tab.categoryId == null
                  ? null
                  : '/categories/${tab.categoryId}/products',
            ),
        ],
      ),
    );
  }
}
