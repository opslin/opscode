import 'dart:async';

import 'package:bakaloo_flutter_app/commerce/commerce_client.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:bakaloo_flutter_app/shared/widgets/arched_product_layouts.dart';
import 'package:bakaloo_flutter_app/shared/widgets/category_artwork.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';

import 'seasonal_deal_mosaic.dart';

part 'merchandising_widgets.dart';

const _motionAsset = 'assets/commerce/bakaloo-motion.json';

/// Adapts the published Bakaloo manifest to the standalone catalog.
class MerchandisingSection extends ConsumerWidget {
  const MerchandisingSection({
    super.key,
    required this.entry,
    required this.storefront,
    required this.onCategory,
    required this.onProduct,
  });

  final SectionManifestEntry entry;
  final Storefront storefront;
  final ValueChanged<String> onCategory;
  final ValueChanged<ProductEntity> onProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider) ?? storefront.products;
    final products = _products(catalog);
    final config = entry.config;
    final style = productCardVariantFromString(entry.productCardStyle);
    switch (entry.type) {
      case SectionType.animatedBanner:
        return _CampaignBanner(
          height: entry.height ?? 120,
          gradient: entry.gradient,
          image: publishedMediaUrl(entry.imageUrl),
          motion: (entry.lottieUrl ?? config['fallback_asset']) == _motionAsset,
        );
      case SectionType.roundCategoryIcons:
        return _categoryRail(config, catalog);
      case SectionType.seasonalMosaic:
        if (products.isEmpty) return const SizedBox.shrink();
        return _mosaic(products, catalog);
      case SectionType.categoryProductGrid:
        if (products.isEmpty) return const SizedBox.shrink();
        return _ManifestProductGridSection(
          title: entry.title ?? 'Products for you',
          products: products,
          columns: (entry.columns ?? 3).clamp(2, 3),
          variant: style,
          onProduct: onProduct,
        );
      case SectionType.productCarousel:
      case SectionType.trendingProducts:
        if (products.isEmpty) return const SizedBox.shrink();
        final trending = entry.type == SectionType.trendingProducts;
        return _ManifestHorizontalProductSection(
          title:
              entry.title ?? (trending ? 'Trending Near You' : 'Fresh picks'),
          products: products,
          accentColor: trending ? AppColors.primaryGreen : null,
          variant: style,
          onProduct: onProduct,
        );
      case SectionType.promoCarousel:
        final uploaded = publishedMediaUrl(entry.imageUrl);
        final configured = _strings(config['images'])
            .map(publishedMediaUrl)
            .nonNulls;
        final images =
            config['banner_source'] == 'custom' ||
                configured.isNotEmpty ||
                uploaded != null
            ? {...configured, ?uploaded}.toList(growable: false)
            : storefront.promos
                  .map((promo) => promo.image)
                  .toList(growable: false);
        if (images.isEmpty) return const SizedBox.shrink();
        return _ManifestPromoCarousel(
          items: [
            for (final image in images.take(5)) _PromoItem(imageUrl: image),
          ],
          borderRadius: (_number(config['border_radius']) ?? 18).clamp(0, 32),
          aspectRatio: _aspect(config['aspect_ratio']),
          autoScroll:
              config['auto_scroll'] != false &&
              !MediaQuery.disableAnimationsOf(context),
          autoScrollSpeedMs: (_number(config['auto_scroll_speed']) ?? 3000)
              .toInt(),
        );
      case SectionType.bankOffers:
        if (config['visible'] == false) return const SizedBox.shrink();
        final items = <_PromoItem>[
          for (final url in {
            ..._strings(config['image_urls']),
            ?entry.imageUrl,
          }.take(10))
            if (publishedMediaUrl(url) case final image?)
              _PromoItem(imageUrl: image),
        ];
        return items.isEmpty
            ? const SizedBox.shrink()
            : _ManifestBankOffersRow(items: items);
      case SectionType.archedProductShowcase:
        if (products.isEmpty) return const SizedBox.shrink();
        return _showcase(products, catalog);
      case SectionType.feeStrip:
      case SectionType.customBanner:
      case SectionType.textHeader:
      case SectionType.spacer:
        return const SizedBox.shrink();
    }
  }

  List<ProductEntity> _products(List<ProductEntity> catalog) {
    final binding = entry.merchBinding ?? const {};
    final productIds = _strings(binding['product_ids']);
    final categoryIds = _strings(binding['category_ids']).toSet();
    final tags = _strings(binding['tags'])
        .map((tag) => tag.toLowerCase())
        .toSet();
    final source = binding['source'];
    final candidates = catalog.where((product) => product.inStock);
    final byId = {for (final product in candidates) product.id: product};
    final selection = switch (source) {
      'manual' => productIds.map((id) => byId[id]).nonNulls,
      'tag' when tags.isNotEmpty => candidates.where(
        (product) =>
            product.tags.any((tag) => tags.contains(tag.toLowerCase())),
      ),
      'category' when categoryIds.isNotEmpty => candidates.where(
        (product) =>
            categoryIds.contains(product.categoryId) ||
            categoryIds.contains(product.category),
      ),
      _ => candidates,
    };
    return selection
        .take((entry.productLimit ?? 12).clamp(1, 200))
        .toList(growable: false);
  }

  List<DemoCategory> _categories() =>
      storefront.categories.where((category) => category.id != 'all').toList();

  DemoCategory? _findCategory(String? id, List<ProductEntity> catalog) {
    if (id == null) return null;
    final slug =
        catalog
            .where((product) => product.categoryId == id)
            .firstOrNull
            ?.category ??
        id;
    return _categories().where((category) => category.id == slug).firstOrNull;
  }

  Widget _categoryRail(
    Map<String, dynamic> config,
    List<ProductEntity> catalog,
  ) {
    final configured = _maps(config['items']).take(30);
    final defaults = _categories();
    final items = configured.isEmpty
        ? [
            for (final category in defaults)
              _CategoryRailItem(label: category.name, category: category),
          ]
        : [
            for (final item in configured)
              _CategoryRailItem(
                label:
                    _string(item['label']) ??
                    _findCategory(
                      _string(item['category_id']),
                      catalog,
                    )?.name ??
                    '',
                category: _findCategory(_string(item['category_id']), catalog),
                imageUrl: publishedMediaUrl(_string(item['image_url'])),
              ),
          ];
    return _ManifestCategoryRail(
      items: items,
      iconSize: (_number(config['icon_size']) ?? 64).clamp(40, 96),
      gap: (_number(config['gap']) ?? 12).clamp(4, 24),
      showLabels: config['show_labels'] != false,
      onCategory: onCategory,
    );
  }

  Widget _mosaic(List<ProductEntity> products, List<ProductEntity> catalog) {
    final config = entry.config;
    final fallback = SeasonalMosaicTheme.defaults();
    final hero = _map(config['hero_tile']);
    final mini = _maps(config['mini_tiles']).take(8).toList();
    return SeasonalDealMosaic(
      products: products,
      layoutVariant: entry.layoutVariant ?? 'hero_plus_four',
      mosaicTheme: SeasonalMosaicTheme(
        containerColor: _color(entry.containerColor) ?? fallback.containerColor,
        heroTile: HeroTileTheme(
          title:
              _string(hero['title'] ?? config['hero_title']) ??
              entry.title ??
              fallback.heroTile.title,
          gradient:
              _colors(hero['gradient'] ?? config['hero_gradient']) ??
              fallback.heroTile.gradient,
          badgeText:
              _string(hero['badge_text'] ?? config['hero_badge_text']) ??
              fallback.heroTile.badgeText,
          badgeGradient:
              _colors(hero['badge_gradient']) ??
              fallback.heroTile.badgeGradient,
          imageUrl: publishedMediaUrl(_string(hero['image_url'])),
          action: MosaicTileAction.fromJson(hero['action']),
        ),
        miniTiles: mini.isEmpty
            ? fallback.miniTiles
            : [
                for (var index = 0; index < mini.length; index++)
                  MiniTileTheme(
                    title:
                        _string(mini[index]['title']) ??
                        MiniTileTheme.defaults(index).title,
                    gradient:
                        _colors(mini[index]['gradient']) ??
                        MiniTileTheme.defaults(index).gradient,
                    imageUrl: publishedMediaUrl(
                      _string(mini[index]['image_url']),
                    ),
                    action: MosaicTileAction.fromJson(mini[index]['action']),
                  ),
              ],
      ),
      onTileTap: (action, fallbackId) {
        final selected = action?.type == 'category'
            ? _findCategory(action?.value, catalog)
            : null;
        if (selected case final category?) {
          onCategory(category.id);
          return;
        }
        final productId = action?.type == 'product'
            ? action?.value
            : fallbackId;
        final product = catalog
            .where((item) => item.id == productId)
            .firstOrNull;
        if (product != null) onProduct(product);
      },
    );
  }

  Widget _showcase(List<ProductEntity> products, List<ProductEntity> catalog) {
    final background = _color(entry.containerColor) ?? const Color(0xFFFDE7C4);
    final gradient = _colors(entry.bgGradient);
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: background,
        gradient: gradient == null ? null : LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry.showTitle)
            Text(
              entry.title ?? 'Top Picks',
              style: AppTextStyles.h2.copyWith(color: _color(entry.titleColor)),
            ),
          if (entry.archedBannerEnabled)
            _CampaignBanner(
              height: entry.archedBannerHeight,
              gradient: entry.archedBannerGradient,
              image: publishedMediaUrl(entry.archedBannerImageUrl),
              motion: entry.archedBannerLottieUrl == _motionAsset,
            ),
          if (entry.archedCategoryStripEnabled)
            _categoryRail(entry.archedCategoryStrip, catalog),
          Gap(10.h),
          buildArchedProductLayout(
            entry.productLayout,
            ArchedLayoutParams(
              products: products,
              backgroundColor: background,
              cardShape: entry.cardShape ?? 'arch',
              archHeight: (entry.archHeight ?? 14).clamp(0, 32),
              cornerRadius: (entry.cornerRadius ?? 24).clamp(8, 32),
              boxGradientColors: _colors(entry.boxGradient),
              onProductTap: onProduct,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignBanner extends StatelessWidget {
  const _CampaignBanner({
    required this.height,
    required this.gradient,
    this.image,
    this.motion = false,
  });

  final double height;
  final List<String> gradient;
  final String? image;
  final bool motion;

  @override
  Widget build(BuildContext context) => Container(
    height: height.clamp(60, 400).h,
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16.r),
      gradient: LinearGradient(
        colors:
            _colors(gradient) ?? const [Color(0xFFF3EEFE), Color(0xFFE2D6F9)],
      ),
    ),
    child: switch ((image, motion)) {
      (final url?, _) => AppImage(
        imageUrl: url,
        memCacheWidth: 960,
        memCacheHeight: 520,
      ),
      (_, true) => Lottie.asset(
        _motionAsset,
        animate: !MediaQuery.disableAnimationsOf(context),
      ),
      _ => null,
    },
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};
Iterable<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>() : const [];
Iterable<String> _strings(Object? value) =>
    value is Iterable ? value.whereType<String>() : const [];
String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
double? _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;

Color? _color(Object? value) {
  final hex = _string(value)?.replaceFirst('#', '') ?? '';
  final number = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
  return number == null ? null : Color(0xFF000000 | number);
}

List<Color>? _colors(Object? value) {
  final colors = _strings(value).map(_color).nonNulls.take(6).toList();
  return colors.length >= 2 ? colors : null;
}

double _aspect(Object? value) {
  final pair = _string(value)?.split(':');
  if (pair == null || pair.length != 2) return 16 / 9;
  final width = double.tryParse(pair.first);
  final height = double.tryParse(pair.last);
  if (width == null ||
      height == null ||
      !width.isFinite ||
      !height.isFinite ||
      height <= 0) {
    return 16 / 9;
  }
  return (width / height).clamp(.5, 3);
}
