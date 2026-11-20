import 'package:dealker_app/shared/utils/link_tap_handler.dart';

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/core/theme/app_text_styles.dart';
import 'package:dealker_app/core/theme/remote_theme_model.dart';
import 'package:dealker_app/core/theme/remote_theme_provider.dart';
import 'package:dealker_app/core/theme/section_manifest_model.dart';
import 'package:dealker_app/features/categories/domain/entities/category_entity.dart';
import 'package:dealker_app/features/categories/presentation/providers/category_provider.dart';
import 'package:dealker_app/features/home/domain/entities/banner_entity.dart';
import 'package:dealker_app/features/home/presentation/providers/banner_provider.dart';
import 'package:dealker_app/features/home/presentation/providers/home_provider.dart';
import 'package:dealker_app/features/home/presentation/widgets/animated_banner_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/banner_rail_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/brand_spotlight_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/category_deals_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/category_hub_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/oval_spotlight_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/price_sale_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/price_shop_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/collection_showcase_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/custom_banner_section.dart';
// PHASE 2C: Import memoized pool provider from dedicated provider file.
import 'package:dealker_app/features/home/presentation/providers/home_product_pool_provider.dart';
import 'package:dealker_app/features/home/presentation/providers/manual_products_provider.dart';
import 'package:dealker_app/features/home/presentation/widgets/dealer_blocks.dart';
import 'package:dealker_app/features/home/presentation/widgets/seasonal_deal_mosaic.dart';
import 'package:dealker_app/features/home/presentation/widgets/shops_nearby_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/spacer_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/top_brands_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/steal_deals_section.dart';
import 'package:dealker_app/features/home/presentation/widgets/text_header_section.dart';
import 'package:dealker_app/features/products/data/models/product_model.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/arched_product_layouts.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';
import 'package:dealker_app/shared/widgets/dealker_product_grid.dart';
import 'package:dealker_app/shared/widgets/product_card.dart';
import 'package:dealker_app/features/products/presentation/widgets/show_product_options.dart';

typedef SectionBuilder = Widget Function(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
);

double _horizontalSectionExtent(
  int index,
  int itemCount,
  double itemWidth,
  double separatorWidth,
) {
  if (itemCount <= 1 || index == itemCount - 1) {
    return itemWidth;
  }
  return itemWidth + separatorWidth;
}

final Map<SectionType, SectionBuilder> sectionRegistry =
    <SectionType, SectionBuilder>{
  SectionType.animatedBanner: _buildAnimatedBanner,
  SectionType.feeStrip: _buildFeeStrip,
  SectionType.seasonalMosaic: _buildSeasonalMosaic,
  SectionType.roundCategoryIcons: _buildRoundCategoryIcons,
  SectionType.categoryProductGrid: _buildCategoryProductGrid,
  SectionType.productCarousel: _buildProductCarousel,
  SectionType.trendingProducts: _buildTrendingProducts,
  SectionType.promoCarousel: _buildPromoCarousel,
  SectionType.bankOffers: _buildBankOffers,
  SectionType.customBanner: _buildCustomBanner,
  SectionType.textHeader: _buildTextHeader,
  SectionType.archedProductShowcase: _buildArchedProductShowcase,
  SectionType.spacer: _buildSpacer,
  SectionType.liveAuction: _buildLiveAuction,
  SectionType.dealOfDay: _buildDealOfDay,
  SectionType.recentRecommended: _buildRecentRecommended,
  SectionType.stealDeals: _buildStealDeals,
  SectionType.collectionShowcase: _buildCollectionShowcase,
  SectionType.brandSpotlight: _buildBrandSpotlight,
  SectionType.priceShop: _buildPriceShop,
  SectionType.categoryHub: _buildCategoryHub,
  SectionType.bannerRail: _buildBannerRail,
  SectionType.topBrands: _buildTopBrands,
  SectionType.priceSale: _buildPriceSale,
  SectionType.ovalSpotlight: _buildOvalSpotlight,
  SectionType.categoryDeals: _buildCategoryDeals,
  SectionType.shopsNearby: _buildShopsNearby,
};

Widget _buildShopsNearby(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    ShopsNearbySection(
      config: <String, dynamic>{...kShopsNearbyDefaults, ...entry.config},
    );

Widget _buildCategoryDeals(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    CategoryDealsSection(
      config: <String, dynamic>{...kCategoryDealsDefaults, ...entry.config},
    );

Widget _buildOvalSpotlight(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    OvalSpotlightSection(
      config: <String, dynamic>{...kOvalSpotlightDefaults, ...entry.config},
      products: _resolveProducts(ref, entry, fallbackLimit: 12),
    );

Widget _buildPriceSale(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    PriceSaleSection(
      config: <String, dynamic>{...kPriceSaleDefaults, ...entry.config},
    );

Widget _buildTopBrands(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    TopBrandsSection(
      config: <String, dynamic>{...kTopBrandsDefaults, ...entry.config},
    );

Widget _buildPriceShop(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    PriceShopSection(
      config: <String, dynamic>{...kPriceShopDefaults, ...entry.config},
    );

Widget _buildCategoryHub(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    CategoryHubSection(
      config: <String, dynamic>{...kCategoryHubDefaults, ...entry.config},
    );

Widget _buildBannerRail(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    BannerRailSection(
      config: <String, dynamic>{...kBannerRailDefaults, ...entry.config},
      products: _resolveProducts(ref, entry, fallbackLimit: 12),
    );

Widget _buildBrandSpotlight(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    BrandSpotlightSection(
      config: <String, dynamic>{...kBrandSpotlightDefaults, ...entry.config},
      products: _resolveProducts(ref, entry, fallbackLimit: 12),
    );

Widget _buildCollectionShowcase(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    CollectionShowcaseSection(
      config: <String, dynamic>{
        ...kCollectionShowcaseDefaults,
        ...entry.config
      },
    );

Widget _buildStealDeals(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    StealDealsSection(
      config: <String, dynamic>{...kStealDealsDefaults, ...entry.config},
    );

Widget _buildLiveAuction(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    LiveAuctionSection(
      config: <String, dynamic>{...kLiveAuctionDefaults, ...entry.config},
    );

Widget _buildDealOfDay(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    DealOfDaySection(
      config: <String, dynamic>{
        ...kDealOfDayDefaults,
        ...entry.config,
        // A live deal attached in Deals & Merchandising drives the timer.
        if (entry.dealEndsAt != null)
          'ends_at': entry.dealEndsAt!.toUtc().toIso8601String(),
      },
      products: _resolveProducts(ref, entry, fallbackLimit: 1),
    );

Widget _buildRecentRecommended(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) =>
    RecentRecommendedSection(
      config: <String, dynamic>{...kRecentRecommendedDefaults, ...entry.config},
      products: _resolveProducts(ref, entry, fallbackLimit: 3),
    );

Widget _buildAnimatedBanner(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final fallback = theme.sections.bannerAnimation;
  return AnimatedBannerSection(
    // No local fallback asset — if the dashboard doesn't configure a remote
    // lottie/image URL, the banner renders only the gradient background.
    assetPath: _readString(entry.config['fallback_asset']) ?? '',
    height: entry.height ?? 120,
    linkUrl: _readString(entry.config['link_url']),
    bannerTheme: BannerAnimationTheme(
      imageUrl: entry.imageUrl ?? fallback.imageUrl,
      lottieUrl: entry.lottieUrl ?? fallback.lottieUrl,
      backgroundGradient: _resolveGradient(
        entry.config['gradient'],
        fallback.backgroundGradient,
      ),
      containerColor: _resolveColor(
        entry.containerColor,
        fallback.containerColor,
      ),
    ),
    feeStripTheme: const FeeStripTheme(imageUrl: null, visible: false),
  );
}

Widget _buildFeeStrip(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final List<String> feeLines = _readStringList(entry.config['lines']);
  if (feeLines.isNotEmpty) {
    return _FeeStripCard(
      title: _readString(entry.config['title']) ?? '',
      lines: feeLines,
      footnote: _readString(entry.config['footnote']),
    );
  }
  return _ManifestFeeStrip(
    imageUrl: _readString(entry.config['image_url']) ??
        theme.sections.feeStrip.imageUrl,
    containerColor: _resolveColor(
      entry.containerColor,
      const Color(0xFFBFEFFF),
    ),
  );
}

Widget _buildSeasonalMosaic(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(ref, entry, fallbackLimit: 8);
  if (products.isEmpty) {
    return const SizedBox.shrink();
  }

  final fallback = theme.sections.seasonalMosaic;

  // V2: prefer the rich `hero_tile` object; fall back to legacy flat keys.
  final heroTileConfig = _asConfigMap(entry.config['hero_tile']);
  final heroGradient = _resolveGradient(
    heroTileConfig?['gradient'] ?? entry.config['hero_gradient'],
    fallback.heroTile.gradient,
  );
  final heroTheme = HeroTileTheme(
    title: _readString(heroTileConfig?['title']) ??
        _readString(entry.config['hero_title']) ??
        entry.title ??
        fallback.heroTile.title,
    gradient: heroGradient,
    badgeText: _readString(heroTileConfig?['badge_text']) ??
        _readString(entry.config['hero_badge_text']) ??
        fallback.heroTile.badgeText,
    badgeGradient: _resolveGradient(
      heroTileConfig?['badge_gradient'],
      fallback.heroTile.badgeGradient,
    ),
    imageUrl: _readString(heroTileConfig?['image_url']),
    action: MosaicTileAction.fromJson(heroTileConfig?['action']),
  );

  final miniTiles = _buildManifestMiniTiles(entry, fallback);

  final mosaicTheme = SeasonalMosaicTheme(
    containerColor: _resolveColor(
      entry.containerColor,
      fallback.containerColor,
    ),
    heroTile: heroTheme,
    miniTiles: miniTiles,
  );
  final heroCandidates = _mergeUniqueProducts(<List<ProductEntity>>[
    _resolveTrendingPool(ref),
    _resolveFeaturedPool(ref),
    products,
  ]);

  return SeasonalDealMosaic(
    products: products,
    heroCandidates: heroCandidates,
    mosaicTheme: mosaicTheme,
    layoutVariant: entry.layoutVariant ?? 'hero_plus_four',
  );
}

Map<String, dynamic>? _asConfigMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

/// Builds the mosaic mini tiles from the section config `mini_tiles` array,
/// falling back to the global preset tiles when the section has none (legacy).
List<MiniTileTheme> _buildManifestMiniTiles(
  SectionManifestEntry entry,
  SeasonalMosaicTheme fallback,
) {
  final raw = entry.config['mini_tiles'];
  if (raw is! List || raw.isEmpty) {
    return fallback.miniTiles;
  }

  return List<MiniTileTheme>.generate(raw.length, (int index) {
    final map = _asConfigMap(raw[index]) ?? <String, dynamic>{};
    final fb = fallback.miniTiles.isEmpty
        ? MiniTileTheme.defaults(index)
        : fallback.miniTiles[index % fallback.miniTiles.length];
    return MiniTileTheme(
      title: _readString(map['title']) ?? fb.title,
      gradient: _resolveGradient(map['gradient'], fb.gradient),
      imageUrl: _readString(map['image_url']),
      action: MosaicTileAction.fromJson(map['action']),
    );
  });
}

Widget _buildRoundCategoryIcons(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final List<_CategoryRailItem> configuredItems =
      _resolveConfiguredCategoryRailItems(ref, entry);
  final double iconSize = (_readDouble(entry.config['icon_size']) ??
          _readInt(entry.config['icon_size'])?.toDouble() ??
          64)
      .clamp(40, 96)
      .toDouble();
  final double gap = (_readDouble(entry.config['gap']) ??
          _readInt(entry.config['gap'])?.toDouble() ??
          12)
      .clamp(4, 24)
      .toDouble();
  final bool showLabels = _readBool(entry.config['show_labels']) ?? true;

  if (configuredItems.isNotEmpty) {
    return _ManifestCategoryRail(
      items: configuredItems,
      iconSize: iconSize,
      gap: gap,
      showLabels: showLabels,
    );
  }

  final categories = _resolveCategories(ref, entry);
  if (categories.isEmpty) {
    return const SizedBox.shrink();
  }

  return _ManifestCategoryRail(
    items: categories
        .map(
          (CategoryEntity category) => _CategoryRailItem(
            label: category.name,
            imageUrl: category.imageUrl,
            categoryId: category.id,
          ),
        )
        .toList(growable: false),
    iconSize: iconSize,
    gap: gap,
    showLabels: showLabels,
  );
}

Widget _buildCategoryProductGrid(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(ref, entry, fallbackLimit: 12);
  if (products.isEmpty) {
    return const SizedBox.shrink();
  }

  // The Dealkr card is a tall card: the grid is always two columns.
  const columns = 2;
  return _ManifestProductGridSection(
    title: entry.title ?? 'Products for you',
    // Render every product the manifest already resolved (already capped by
    // entry.productLimit server-side) — don't re-truncate to a fixed row
    // count here, or picks beyond 2 rows silently disappear.
    products: products,
    columns: columns,
    variant: productCardVariantFromString(entry.productCardStyle),
    // White full-width "View all" button under the grid (on by default, switchable
    // and re-wordable from the dashboard). Opens the section's category, else all.
    showViewAll: _readBool(entry.config['show_view_all_button']) ?? true,
    viewAllLabel: _readString(entry.config['view_all_label']) ?? 'View All',
    viewAllRoute: () {
      final List<String> ids = _readStringList(
        entry.merchBinding?['category_ids'],
      );
      return ids.isNotEmpty
          ? '/categories/${ids.first}/products'
          : '/categories';
    }(),
  );
}

Widget _buildProductCarousel(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(ref, entry, fallbackLimit: 10);
  if (products.isEmpty) {
    return const SizedBox.shrink();
  }

  final String? backgroundUrl = _readString(
    entry.config['background_image_url'],
  );
  final String? backgroundColorRaw = _readString(
    entry.config['background_color'],
  );
  return _ManifestHorizontalProductSection(
    title: entry.title ?? 'Top picks',
    products: products,
    variant: productCardVariantFromString(entry.productCardStyle),
    // Optional artwork behind the whole section (header graphic on top, cards in
    // the middle, same colour below). All keys are optional — without them the
    // section looks exactly as before.
    backgroundImageUrl: backgroundUrl,
    backgroundColor: backgroundColorRaw == null
        ? null
        : _resolveColor(backgroundColorRaw, Colors.transparent),
    showTitle: _readBool(entry.config['show_title']) ?? true,
    // White full-width "View all" button under the cards. On by default when the
    // section has a background image; always switchable from the dashboard.
    showViewAll: _readBool(entry.config['show_view_all_button']) ??
        (backgroundUrl != null && backgroundUrl.trim().isNotEmpty),
    viewAllLabel: _readString(entry.config['view_all_label']) ?? 'View all',
    viewAllRoute: () {
      final List<String> ids = _readStringList(
        entry.merchBinding?['category_ids'],
      );
      return ids.isNotEmpty
          ? '/categories/${ids.first}/products'
          : '/categories';
    }(),
    titleColor: _readString(entry.config['title_color']) == null
        ? null
        : _resolveColor(_readString(entry.config['title_color']), Colors.black),
    topSpace: _readDouble(entry.config['top_space']),
    bottomSpace: _readDouble(entry.config['bottom_space']),
    borderRadius: _readDouble(entry.config['border_radius']) ?? 16,
  );
}

Widget _buildTrendingProducts(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(
    ref,
    entry,
    fallbackProducts: _resolveTrendingPool(ref),
    fallbackLimit: 8,
  );
  if (products.isEmpty) {
    return const SizedBox.shrink();
  }

  return _ManifestHorizontalProductSection(
    title: entry.title ?? 'Trending Near You',
    products: products,
    accentColor: const Color(0xFF0D8320),
    variant: productCardVariantFromString(entry.productCardStyle),
    // White full-width "View All" button under the shelf (on by default; switch
    // and wording come from the dashboard). Opens the section's category, else all.
    showViewAll: _readBool(entry.config['show_view_all_button']) ?? true,
    viewAllLabel: _readString(entry.config['view_all_label']) ?? 'View All',
    viewAllRoute: () {
      final List<String> ids = _readStringList(
        entry.merchBinding?['category_ids'],
      );
      return ids.isNotEmpty
          ? '/categories/${ids.first}/products'
          : '/categories';
    }(),
  );
}

Widget _buildPromoCarousel(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final items = _resolvePromoItems(ref, entry);
  if (items.isEmpty) {
    return const SizedBox.shrink();
  }

  return _ManifestPromoCarousel(
    items: items,
    borderRadius: _readDouble(entry.config['border_radius']) ?? 12,
    // The home hero always uses the design's wide 870:382 shape. The builder's
    // `aspect_ratio` value (often a tall default like 4:5) must NOT resize it.
    autoScroll: _readBool(entry.config['auto_scroll']) ?? true,
    autoScrollSpeedMs: _readInt(entry.config['auto_scroll_speed']) ?? 3000,
  );
}

Widget _buildBankOffers(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final List<String> configuredUrls = _readStringList(
    entry.config['image_urls'],
  );
  final String? legacyUrl = _readString(entry.config['image_url']);
  final List<String> urls = configuredUrls.isNotEmpty
      ? configuredUrls
      : legacyUrl != null && legacyUrl.trim().isNotEmpty
          ? <String>[legacyUrl]
          : theme.sections.bankOffers.bannerImageUrls;
  final items = urls
      .take(10)
      .map(
        (String url) => _PromoItem(
          imageUrl: url,
          linkUrl: _readString(entry.config['link_url']),
        ),
      )
      .where((item) => item.imageUrl.trim().isNotEmpty)
      .toList(growable: false);
  if (items.isEmpty) {
    return const SizedBox.shrink();
  }

  return _ManifestBankOffersRow(items: items);
}

Widget _buildCustomBanner(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  return CustomBannerSection(
    imageUrl: entry.imageUrl,
    linkUrl: _readString(entry.config['link_url']),
    borderRadius: _readDouble(entry.config['border_radius']) ?? 12,
    aspectRatio: _parseAspectRatio(entry.config['aspect_ratio']),
  );
}

Widget _buildTextHeader(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  return TextHeaderSection(
    text: _readString(entry.config['text']) ??
        entry.title ??
        theme.meta.seasonLabel,
    fontSize: _readDouble(entry.config['font_size']) ?? 18,
    color: _readString(entry.config['color']) ?? '#000000',
    alignment: _readString(entry.config['alignment']) ?? 'left',
  );
}

Widget _buildSpacer(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  return SpacerSection(height: entry.height ?? 16);
}

List<CategoryEntity> _resolveCategories(
  WidgetRef ref,
  SectionManifestEntry entry,
) {
  final categoriesAsync = ref.watch(categoryCollectionProvider);
  final categories = categoriesAsync.asData?.value ?? const <CategoryEntity>[];
  final activeCategories = categories.where((category) => category.isActive);
  final selectedIds = _readStringList(entry.merchBinding?['category_ids']);

  final List<CategoryEntity> preferred = selectedIds.isNotEmpty
      ? activeCategories
          .where(
            (category) =>
                selectedIds.contains(category.id) ||
                (category.parentId != null &&
                    selectedIds.contains(category.parentId)),
          )
          .toList(growable: false)
      : activeCategories
          .where((category) => category.isParent)
          .toList(growable: false);

  final result = (preferred.isNotEmpty
      ? preferred
      : activeCategories.toList(growable: false))
    ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  return result.take(10).toList(growable: false);
}

List<_CategoryRailItem> _resolveConfiguredCategoryRailItems(
  WidgetRef ref,
  SectionManifestEntry entry,
) {
  final dynamic rawItems = entry.config['items'];
  if (rawItems is! List) {
    return const <_CategoryRailItem>[];
  }

  final categoriesAsync = ref.watch(categoryCollectionProvider);
  final List<CategoryEntity> categories =
      categoriesAsync.asData?.value ?? const <CategoryEntity>[];
  final Map<String, CategoryEntity> categoryById = <String, CategoryEntity>{
    for (final CategoryEntity category in categories) category.id: category,
  };

  final List<_CategoryRailItem> items = <_CategoryRailItem>[];
  for (final dynamic rawItem in rawItems) {
    if (rawItem is! Map) {
      continue;
    }

    final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
    final String? categoryId = _readString(item['category_id']);
    final String? labelOverride = _readString(item['label']);
    final String? imageOverride = _readString(item['image_url']);
    final CategoryEntity? linkedCategory =
        categoryId == null ? null : categoryById[categoryId];
    final String? resolvedLabel = labelOverride ?? linkedCategory?.name;
    final String? resolvedImageUrl = imageOverride ?? linkedCategory?.imageUrl;

    if ((resolvedLabel == null || resolvedLabel.isEmpty) &&
        (resolvedImageUrl == null || resolvedImageUrl.isEmpty)) {
      continue;
    }

    items.add(
      _CategoryRailItem(
        label: resolvedLabel ?? 'Category',
        imageUrl: resolvedImageUrl,
        categoryId: categoryId,
      ),
    );
  }

  return items.take(10).toList(growable: false);
}

List<ProductEntity> _resolveProducts(
  WidgetRef ref,
  SectionManifestEntry entry, {
  List<ProductEntity>? fallbackProducts,
  int fallbackLimit = 6,
}) {
  final binding = entry.merchBinding ?? const <String, dynamic>{};
  final limit = entry.productLimit ?? fallbackLimit;

  // PRIMARY PATH: use the products the backend already resolved for this
  // section. The public section-manifest endpoint resolves `merch_binding`
  // (manual `product_ids` + optional category fill) server-side and returns
  // the ordered, stock-filtered product objects in `entry.products`. Preferring
  // them guarantees hand-picked grids render exactly what the dashboard pinned,
  // even when those products are not part of the home feed's product pool.
  //
  // Only clamp when the admin explicitly configured a limit for THIS
  // section (`entry.productLimit`). Falling back to the generic
  // `fallbackLimit` here — as this used to do — silently re-truncated an
  // already-complete, backend-resolved list, which was the root cause of
  // "some products in a category-linked section don't show up": the
  // backend correctly sent every product, but this widget only rendered
  // the first 6-12 of them.
  final List<ProductEntity> resolvedFromManifest = _parseManifestProducts(
    entry,
  );
  if (resolvedFromManifest.isNotEmpty) {
    return entry.productLimit != null
        ? resolvedFromManifest.take(entry.productLimit!).toList(growable: false)
        : resolvedFromManifest;
  }

  final source = _readString(binding['source']) ?? 'category';
  final basePool = fallbackProducts ?? _resolveDefaultProductPool(ref);

  if (source == 'manual') {
    final productIds = _readStringList(binding['product_ids']);
    if (productIds.isNotEmpty) {
      // First try to resolve from the already-loaded pool (fast path)
      final fromPool = _filterByIds(basePool, productIds);
      if (fromPool.length >= productIds.length) {
        // All products found in pool — use directly
        return fromPool.take(limit).toList(growable: false);
      }
      // Some products missing from pool — fetch them directly from API
      // This handles products from categories not loaded on the home feed
      final fetched = ref
          .watch(manualProductsByIdsProvider(productIds.join(',')))
          .asData
          ?.value;
      if (fetched != null && fetched.isNotEmpty) {
        return fetched.take(limit).toList(growable: false);
      }
      // Fall back to what we have from pool while API loads
      if (fromPool.isNotEmpty) {
        return fromPool.take(limit).toList(growable: false);
      }
    }
  }

  if (source == 'tag') {
    final tags = _readStringList(binding['tags']);
    final tagged = _filterByTags(basePool, tags);
    if (tagged.isNotEmpty) {
      return tagged.take(limit).toList(growable: false);
    }
  }

  final categoryIds = _readStringList(binding['category_ids']);
  if (categoryIds.isNotEmpty) {
    final scoped = <ProductEntity>[];
    for (final categoryId in categoryIds.take(4)) {
      final productsAsync = ref.watch(homeCategoryProductsProvider(categoryId));
      final categoryProducts =
          productsAsync.asData?.value ?? const <ProductEntity>[];
      scoped.addAll(categoryProducts.where((product) => product.inStock));
    }
    final merged = _mergeUniqueProducts(<List<ProductEntity>>[
      scoped,
      basePool,
    ]);
    if (merged.isNotEmpty) {
      return merged.take(limit).toList(growable: false);
    }
  }

  return basePool.take(limit).toList(growable: false);
}

/// Parses the server-resolved product objects attached to a section manifest
/// entry into [ProductEntity]s. Malformed individual records are skipped so a
/// single bad product never blanks the whole section.
List<ProductEntity> _parseManifestProducts(SectionManifestEntry entry) {
  if (entry.products.isEmpty) {
    return const <ProductEntity>[];
  }
  final List<ProductEntity> result = <ProductEntity>[];
  for (final Map<String, dynamic> raw in entry.products) {
    try {
      result.add(ProductModel.fromJson(raw).toEntity());
    } catch (_) {
      // Skip an unparseable product rather than failing the whole section.
    }
  }
  return result;
}

List<ProductEntity> _resolveDefaultProductPool(WidgetRef ref) {
  // PHASE 2C: Read from the memoized provider — computed once per Riverpod
  // build cycle instead of once per section builder call.
  return ref.watch(memoizedDefaultProductPoolProvider);
}

List<ProductEntity> _resolveFeaturedPool(WidgetRef ref) {
  // PHASE 2D: Re-use the memoized pool for featured — it already includes
  // tabHome.featuredProducts merged with homeFeaturedProductsProvider.
  // Filter to only featured/seasonal products to preserve current behaviour.
  final tabHome = ref.watch(selectedTabHomeContentProvider).asData?.value;
  final featured = ref.watch(homeFeaturedProductsProvider).asData?.value ??
      const <ProductEntity>[];
  // Only merge these two small lists; skip the full pool expansion.
  return _mergeUniqueProducts(<List<ProductEntity>>[
    tabHome?.featuredProducts ?? const <ProductEntity>[],
    featured,
  ]);
}

List<ProductEntity> _resolveTrendingPool(WidgetRef ref) {
  final tabHome = ref.watch(selectedTabHomeContentProvider).asData?.value;
  final trending = ref.watch(homeTrendingProductsProvider).asData?.value ??
      const <ProductEntity>[];
  // PHASE 2D: Merge only the two relevant lists; skip full pool re-merge.
  return _mergeUniqueProducts(<List<ProductEntity>>[
    tabHome?.trendingProducts ?? const <ProductEntity>[],
    trending,
  ]);
}

List<_PromoItem> _resolvePromoItems(WidgetRef ref, SectionManifestEntry entry) {
  // banner_source: "system" (default) → pull from live /banners API
  //               "custom"            → use inline images[] from config
  // Legacy sections without banner_source default to "system" for
  // backward compatibility (existing behaviour before this change).
  final String source = _readString(entry.config['banner_source']) ?? 'system';

  if (source == 'custom') {
    // ── Custom mode: use images[] from section config ──────────────────────
    final inlineImages = _readStringList(entry.config['images']);
    if (inlineImages.isNotEmpty) {
      return inlineImages
          .take(5)
          .map(
            (String imageUrl) => _PromoItem(
              imageUrl: imageUrl,
              linkUrl: _readString(entry.config['link_url']),
            ),
          )
          .where((item) => item.imageUrl.trim().isNotEmpty)
          .toList(growable: false);
    }
    // Also accept legacy single image_url if no images[] set yet
    if (entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty) {
      return <_PromoItem>[
        _PromoItem(
          imageUrl: entry.imageUrl!,
          linkUrl: _readString(entry.config['link_url']),
        ),
      ];
    }
    return const <_PromoItem>[];
  }

  // ── System mode (default): pull from bannerProvider ────────────────────
  final bannerAsync = ref.watch(bannerProvider);
  final banners = bannerAsync.asData?.value ?? const <BannerEntity>[];
  final sorted = List<BannerEntity>.from(banners)
    ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

  final items = sorted
      .where((BannerEntity banner) => banner.imageUrl.trim().isNotEmpty)
      .map(
        (BannerEntity banner) => _PromoItem(
          imageUrl: banner.imageUrl,
          linkUrl: _resolveBannerTarget(banner),
        ),
      )
      .toList(growable: false);

  if (items.isNotEmpty) {
    return items;
  }

  // ── Fallback (system mode, no live banners yet): try inline config ──────
  final inlineImages = _readStringList(entry.config['images']);
  if (inlineImages.isNotEmpty) {
    return inlineImages
        .map(
          (String imageUrl) => _PromoItem(
            imageUrl: imageUrl,
            linkUrl: _readString(entry.config['link_url']),
          ),
        )
        .toList(growable: false);
  }

  if (entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty) {
    return <_PromoItem>[
      _PromoItem(
        imageUrl: entry.imageUrl!,
        linkUrl: _readString(entry.config['link_url']),
      ),
    ];
  }

  return const <_PromoItem>[];
}

String? _resolveBannerTarget(BannerEntity banner) {
  final rawValue = banner.linkValue?.trim();
  if (rawValue == null || rawValue.isEmpty) {
    return null;
  }

  switch (banner.linkType.trim().toLowerCase()) {
    case 'product':
      return '/product/$rawValue';
    case 'category':
      return '/categories/$rawValue/products';
    default:
      return rawValue.startsWith('/') ? rawValue : rawValue;
  }
}

List<ProductEntity> _mergeUniqueProducts(List<List<ProductEntity>> groups) {
  final seen = <String>{};
  final seenFamilies = <String>{};
  final merged = <ProductEntity>[];
  for (final group in groups) {
    for (final product in group) {
      if (!product.inStock) {
        continue;
      }
      // Family-based deduplication: show only one representative per family.
      // Prefer the default option if it appears later.
      if (product.productFamilyId != null &&
          product.productFamilyId!.isNotEmpty) {
        if (!seenFamilies.add(product.productFamilyId!)) {
          // Family already represented — skip sibling.
          continue;
        }
      }
      if (seen.add(product.id)) {
        merged.add(product);
      }
    }
  }
  return merged;
}

List<ProductEntity> _filterByIds(
  List<ProductEntity> products,
  List<String> ids,
) {
  if (ids.isEmpty) {
    return const <ProductEntity>[];
  }
  return products
      .where((ProductEntity product) => ids.contains(product.id))
      .toList(growable: false);
}

List<ProductEntity> _filterByTags(
  List<ProductEntity> products,
  List<String> tags,
) {
  if (tags.isEmpty) {
    return const <ProductEntity>[];
  }
  final normalizedTags = tags.map((String tag) => tag.toLowerCase()).toSet();
  return products.where((ProductEntity product) {
    return product.tags.any(
      (String tag) => normalizedTags.contains(tag.toLowerCase()),
    );
  }).toList(growable: false);
}

String? _readString(dynamic value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

double? _readDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

bool? _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    if (value.trim().toLowerCase() == 'true') {
      return true;
    }
    if (value.trim().toLowerCase() == 'false') {
      return false;
    }
  }
  return null;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

double? _parseAspectRatio(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final normalized = value.trim();
    if (normalized.contains(':')) {
      final parts = normalized.split(':');
      if (parts.length == 2) {
        final width = double.tryParse(parts[0]);
        final height = double.tryParse(parts[1]);
        if (width != null && height != null && height > 0) {
          return width / height;
        }
      }
    }
    return double.tryParse(normalized);
  }
  return null;
}

Color _resolveColor(String? rawValue, Color fallback) {
  final normalized = rawValue?.trim();
  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }
  final cleaned = normalized.replaceFirst('#', '');
  final hex = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return fallback;
  }
  return Color(parsed);
}

List<Color> _resolveGradient(dynamic rawValue, List<Color> fallback) {
  if (rawValue is! List || rawValue.length < 2) {
    return fallback;
  }

  final first = _resolveColor(rawValue[0]?.toString(), fallback.first);
  final second = _resolveColor(rawValue[1]?.toString(), fallback.last);
  return <Color>[first, second];
}

PhosphorIconData _categoryIconForLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('fruit') || normalized.contains('vegetable')) {
    return PhosphorIcons.carrot;
  }
  if (normalized.contains('dairy') || normalized.contains('egg')) {
    return PhosphorIcons.egg;
  }
  if (normalized.contains('bakery') || normalized.contains('bread')) {
    return PhosphorIcons.bread;
  }
  if (normalized.contains('drink') || normalized.contains('juice')) {
    return PhosphorIcons.drop;
  }
  if (normalized.contains('electronics')) {
    return PhosphorIcons.headphones;
  }
  if (normalized.contains('beauty')) {
    return PhosphorIcons.sparkle;
  }
  if (normalized.contains('fresh')) {
    return PhosphorIcons.appleLogo;
  }
  return PhosphorIcons.squaresFour;
}

class _ManifestFeeStrip extends StatefulWidget {
  const _ManifestFeeStrip({required this.containerColor, this.imageUrl});

  final String? imageUrl;
  final Color containerColor;

  @override
  State<_ManifestFeeStrip> createState() => _ManifestFeeStripState();
}

class _ManifestFeeStripState extends State<_ManifestFeeStrip> {
  static const double _fallbackAspectRatio = 336 / 74;

  double _aspectRatio = _fallbackAspectRatio;
  String? _resolvedImageUrl;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _syncResolvedImage();
  }

  @override
  void didUpdateWidget(covariant _ManifestFeeStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _syncResolvedImage();
    }
  }

  @override
  void dispose() {
    _detachImageStream();
    super.dispose();
  }

  void _syncResolvedImage() {
    _detachImageStream();
    final rawValue = widget.imageUrl?.trim();
    final String? resolvedValue = rawValue == null || rawValue.isEmpty
        ? null
        : (ApiConstants.resolveMediaUrl(rawValue) ?? rawValue);
    _resolvedImageUrl = rawValue == null || rawValue.isEmpty
        ? null
        : (ApiConstants.proxyMediaUrl(resolvedValue) ?? resolvedValue);
    _aspectRatio = _fallbackAspectRatio;

    if (_resolvedImageUrl == null) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final ImageProvider provider = CachedNetworkImageProvider(
      _resolvedImageUrl!,
    );
    final ImageStream stream = provider.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool _) {
        final double width = image.image.width.toDouble();
        final double height = image.image.height.toDouble();
        final double nextAspectRatio =
            height == 0 ? _fallbackAspectRatio : width / height;
        _detachImageStream();
        if (!mounted) {
          return;
        }
        setState(() {
          _aspectRatio = nextAspectRatio.isFinite && nextAspectRatio > 0
              ? nextAspectRatio
              : _fallbackAspectRatio;
        });
      },
      onError: (_, __) {
        _detachImageStream();
        if (!mounted) {
          return;
        }
        setState(() {
          _aspectRatio = _fallbackAspectRatio;
        });
      },
    );

    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);

    if (mounted) {
      setState(() {});
    }
  }

  void _detachImageStream() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedImageUrl != null) {
      // Rounded card, inset from the screen edges (same side margin as the
      // home banner) with a gap above — sized to the image's own shape so the
      // artwork is neither letterboxed nor cropped.
      final double k = MediaQuery.sizeOf(context).width / 914;
      return Padding(
        padding: EdgeInsets.fromLTRB(22 * k, 10.h, 22 * k, 4.h),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final double safeAspectRatio =
                _aspectRatio.isFinite && _aspectRatio > 0
                    ? _aspectRatio
                    : _fallbackAspectRatio;
            final double targetHeight =
                (width / safeAspectRatio).clamp(40.h, 140.h).toDouble();

            return ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: SizedBox(
                height: targetHeight,
                width: double.infinity,
                child: ColoredBox(
                  color: widget.containerColor,
                  child: AppImage(
                    imageUrl: _resolvedImageUrl!,
                    memCacheWidth: 1200,
                    memCacheHeight: 333,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                    placeholder: ColoredBox(
                      color: widget.containerColor,
                      child: const SizedBox.expand(),
                    ),
                    errorWidget: const _FeeStripFallback(),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return const _FeeStripFallback();
  }
}

class _FeeStripFallback extends StatelessWidget {
  const _FeeStripFallback();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 2.h),
      child: Container(
        height: 42.h,
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1C9A38),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.ticketFill,
              color: Colors.white,
              size: 17.sp,
            ),
            Gap(8.w),
            Expanded(
              child: Text(
                '₹0 Platform Fee • ₹0 Delivery Fee',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManifestCategoryRail extends StatelessWidget {
  const _ManifestCategoryRail({
    required this.items,
    required this.iconSize,
    required this.gap,
    required this.showLabels,
  });

  final List<_CategoryRailItem> items;
  final double iconSize;
  final double gap;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final double tileWidth = (iconSize + 18).clamp(82, 120).toDouble();
    final double boxRadius = (iconSize * 0.34).clamp(16, 26).toDouble();
    final double artworkRadius = (boxRadius - 2).clamp(14, 24).toDouble();
    final double railHeight = showLabels ? iconSize + 40 : iconSize + 12;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 2.h),
      child: SizedBox(
        height: railHeight.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemExtentBuilder: (int index, _) =>
              _horizontalSectionExtent(index, items.length, tileWidth.w, gap.w),
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];
            return Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: item.categoryId == null
                    ? null
                    : () => context.push(
                          '/categories/${item.categoryId}/products',
                        ),
                child: SizedBox(
                  width: tileWidth.w,
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: iconSize.w,
                        height: iconSize.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(boxRadius.r),
                          border: Border.all(
                            color: const Color(0xFFF0F0F0),
                            width: 1,
                          ),
                          // PHASE 3D: Replace blurred shadow with a slightly
                          // stronger border. The category icon tiles are
                          // static — no need for blur rasterisation on each
                          // visible tile.
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 0,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(artworkRadius.r),
                          child: _CategoryArtwork(
                            label: item.label,
                            imageUrl: item.imageUrl,
                          ),
                        ),
                      ),
                      if (showLabels) ...<Widget>[
                        Gap(8.h),
                        Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: const Color(0xFF131313),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryArtwork extends StatelessWidget {
  const _CategoryArtwork({required this.label, required this.imageUrl});

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = ApiConstants.resolveMediaUrl(imageUrl);
    final optimizedImage = ApiConstants.optimizedMedia(
      resolvedImageUrl,
      profile: CustomerImageProfile.categoryTile,
    );

    if (resolvedImageUrl == null || resolvedImageUrl.isEmpty) {
      return ColoredBox(
        color: const Color(0xFFF3F6E7),
        child: Center(
          child: PhosphorIcon(
            _categoryIconForLabel(label),
            size: 24.sp,
            color: const Color(0xFF69705E),
          ),
        ),
      );
    }

    return AppImage(
      imageUrl: optimizedImage.url ?? resolvedImageUrl,
      fit: BoxFit.cover,
      memCacheWidth: optimizedImage.memCacheWidth,
      memCacheHeight: optimizedImage.memCacheHeight,
      filterQuality: FilterQuality.high,
      placeholder: const ColoredBox(
        color: Color(0xFFF3F6E7),
        child: SizedBox.expand(),
      ),
      errorWidget: ColoredBox(
        color: const Color(0xFFF3F6E7),
        child: Center(
          child: PhosphorIcon(
            _categoryIconForLabel(label),
            size: 24.sp,
            color: const Color(0xFF69705E),
          ),
        ),
      ),
    );
  }
}

class _CategoryRailItem {
  const _CategoryRailItem({
    required this.label,
    this.imageUrl,
    this.categoryId,
  });

  final String label;
  final String? imageUrl;
  final String? categoryId;
}

class _ManifestProductGridSection extends StatelessWidget {
  const _ManifestProductGridSection({
    required this.title,
    required this.products,
    required this.columns,
    this.variant = ProductCardVariant.quickCommerceCompact,
    this.showViewAll = false,
    this.viewAllLabel = 'View All',
    this.viewAllRoute = '/categories',
  });

  final String title;
  final List<ProductEntity> products;
  final int columns;
  final ProductCardVariant variant;
  final bool showViewAll;
  final String viewAllLabel;
  final String viewAllRoute;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
          child: _ManifestSectionHeader(title: title),
        ),
        Gap(10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const double gap = 12;
              final int count = productGridColumns(constraints.maxWidth, isWeb: kIsWeb);
              final double itemWidth =
                  (constraints.maxWidth - gap * (count - 1)) / count;
              final DealkerCardSlots slots = DealkerCardSlots.forProducts(
                products,
                itemWidth,
              );

              return Wrap(
                spacing: gap,
                runSpacing: 14,
                children: products
                    .map(
                      (ProductEntity product) => DealkerProductCard(
                        product: product,
                        width: itemWidth,
                        nameLines: slots.nameLines,
                        showSoldRow: slots.showSold,
                        showRatingRow: slots.showRating,
                        onTap: () => context.push('/product/${product.id}'),
                        onOptionsTap: product.hasMultipleOptions
                            ? () => showProductOptionsSheet(context, product)
                            : null,
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ),
        if (showViewAll) ...<Widget>[
          Gap(14.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              child: InkWell(
                borderRadius: BorderRadius.circular(12.r),
                onTap: () => context.push(viewAllRoute),
                child: SizedBox(
                  height: 44.h,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          viewAllLabel,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18.sp,
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Gap(8.h),
        ],
      ],
    );
  }
}

class _ManifestHorizontalProductSection extends StatelessWidget {
  const _ManifestHorizontalProductSection({
    required this.title,
    required this.products,
    this.accentColor,
    this.variant = ProductCardVariant.quickCommerceCompact,
    this.backgroundImageUrl,
    this.backgroundColor,
    this.showTitle = true,
    this.showViewAll = false,
    this.viewAllLabel = 'View all',
    this.viewAllRoute = '/categories',
    this.titleColor,
    this.topSpace,
    this.bottomSpace,
    this.borderRadius = 16,
  });

  final String title;
  final List<ProductEntity> products;
  final Color? accentColor;
  final ProductCardVariant variant;

  /// Artwork stretched behind the whole section (cover-fit, rounded).
  final String? backgroundImageUrl;
  final Color? backgroundColor;

  /// False hides the built-in title + "View All" (the artwork carries its own text).
  final bool showTitle;

  /// White full-width "View all" button under the cards.
  final bool showViewAll;
  final String viewAllLabel;
  final String viewAllRoute;

  /// Heading + "View All" colour. Unset: white on a background image, otherwise the
  /// section's normal styling.
  final Color? titleColor;

  /// Space above / below the product cards, in dashboard "points" (scaled like
  /// the cards). With a background they reserve room for the artwork.
  final double? topSpace;
  final double? bottomSpace;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final bool box = variant == ProductCardVariant.dealkerMarketplaceBox;
    // One Dealkr card design everywhere; width is ~60% of the screen so the next
    // card peeks in, height follows the card's fixed proportions (+ shadow room).
    final double cardWidth =
        (MediaQuery.sizeOf(context).width * 0.6).clamp(220.0, 280.0).toDouble();
    final DealkerCardSlots slots = DealkerCardSlots.forProducts(
      products,
      cardWidth,
    );
    final double cardHeight = slots.heightFor(cardWidth);
    final String? bgUrl = backgroundImageUrl?.trim();
    final bool hasImage = bgUrl != null && bgUrl.isNotEmpty;
    final bool hasBackground = hasImage || backgroundColor != null;

    final Color? headingColor = titleColor ?? (hasImage ? Colors.white : null);
    final Widget header = Padding(
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
      child: headingColor != null
          ? Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    box ? title.toUpperCase() : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h2.copyWith(
                      fontSize: box ? 15.sp : 18.sp,
                      fontWeight: FontWeight.w900,
                      color: headingColor,
                    ),
                  ),
                ),
                if (!showViewAll)
                  GestureDetector(
                    onTap: () => context.push('/categories'),
                    child: Text(
                      'View All →',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: headingColor,
                      ),
                    ),
                  ),
              ],
            )
          : box
              ? Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!showViewAll)
                      GestureDetector(
                        onTap: () => context.push('/categories'),
                        child: Text(
                          'View All →',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                  ],
                )
              : _ManifestSectionHeader(title: title, accentColor: accentColor),
    );

    final Widget list = SizedBox(
      height: cardHeight + 28,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        itemExtentBuilder: (int index, _) =>
            _horizontalSectionExtent(index, products.length, cardWidth, 12),
        itemBuilder: (BuildContext context, int index) {
          final product = products[index];
          return Align(
            alignment: Alignment.centerLeft,
            child: DealkerProductCard(
              product: product,
              width: cardWidth,
              nameLines: slots.nameLines,
              showSoldRow: slots.showSold,
              showRatingRow: slots.showRating,
              onTap: () => context.push('/product/${product.id}'),
              onOptionsTap: product.hasMultipleOptions
                  ? () => showProductOptionsSheet(context, product)
                  : null,
            ),
          );
        },
      ),
    );

    final double buttonHeight = 44.h;
    final double buttonGap = 12.h;
    final Widget viewAllButton = Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () => context.push(viewAllRoute),
          child: SizedBox(
            height: buttonHeight,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    viewAllLabel,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18.sp,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!hasBackground) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showTitle) ...<Widget>[header, Gap(10.h)] else Gap(4.h),
          if (topSpace != null && topSpace! > 0) Gap(topSpace!.h),
          list,
          if (showViewAll) ...<Widget>[Gap(buttonGap), viewAllButton],
          if (bottomSpace != null && bottomSpace! > 0) Gap(bottomSpace!.h),
        ],
      );
    }

    // Background mode: one artwork behind everything. The section is as tall as
    // the artwork itself (its whole picture is always visible, never cropped);
    // [topSpace] is where the cards start, and whatever is left below them is the
    // artwork's bottom zone. A [bottomSpace] minimum keeps room for the cards.
    final double top = (topSpace ?? 96).clamp(0, 400).toDouble();
    final double bottom = (bottomSpace ?? 14).clamp(0, 200).toDouble();
    final double listHeight = cardHeight + 28;
    final String? resolvedBg =
        hasImage ? (ApiConstants.resolveMediaUrl(bgUrl) ?? bgUrl) : null;

    Widget compose(double? aspect, Color? bottomColor) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double w = constraints.maxWidth;
          final double? imageHeight =
              (aspect != null && aspect > 0) ? w / aspect : null;
          // The artwork is shown whole at its own shape (scaled to the card's
          // width, never cropped or stretched). Cards start at [topSpace] — or,
          // if unset, 30% down the artwork. When the artwork is shorter than
          // the cards need, the section extends below it in the artwork's own
          // bottom colour (or the dashboard background colour).
          final double needed = listHeight +
              (showViewAll ? buttonGap + buttonHeight : 0) +
              bottom.h;
          final double wantedTop = topSpace != null
              ? top.h
              : (imageHeight == null
                  ? 96.h
                  : (imageHeight * 0.3).clamp(40.h, 160.h).toDouble());
          final double height;
          final double cardsTop;
          if (imageHeight == null) {
            height = wantedTop + needed;
            cardsTop = wantedTop;
          } else if (imageHeight >= wantedTop + needed) {
            height = imageHeight;
            cardsTop = wantedTop;
          } else {
            // Short artwork: grow below it; keep the cards where they were asked.
            height = wantedTop + needed;
            cardsTop = wantedTop;
          }
          final Color? fill = backgroundColor ?? bottomColor;
          return SizedBox(
            height: height,
            child: Stack(
              children: <Widget>[
                if (fill != null)
                  Positioned.fill(child: ColoredBox(color: fill)),
                if (resolvedBg != null && imageHeight != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: imageHeight,
                    child: AppImage(
                      imageUrl: resolvedBg,
                      memCacheWidth: 1600,
                      memCacheHeight: 1600,
                      fit: BoxFit.fill,
                      placeholder: const SizedBox.expand(),
                      errorWidget: const SizedBox.expand(),
                    ),
                  ),
                Positioned(
                  top: cardsTop,
                  left: 0,
                  right: 0,
                  height: listHeight,
                  child: list,
                ),
                if (showViewAll)
                  Positioned(
                    top: cardsTop + listHeight + buttonGap,
                    left: 0,
                    right: 0,
                    height: buttonHeight,
                    child: viewAllButton,
                  ),
                if (showTitle)
                  Positioned(top: 0, left: 0, right: 0, child: header),
              ],
            ),
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          borderRadius.clamp(0, 40).toDouble().r,
        ),
        child: resolvedBg == null
            ? compose(null, null)
            : _ImageAspectBuilder(url: resolvedBg, builder: compose),
      ),
    );
  }
}

/// Resolves a network image's natural width ÷ height and rebuilds [builder] with it
/// (null until known), so a section can be exactly as tall as its artwork.
class _ImageAspectBuilder extends StatefulWidget {
  const _ImageAspectBuilder({required this.url, required this.builder});

  final String url;
  final Widget Function(double? aspectRatio, Color? bottomColor) builder;

  @override
  State<_ImageAspectBuilder> createState() => _ImageAspectBuilderState();
}

class _ImageAspectBuilderState extends State<_ImageAspectBuilder> {
  double? _aspect;
  Color? _bottomColor;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _ImageAspectBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _aspect = null;
      _bottomColor = null;
      _resolve();
    }
  }

  void _resolve() {
    _detach();
    final ImageStream stream = CachedNetworkImageProvider(widget.url)
        .resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final double w = info.image.width.toDouble();
      final double h = info.image.height.toDouble();
      if (mounted && h > 0) setState(() => _aspect = w / h);
      unawaited(_sampleBottomColor(info.image));
      _detach();
    }, onError: (Object _, StackTrace? __) => _detach());
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  /// Average colour of the artwork's bottom edge — used to extend the section
  /// seamlessly below a short image.
  Future<void> _sampleBottomColor(ui.Image image) async {
    try {
      final ByteData? data = await image.toByteData();
      if (data == null || !mounted) return;
      final int w = image.width;
      final int h = image.height;
      final int row = (h - 2).clamp(0, h - 1).toInt();
      int r = 0, g = 0, b = 0, n = 0;
      for (int x = 0; x < w; x += (w ~/ 40).clamp(1, w).toInt()) {
        final int o = (row * w + x) * 4;
        r += data.getUint8(o);
        g += data.getUint8(o + 1);
        b += data.getUint8(o + 2);
        n++;
      }
      if (n > 0 && mounted) {
        setState(
          () => _bottomColor = Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n),
        );
      }
    } catch (_) {
      // No sample: the extension just stays transparent.
    }
  }

  void _detach() {
    final ImageStreamListener? l = _listener;
    if (l != null) _stream?.removeListener(l);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_aspect, _bottomColor);
}

class _ManifestSectionHeader extends StatelessWidget {
  const _ManifestSectionHeader({required this.title, this.accentColor});

  final String title;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    if (accentColor == null) {
      return Text(
        title,
        style: AppTextStyles.h2.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );
    }

    final words = title.split(' ');
    if (words.length < 2) {
      return Text(
        title,
        style: AppTextStyles.h2.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: accentColor,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: AppTextStyles.h2.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        children: <InlineSpan>[
          TextSpan(text: '${words.sublist(0, words.length - 1).join(' ')} '),
          TextSpan(
            text: words.last,
            style: TextStyle(color: accentColor, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

/// White "₹0 FEES" card (design `01-home.jpg`, block 6). Title, lines and
/// footnote are admin-configured section content (`fee_strip` config:
/// `title`, `lines[]`, `footnote`).
class _FeeStripCard extends StatelessWidget {
  const _FeeStripCard({
    required this.title,
    required this.lines,
    this.footnote,
  });

  final String title;
  final List<String> lines;
  final String? footnote;

  static const double _designWidth = 914;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        final HomeLookTheme look = ref.watch(
          activeTabThemeProvider.select((RemoteTheme t) => t.sections.homeLook),
        );
        return _buildCard(context, look);
      },
    );
  }

  Widget _buildCard(BuildContext context, HomeLookTheme look) {
    final double k = MediaQuery.sizeOf(context).width / _designWidth;
    final List<String> left = <String>[
      for (int i = 0; i < lines.length; i += 2) lines[i],
    ];
    final List<String> right = <String>[
      for (int i = 1; i < lines.length; i += 2) lines[i],
    ];

    Widget column(List<String> items, {String? note}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String line in items)
              Padding(
                padding: EdgeInsets.only(bottom: 10 * k),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 26 * k,
                      height: 26 * k,
                      decoration: BoxDecoration(
                        color: look.feeCardCheckColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 18 * k,
                        color: look.feeCardColor,
                      ),
                    ),
                    SizedBox(width: 10 * k),
                    Text(
                      line,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20 * k,
                        fontWeight: FontWeight.w500,
                        color: look.feeCardTextColor,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            if (note != null)
              Text(
                note,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15 * k,
                  color: look.feeCardTextColor.withValues(alpha: 0.75),
                  height: 1.2,
                ),
              ),
          ],
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(22 * k, 14 * k, 22 * k, 10 * k),
      child: Container(
        padding: EdgeInsets.fromLTRB(26 * k, 14 * k, 18 * k, 6 * k),
        decoration: BoxDecoration(
          color: look.feeCardColor,
          borderRadius: BorderRadius.circular(22 * k),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (title.isNotEmpty)
              SizedBox(
                width: 240 * k,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title.replaceAll(' ', ''),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 84 * k,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -4 * k,
                      color: look.feeCardTextColor,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            SizedBox(width: 22 * k),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Flexible(child: column(left)),
                  SizedBox(width: 16 * k),
                  Flexible(child: column(right, note: footnote)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManifestPromoCarousel extends StatefulWidget {
  const _ManifestPromoCarousel({
    required this.items,
    required this.borderRadius,
    required this.autoScroll,
    required this.autoScrollSpeedMs,
  });

  final List<_PromoItem> items;
  final double borderRadius;
  final bool autoScroll;
  final int autoScrollSpeedMs;

  @override
  State<_ManifestPromoCarousel> createState() => _ManifestPromoCarouselState();
}

class _ManifestPromoCarouselState extends State<_ManifestPromoCarousel> {
  late final PageController _controller;
  Timer? _timer;
  // PHASE 4D: Replace local _page int (setState per tick) with ValueNotifier.
  // Only the _PromoPageDots widget rebuilds when the page changes — the
  // PageView and its card items are untouched.
  late final ValueNotifier<int> _pageNotifier;

  @override
  void initState() {
    super.initState();
    _pageNotifier = ValueNotifier<int>(0);
    _controller = PageController();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _ManifestPromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length ||
        oldWidget.autoScroll != widget.autoScroll ||
        oldWidget.autoScrollSpeedMs != widget.autoScrollSpeedMs) {
      _timer?.cancel();
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (!widget.autoScroll || widget.items.length <= 1) {
      return;
    }
    _timer = Timer.periodic(
      Duration(milliseconds: widget.autoScrollSpeedMs.clamp(1500, 10000)),
      (_) {
        if (!mounted || !_controller.hasClients) {
          return;
        }
        final next = (_pageNotifier.value + 1) % widget.items.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  static const double _designWidth = 914;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        final HomeLookTheme look = ref.watch(
          activeTabThemeProvider.select((RemoteTheme t) => t.sections.homeLook),
        );
        return _buildHero(context, look);
      },
    );
  }

  Widget _buildHero(BuildContext context, HomeLookTheme look) {
    // Plain banner: no frame, small corner radius. Corner radius is the
    // dashboard's `border_radius` (default 12); the image fills the whole card.
    final double k = MediaQuery.sizeOf(context).width / _designWidth;
    final double radius = widget.borderRadius.clamp(0, 24).toDouble();
    final banner = Padding(
      padding: EdgeInsets.symmetric(horizontal: 22 * k),
      child: AspectRatio(
        aspectRatio: 870 / 382,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (int value) => _pageNotifier.value = value,
                itemBuilder: (BuildContext context, int index) {
                  final _PromoItem item = widget.items[index];
                  return GestureDetector(
                    onTap: item.linkUrl == null
                        ? null
                        : () => handleLinkTap(context, item.linkUrl!),
                    child: AppImage(
                      imageUrl: ApiConstants.resolveMediaUrl(item.imageUrl) ??
                          item.imageUrl,
                      memCacheWidth: 1200,
                      memCacheHeight: 540,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
              if (widget.items.length > 1)
                Positioned(
                  right: 18 * k,
                  bottom: 16 * k,
                  child: _PromoPageDots(
                    count: widget.items.length,
                    pageNotifier: _pageNotifier,
                    scale: k * 0.75,
                    color: look.heroDotColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (kIsWeb && MediaQuery.sizeOf(context).width >= 700) {
      return Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: banner,
      ));
    }
    return banner;
  }
}

/// Isolated page indicator for _ManifestPromoCarousel.
/// Listens to the ValueNotifier and rebuilds only the dots row.
class _PromoPageDots extends StatelessWidget {
  const _PromoPageDots({
    required this.count,
    required this.pageNotifier,
    required this.scale,
    required this.color,
  });

  final int count;
  final ValueNotifier<int> pageNotifier;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: pageNotifier,
      builder: (BuildContext context, int page, Widget? _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(
            count,
            (int index) => Container(
              width: 20 * scale,
              height: 20 * scale,
              margin: EdgeInsets.only(left: 12 * scale),
              decoration: BoxDecoration(
                color: index == page ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5 * scale),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ManifestBankOffersRow extends StatelessWidget {
  const _ManifestBankOffersRow({required this.items});

  final List<_PromoItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 6.h, 0, 2.h),
      child: SizedBox(
        height: 74.h,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemExtentBuilder: (int index, _) =>
              _horizontalSectionExtent(index, items.length, 336.w, 14.w),
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];
            final resolvedImage = ApiConstants.proxyMediaUrl(
                  ApiConstants.resolveMediaUrl(item.imageUrl) ?? item.imageUrl,
                ) ??
                ApiConstants.resolveMediaUrl(item.imageUrl) ??
                item.imageUrl;
            final VoidCallback? handleTap = item.linkUrl == null ||
                    item.linkUrl!.trim().isEmpty
                ? null
                : () => _handleManifestLinkTap(context, item.linkUrl!.trim());

            return Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: handleTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: SizedBox(
                    width: 336.w,
                    height: 74.h,
                    child: AppImage(
                      imageUrl: resolvedImage,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      memCacheWidth: 1440,
                      memCacheHeight: 317,
                      filterQuality: FilterQuality.high,
                      placeholder: const ColoredBox(
                        color: Color(0xFFF2F8FF),
                        child: SizedBox.expand(),
                      ),
                      errorWidget: const ColoredBox(
                        color: Color(0xFFF2F8FF),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Arched Product Showcase ────────────────────────────────────────────

Widget _buildArchedProductShowcase(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(ref, entry, fallbackLimit: 10);
  final categoriesAsync = ref.watch(categoryCollectionProvider);
  final categories = categoriesAsync.asData?.value ?? const <CategoryEntity>[];
  final containerColor = _resolveColor(
    entry.containerColor,
    const Color(0xFFFDE7C4),
  );
  final cardShape = entry.cardShape ?? 'arch';
  final archHeight = entry.archHeight ?? 14.0;
  final cornerRadius = entry.cornerRadius ?? 24.0;

  final bgGradient = entry.bgGradient;
  final bgGradientColors = bgGradient.length >= 2
      ? bgGradient
          .map((hex) => _resolveColor(hex, containerColor))
          .toList(growable: false)
      : null;

  final boxGradient = entry.boxGradient;
  final boxGradientColors = boxGradient.length >= 2
      ? boxGradient
          .map((hex) => _resolveColor(hex, containerColor))
          .toList(growable: false)
      : null;
  final categoryStripItems = entry.archedCategoryStripItems.map((item) {
    final link = _readString(item['link']);
    final resolvedLink = _resolveArchedCategoryLink(link, categories);
    if (resolvedLink == null || resolvedLink == link) {
      return item;
    }

    return <String, dynamic>{...item, 'link': resolvedLink};
  }).toList(growable: false);

  return _ManifestArchedProductSection(
    title: entry.title ?? 'Top Picks',
    showTitle: entry.showTitle,
    titleColor: _resolveColor(entry.titleColor, const Color(0xFF1A1A1A)),
    bannerEnabled: entry.archedBannerEnabled,
    bannerContentSource: entry.archedBannerContentSource,
    bannerLottieUrl: entry.archedBannerLottieUrl,
    bannerImageUrl: entry.archedBannerImageUrl,
    bannerHeight: entry.archedBannerHeight,
    bannerGradient: entry.archedBannerGradient.length >= 2
        ? entry.archedBannerGradient
            .map((hex) => _resolveColor(hex, const Color(0xFFE8F5E9)))
            .toList(growable: false)
        : null,
    categoryStripEnabled: entry.archedCategoryStripEnabled,
    categoryStripItems: categoryStripItems,
    categoryStripIconSize: entry.archedCategoryStripIconSize,
    categoryStripShowLabels: entry.archedCategoryStripShowLabels,
    products: products,
    productLayout: entry.productLayout,
    backgroundColor: containerColor,
    bgGradientColors: bgGradientColors,
    cardShape: cardShape,
    archHeight: archHeight,
    cornerRadius: cornerRadius,
    boxGradientColors: boxGradientColors,
  );
}

String? _resolveArchedCategoryLink(
  String? target,
  List<CategoryEntity> categories,
) {
  final trimmed = target?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return trimmed;
  }

  final normalizedTarget = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  if (normalizedTarget.contains('/products')) {
    return normalizedTarget;
  }

  final match = RegExp(r'^/categories/([^/]+)$').firstMatch(normalizedTarget);
  if (match == null) {
    return normalizedTarget;
  }

  final rawToken = match.group(1);
  if (rawToken == null || rawToken.isEmpty) {
    return normalizedTarget;
  }

  final token = _normalizeCategoryLookupToken(rawToken);
  CategoryEntity? fallbackMatch;

  for (final category in categories) {
    final nameToken = _normalizeCategoryLookupToken(category.name);
    if (nameToken == token || category.id == rawToken) {
      return '/categories/${category.id}/products';
    }

    if (fallbackMatch == null &&
        nameToken.contains(token) &&
        category.isActive) {
      fallbackMatch = category;
    }
  }

  if (fallbackMatch != null) {
    return '/categories/${fallbackMatch.id}/products';
  }

  return normalizedTarget;
}

String _normalizeCategoryLookupToken(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _ManifestArchedProductSection extends StatelessWidget {
  const _ManifestArchedProductSection({
    required this.title,
    required this.showTitle,
    required this.titleColor,
    required this.bannerEnabled,
    required this.bannerContentSource,
    required this.bannerHeight,
    required this.categoryStripEnabled,
    required this.categoryStripItems,
    required this.categoryStripIconSize,
    required this.categoryStripShowLabels,
    required this.products,
    required this.productLayout,
    required this.backgroundColor,
    this.bannerLottieUrl,
    this.bannerImageUrl,
    this.bannerGradient,
    this.bgGradientColors,
    this.cardShape = 'arch',
    this.archHeight = 14.0,
    this.cornerRadius = 24.0,
    this.boxGradientColors,
  });

  final String title;
  final bool showTitle;
  final Color titleColor;
  final bool bannerEnabled;
  final String bannerContentSource;
  final String? bannerLottieUrl;
  final String? bannerImageUrl;
  final double bannerHeight;
  final List<Color>? bannerGradient;
  final bool categoryStripEnabled;
  final List<Map<String, dynamic>> categoryStripItems;
  final double categoryStripIconSize;
  final bool categoryStripShowLabels;
  final List<ProductEntity> products;
  final String productLayout;
  final Color backgroundColor;
  final List<Color>? bgGradientColors;
  final String cardShape;
  final double archHeight;
  final double cornerRadius;
  final List<Color>? boxGradientColors;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showTitle)
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 10.h),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
        if (bannerEnabled) _buildBannerZone(context),
        if (categoryStripEnabled && categoryStripItems.isNotEmpty)
          _buildCategoryStrip(context),
        if (products.isNotEmpty)
          buildArchedProductLayout(
            productLayout,
            ArchedLayoutParams(
              products: products,
              backgroundColor: backgroundColor,
              cardShape: cardShape,
              archHeight: archHeight,
              cornerRadius: cornerRadius,
              boxGradientColors: boxGradientColors,
            ),
          ),
        Gap(12.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDFB8),
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Gap(4),
                PhosphorIcon(
                  PhosphorIcons.caretRightBold,
                  size: 14,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: bgGradientColors != null
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bgGradientColors!,
                )
              : null,
        ),
        child: content,
      ),
    );
  }

  Widget _buildBannerZone(BuildContext context) {
    final gradientColors = bannerGradient ??
        <Color>[const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)];

    if (bannerContentSource == 'lottie' &&
        bannerLottieUrl != null &&
        bannerLottieUrl!.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: AnimatedBannerSection(
          // No local fallback — only render remote lottie from dashboard.
          assetPath: '',
          height: bannerHeight,
          bannerTheme: BannerAnimationTheme(
            imageUrl: null,
            lottieUrl: bannerLottieUrl,
            backgroundGradient: gradientColors,
            containerColor: gradientColors.first,
          ),
          feeStripTheme: const FeeStripTheme(imageUrl: null, visible: false),
        ),
      );
    }

    if (bannerContentSource == 'image' &&
        bannerImageUrl != null &&
        bannerImageUrl!.isNotEmpty) {
      final resolvedUrl = ApiConstants.resolveMediaUrl(bannerImageUrl);
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Container(
          height: bannerHeight.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: resolvedUrl != null
              ? AppImage(
                  imageUrl: resolvedUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  memCacheHeight: 360,
                )
              : null,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        height: bannerHeight.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
      ),
    );
  }

  Widget _buildCategoryStrip(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: SizedBox(
        height: categoryStripShowLabels
            ? categoryStripIconSize.h + 24.h
            : categoryStripIconSize.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: categoryStripItems.length,
          itemExtentBuilder: (int index, _) => _horizontalSectionExtent(
            index,
            categoryStripItems.length,
            (categoryStripIconSize + 8).w,
            12.w,
          ),
          itemBuilder: (BuildContext context, int index) {
            final item = categoryStripItems[index];
            final label = _readString(item['label']) ?? '';
            final imageUrl = _readString(item['image_url']);
            final link = _readString(item['link']);

            return Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: link != null && link.isNotEmpty
                    ? () => _handleManifestLinkTap(context, link)
                    : null,
                child: SizedBox(
                  width: categoryStripIconSize.w + 8.w,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: categoryStripIconSize.w,
                        height: categoryStripIconSize.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? AppImage(
                                imageUrl:
                                    ApiConstants.resolveMediaUrl(imageUrl) ??
                                        '',
                                fit: BoxFit.cover,
                                memCacheWidth: 160,
                                memCacheHeight: 160,
                                errorWidget: PhosphorIcon(
                                  PhosphorIcons.packageDuotone,
                                  size: 24.sp,
                                  color: Colors.grey,
                                ),
                              )
                            : PhosphorIcon(
                                PhosphorIcons.packageDuotone,
                                size: 24.sp,
                                color: Colors.grey,
                              ),
                      ),
                      if (categoryStripShowLabels && label.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
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
    );
  }
}

class _PromoItem {
  const _PromoItem({required this.imageUrl, required this.linkUrl});

  final String imageUrl;
  final String? linkUrl;
}

Future<void> _handleManifestLinkTap(BuildContext context, String target) async {
  final uri = Uri.tryParse(target);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  if (!context.mounted) {
    return;
  }

  final container = ProviderScope.containerOf(context, listen: false);
  final categoriesAsync = container.read(categoryCollectionProvider);
  final categories = categoriesAsync.asData?.value ?? const <CategoryEntity>[];
  final resolvedTarget =
      _resolveArchedCategoryLink(target, categories) ?? target;

  context.push(
    resolvedTarget.startsWith('/') ? resolvedTarget : '/$resolvedTarget',
  );
}
