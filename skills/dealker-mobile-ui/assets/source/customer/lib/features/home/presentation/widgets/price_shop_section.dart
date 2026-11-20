import 'package:flutter/material.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/features/products/data/models/product_model.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';

/// Defaults of the `price_shop` ("Shop by price") section; all keys editable in
/// the dashboard theme builder.
const Map<String, dynamic> kPriceShopDefaults = <String, dynamic>{
  'title': 'Shop by price',
  'badge_text': '',
  'see_all_label': 'See all',
  'empty_text': 'No products in this range yet',
  'bg_color': '#FFFFFF',
  'text_color': '#1F2937',
  'accent_color': '#2B2FD6',
  'pill_color': '#F0F0F0',
  'pill_selected_color': '#DDE6FF',
  'badge_bg_color': '#DDE6FF',
  'badge_text_color': '#2B2FD6',
  'indicator_color': '#1F1B3A',
};

class _PriceTab {
  const _PriceTab(this.label, this.value, this.categoryId, this.products);
  final String label;
  final String value;
  final String? categoryId;
  final List<ProductEntity> products;
}

List<_PriceTab> _parseTabs(Map<String, dynamic> config) {
  final Object? raw = config['tabs'];
  if (raw is! List) return const <_PriceTab>[];
  final List<_PriceTab> out = <_PriceTab>[];
  for (final Object? t in raw) {
    if (t is! Map) continue;
    final String label = '${t['label'] ?? ''}'.trim();
    final String value = '${t['sub_label'] ?? ''}'.trim();
    if (label.isEmpty && value.isEmpty) continue;
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
      _PriceTab(
        label,
        value,
        ids is List && ids.isNotEmpty ? '${ids.first}' : null,
        products,
      ),
    );
  }
  return out;
}

class PriceShopSection extends StatefulWidget {
  const PriceShopSection({required this.config, super.key});

  final Map<String, dynamic> config;

  @override
  State<PriceShopSection> createState() => _PriceShopSectionState();
}

class _PriceShopSectionState extends State<PriceShopSection> {
  int _tab = 0;

  static const double _pillW = 78;
  static const double _pillH = 76;
  static const double _gap = 10;
  static const double _lead = 14;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> cfg = widget.config;
    final List<_PriceTab> tabs = _parseTabs(cfg);
    if (tabs.isEmpty) return const SizedBox.shrink();
    final int index = _tab.clamp(0, tabs.length - 1);
    final _PriceTab tab = tabs[index];

    final Color bg = colorFrom(cfg, 'bg_color', Colors.white);
    final Color text = colorFrom(cfg, 'text_color', const Color(0xFF1F2937));
    final Color accent = colorFrom(
      cfg,
      'accent_color',
      const Color(0xFF2B2FD6),
    );
    final Color pill = colorFrom(cfg, 'pill_color', const Color(0xFFF0F0F0));
    final Color pillOn = colorFrom(
      cfg,
      'pill_selected_color',
      const Color(0xFFDDE6FF),
    );
    final Color indicator = colorFrom(
      cfg,
      'indicator_color',
      const Color(0xFF1F1B3A),
    );
    final String badge = stringFrom(cfg, 'badge_text', '');

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
                Text(
                  stringFrom(cfg, 'title', 'Shop by price'),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                if (badge.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorFrom(
                        cfg,
                        'badge_bg_color',
                        const Color(0xFFDDE6FF),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: colorFrom(
                          cfg,
                          'badge_text_color',
                          const Color(0xFF2B2FD6),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 1.2,
                    color: text.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: _pillH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _lead),
              physics: const BouncingScrollPhysics(),
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: _gap),
              itemBuilder: (BuildContext context, int i) {
                final bool on = i == index;
                final _PriceTab t = tabs[i];
                return GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    width: _pillW,
                    decoration: BoxDecoration(
                      color: on ? pillOn : pill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (t.label.isNotEmpty)
                          Text(
                            t.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              color: on ? accent : text,
                            ),
                          ),
                        if (t.value.isNotEmpty)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                t.value,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 22,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w800,
                                  color: on ? accent : text,
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
          const SizedBox(height: 8),
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
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  left: _lead + index * (_pillW + _gap) - 4,
                  bottom: 0,
                  width: _pillW + 8,
                  height: 3,
                  child: ColoredBox(color: indicator),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (tab.products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
              child: Center(
                child: Text(
                  stringFrom(
                    cfg,
                    'empty_text',
                    'No products in this range yet',
                  ),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: text.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            DealerProductRail(
              key: ValueKey<int>(index),
              products: tab.products,
              seeAllLabel: stringFrom(cfg, 'see_all_label', 'See all'),
              seeAllRoute: tab.categoryId == null
                  ? null
                  : '/categories/${tab.categoryId}/products',
            ),
        ],
      ),
    );
  }
}
