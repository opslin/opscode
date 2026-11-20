import 'package:flutter/material.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/features/products/data/models/product_model.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Defaults of the `price_sale` section ("Daily Essentials Sale"): a banner
/// whose combo artwork and "flat ₹N" price change with the selected price box,
/// then the price boxes and the Dealkr product boxes. Every key is editable in
/// the dashboard theme builder.
const Map<String, dynamic> kPriceSaleDefaults = <String, dynamic>{
  'title': 'Daily Essentials Sale',
  'subtitle': 'Best brands at flat',
  'see_all_label': 'See all',
  'empty_text': 'No products in this range yet',
  'bg_color': '#FBF4C4',
  'title_color': '#7A4F0F',
  'subtitle_color': '#4A3A1A',
  'price_color': '#7A4F0F',
  'pill_color': '#FFFDF2',
  'pill_border_color': '#E6D79A',
  'pill_selected_color': '#FFFFFF',
  'pill_selected_border_color': '#C99A3B',
  'pill_halo_color': '#FFFFFF',
  'pill_text_color': '#B7762B',
  'indicator_color': '#2F4A2B',
};

class _SaleTab {
  const _SaleTab({
    required this.label,
    required this.value,
    required this.priceText,
    required this.left,
    required this.right,
    required this.categoryId,
    required this.products,
  });
  final String label;
  final String value;
  final String priceText;
  final String left;
  final String right;
  final String? categoryId;
  final List<ProductEntity> products;
}

List<_SaleTab> _parseTabs(Map<String, dynamic> config) {
  final Object? raw = config['tabs'];
  if (raw is! List) return const <_SaleTab>[];
  final List<_SaleTab> out = <_SaleTab>[];
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
    final String priceText = '${t['price_text'] ?? ''}'.trim();
    out.add(
      _SaleTab(
        label: label,
        value: value,
        priceText: priceText.isEmpty ? value : priceText,
        left: '${t['header_left_url'] ?? ''}'.trim(),
        right: '${t['header_right_url'] ?? ''}'.trim(),
        categoryId: ids is List && ids.isNotEmpty ? '${ids.first}' : null,
        products: products,
      ),
    );
  }
  return out;
}

class PriceSaleSection extends StatefulWidget {
  const PriceSaleSection({required this.config, super.key});

  final Map<String, dynamic> config;

  @override
  State<PriceSaleSection> createState() => _PriceSaleSectionState();
}

class _PriceSaleSectionState extends State<PriceSaleSection> {
  int _tab = 0;

  static const double _pillW = 84;
  static const double _pillH = 84;
  static const double _gap = 10;
  static const double _lead = 14;
  static const Duration _fade = Duration(milliseconds: 380);

  Widget _art(String url, bool left) {
    if (url.isEmpty) return const SizedBox.shrink();
    return AppImage(
      key: ValueKey<String>(url),
      imageUrl: url,
      memCacheWidth: 500,
      memCacheHeight: 400,
      fit: BoxFit.contain,
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      placeholder: const SizedBox.shrink(),
      errorWidget: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> cfg = widget.config;
    final List<_SaleTab> tabs = _parseTabs(cfg);
    if (tabs.isEmpty) return const SizedBox.shrink();
    final int index = _tab.clamp(0, tabs.length - 1);
    final _SaleTab tab = tabs[index];

    final Color bg = colorFrom(cfg, 'bg_color', const Color(0xFFFBF4C4));
    final Color titleC = colorFrom(cfg, 'title_color', const Color(0xFF7A4F0F));
    final Color subC = colorFrom(
      cfg,
      'subtitle_color',
      const Color(0xFF4A3A1A),
    );
    final Color priceC = colorFrom(cfg, 'price_color', const Color(0xFF7A4F0F));
    final Color pill = colorFrom(cfg, 'pill_color', const Color(0xFFFFFDF2));
    final Color pillBorder = colorFrom(
      cfg,
      'pill_border_color',
      const Color(0xFFE6D79A),
    );
    final Color pillOn = colorFrom(cfg, 'pill_selected_color', Colors.white);
    final Color pillOnBorder = colorFrom(
      cfg,
      'pill_selected_border_color',
      const Color(0xFFC99A3B),
    );
    final Color halo = colorFrom(cfg, 'pill_halo_color', Colors.white);
    final Color pillText = colorFrom(
      cfg,
      'pill_text_color',
      const Color(0xFFB7762B),
    );
    final Color indicator = colorFrom(
      cfg,
      'indicator_color',
      const Color(0xFF2F4A2B),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 92,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 78,
                  child: AnimatedSwitcher(
                    duration: _fade,
                    child: _art(tab.left, true),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          stringFrom(cfg, 'title', 'Daily Essentials Sale'),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: titleC,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              stringFrom(cfg, 'subtitle', ''),
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: subC,
                              ),
                            ),
                            const SizedBox(width: 5),
                            // The number slides up when the price box changes.
                            AnimatedSwitcher(
                              duration: _fade,
                              transitionBuilder:
                                  (Widget child, Animation<double> a) {
                                final bool incoming = child.key ==
                                    ValueKey<String>(tab.priceText);
                                return ClipRect(
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(0, incoming ? 1 : -1),
                                      end: Offset.zero,
                                    ).animate(a),
                                    child: FadeTransition(
                                      opacity: a,
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                tab.priceText,
                                key: ValueKey<String>(tab.priceText),
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: priceC,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 78,
                  child: AnimatedSwitcher(
                    duration: _fade,
                    child: _art(tab.right, false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
                final _SaleTab t = tabs[i];
                return GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  // Outer halo (the "box inside a box" of the selected price) + the box.
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _pillW,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: on
                          ? halo.withValues(alpha: 0.75)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        color: on ? pillOn : pill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: on ? pillOnBorder : pillBorder,
                          width: on ? 2 : 1,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: pillText.withValues(alpha: on ? 0.22 : 0.1),
                            blurRadius: on ? 10 : 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
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
                                fontWeight: FontWeight.w800,
                                color: pillText,
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: pillText,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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
                  child: ColoredBox(color: titleC.withValues(alpha: 0.15)),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
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
          // Products cross-fade (and drift in) when the price box changes.
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
                        stringFrom(
                          cfg,
                          'empty_text',
                          'No products in this range yet',
                        ),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subC.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  )
                : DealerProductRail(
                    key: ValueKey<String>('rail-$index'),
                    products: tab.products,
                    seeAllLabel: stringFrom(cfg, 'see_all_label', 'See all'),
                    seeAllRoute: tab.categoryId == null
                        ? null
                        : '/categories/${tab.categoryId}/products',
                  ),
          ),
        ],
      ),
    );
  }
}
