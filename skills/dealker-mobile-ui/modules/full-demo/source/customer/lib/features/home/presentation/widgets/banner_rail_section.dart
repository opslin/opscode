import 'package:flutter/material.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Defaults of the `banner_rail` section: header artwork that fades into a
/// tinted panel holding the Dealkr product boxes and a See All button.
const Map<String, dynamic> kBannerRailDefaults = <String, dynamic>{
  'title': '',
  'header_image_url': '',
  'panel_color': '#DCE9F8',
  'title_color': '#111111',
  'see_all_label': 'See All',
};

class BannerRailSection extends StatelessWidget {
  const BannerRailSection({
    required this.config,
    required this.products,
    super.key,
  });

  final Map<String, dynamic> config;
  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final Color panel = colorFrom(
      config,
      'panel_color',
      const Color(0xFFDCE9F8),
    );
    final String image = stringFrom(config, 'header_image_url', '');
    final String title = stringFrom(config, 'title', '');
    final String? cat = products.first.categoryId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (image.isNotEmpty)
            AspectRatio(
              aspectRatio: 1148 / 360,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  AppImage(
                    imageUrl: image,
                    memCacheWidth: 1200,
                    memCacheHeight: 400,
                    placeholder: ColoredBox(color: panel),
                    errorWidget: ColoredBox(color: panel),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[panel.withValues(alpha: 0), panel],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colorFrom(
                    config,
                    'title_color',
                    const Color(0xFF111111),
                  ),
                ),
              ),
            ),
          SizedBox(height: image.isNotEmpty ? 2 : 12),
          DealerProductRail(
            products: products,
            seeAllLabel: stringFrom(config, 'see_all_label', 'See All'),
            seeAllRoute: (cat == null || cat.isEmpty)
                ? null
                : '/categories/$cat/products',
          ),
        ],
      ),
    );
  }
}
