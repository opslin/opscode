import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart'
    show splitNameAndVariant;

/// Defaults of the `brand_spotlight` section; every key is editable in the
/// dashboard theme builder. Products come from the section's product source:
/// the first one is the featured product, the rest are "more from the brand".
const Map<String, dynamic> kBrandSpotlightDefaults = <String, dynamic>{
  'brand_name': '',
  'brand_logo_url': '',
  'tagline': 'Limited Time Deals',
  'more_title': 'More Items From the Brand',
  'add_label': 'ADD',
  'bg_color': '#E6EEFB',
  'panel_color': '#FFFFFF',
  'featured_start_color': '#F3F7FF',
  'featured_end_color': '#D5E3FA',
  'accent_color': '#E8175D',
  'text_color': '#111111',
  'muted_color': '#6B7280',
  'price_badge_color': '#FFE53B',
  'price_badge_text_color': '#111111',
  'off_text_color': '#2E8B2E',
};

String _rupees(double v) => formatRupees(v);

class BrandSpotlightSection extends StatelessWidget {
  const BrandSpotlightSection({
    required this.config,
    required this.products,
    super.key,
  });

  final Map<String, dynamic> config;
  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final Color bg = colorFrom(config, 'bg_color', const Color(0xFFE6EEFB));
    final Color panel = colorFrom(config, 'panel_color', Colors.white);
    final Color text = colorFrom(config, 'text_color', const Color(0xFF111111));
    final Color muted = colorFrom(
      config,
      'muted_color',
      const Color(0xFF6B7280),
    );
    final ProductEntity featured = products.first;
    final List<ProductEntity> more = products.skip(1).toList(growable: false);
    final String logo = stringFrom(config, 'brand_logo_url', '');
    final String brand = stringFrom(
      config,
      'brand_name',
      (featured.brand ?? '').trim(),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: logo.isEmpty
                      ? Center(
                          child: Text(
                            brand.isEmpty ? '' : brand[0].toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: text,
                            ),
                          ),
                        )
                      : AppImage(
                          imageUrl: logo,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          fit: BoxFit.contain,
                          placeholder: const SizedBox.shrink(),
                          errorWidget: const SizedBox.shrink(),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: text,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stringFrom(config, 'tagline', ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _FeaturedCard(product: featured, config: config),
                if (more.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  DashedDivider(color: muted.withValues(alpha: 0.35)),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      stringFrom(
                        config,
                        'more_title',
                        'More Items From the Brand',
                      ),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DealerProductRail(
                    products: more,
                    seeAllLabel: '',
                    seeAllRoute: null,
                    horizontalPadding: 0,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends ConsumerWidget {
  const _FeaturedCard({required this.product, required this.config});

  final ProductEntity product;
  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color text = colorFrom(config, 'text_color', const Color(0xFF111111));
    final Color muted = colorFrom(
      config,
      'muted_color',
      const Color(0xFF6B7280),
    );
    final Color accent = colorFrom(
      config,
      'accent_color',
      const Color(0xFFE8175D),
    );
    final Color badge = colorFrom(
      config,
      'price_badge_color',
      const Color(0xFFFFE53B),
    );
    final Color badgeText = colorFrom(
      config,
      'price_badge_text_color',
      const Color(0xFF111111),
    );
    final Color off = colorFrom(
      config,
      'off_text_color',
      const Color(0xFF2E8B2E),
    );
    final ({String name, String? variant}) split = splitNameAndVariant(
      product.name,
    );
    final String? option = product.optionLabel?.trim().isNotEmpty == true
        ? product.optionLabel
        : split.variant;
    final String unitLine = <String?>[
      product.unit.trim().isEmpty ? null : '1 ${product.unit.trim()}',
      option == null ? null : '($option)',
    ].whereType<String>().join(' ');
    final String? imageUrl = product.thumbnailUrl?.isNotEmpty == true
        ? product.thumbnailUrl
        : (product.images.isNotEmpty ? product.images.first : null);

    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              colorFrom(
                config,
                'featured_start_color',
                const Color(0xFFF3F7FF),
              ),
              colorFrom(config, 'featured_end_color', const Color(0xFFD5E3FA)),
            ],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 104,
              height: 112,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: imageUrl == null
                  ? null
                  : AppImage(
                      imageUrl: imageUrl,
                      memCacheWidth: 400,
                      memCacheHeight: 400,
                      fit: BoxFit.contain,
                      placeholder: const SizedBox.shrink(),
                      errorWidget: const SizedBox.shrink(),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    split.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: text,
                      height: 1.25,
                    ),
                  ),
                  if (unitLine.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      unitLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: badge,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black87,
                                    width: 1.2,
                                  ),
                                  boxShadow: const <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black87,
                                      offset: Offset(1.5, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _rupees(product.effectivePrice),
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: badgeText,
                                  ),
                                ),
                              ),
                              if (product.isOnSale) ...<Widget>[
                                const SizedBox(width: 8),
                                Text(
                                  _rupees(product.price),
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      if (product.isOnSale)
                        Text(
                          '${_rupees(product.discountAmount)} OFF',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: off,
                          ),
                        ),
                      const Spacer(),
                      AddPill(
                        product: product,
                        accent: accent,
                        label: stringFrom(config, 'add_label', 'ADD'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
