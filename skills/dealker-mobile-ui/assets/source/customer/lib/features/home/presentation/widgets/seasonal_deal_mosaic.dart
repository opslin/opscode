import 'dart:async';

import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/theme/remote_theme_model.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';

/// Deal mosaic of the home. Image-only: every tile shows the picture uploaded
/// in the dashboard edge to edge (BoxFit.cover) — no title, badge or caption is
/// drawn by the app; marketing bakes any text into the artwork. Two layouts:
/// `hero_plus_four` (tall hero + 2×2) and `two_by_two`.
class SeasonalDealMosaic extends StatelessWidget {
  const SeasonalDealMosaic({
    required this.products,
    this.heroCandidates,
    this.mosaicTheme,
    this.layoutVariant = 'hero_plus_four',
    super.key,
  });

  final List<ProductEntity> products;
  final List<ProductEntity>? heroCandidates;
  final SeasonalMosaicTheme? mosaicTheme;
  final String layoutVariant;

  @override
  Widget build(BuildContext context) {
    final List<ProductEntity> heroProducts = _buildHeroProducts(
      heroCandidates ?? products,
    );
    final List<_MiniAssetTileSpec> miniTiles = _buildMiniAssetTiles(
      products,
      mosaicTheme,
    );
    if (heroProducts.isEmpty || miniTiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final Widget content;
    if (layoutVariant == 'two_by_two') {
      content = _buildMiniTileGrid(miniTiles);
    } else {
      if (miniTiles.length < 4) {
        return const SizedBox.shrink();
      }
      final HeroTileTheme hero =
          mosaicTheme?.heroTile ?? HeroTileTheme.defaults();
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: AspectRatio(
          aspectRatio: 1.48,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double gap = 8.w;
              final double leftWidth = constraints.maxWidth * 0.36;
              final double rightWidth = constraints.maxWidth - leftWidth - gap;
              final double tileHeight = (constraints.maxHeight - gap) / 2;
              final double tileWidth = (rightWidth - gap) / 2;

              Widget mini(int i) => SizedBox(
                    width: tileWidth,
                    height: tileHeight,
                    child: _AssetMiniDealTile(spec: miniTiles[i]),
                  );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: leftWidth,
                    child: _HeroSeasonalDealTile(
                      product: heroProducts.first,
                      gradient: hero.gradient,
                      imageUrl: hero.imageUrl,
                      action: hero.action,
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox(
                    width: rightWidth,
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            mini(0),
                            SizedBox(width: gap),
                            mini(1),
                          ],
                        ),
                        SizedBox(height: gap),
                        Row(
                          children: <Widget>[
                            mini(2),
                            SizedBox(width: gap),
                            mini(3),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    final Color surfaceColor = mosaicTheme?.containerColor ??
        SeasonalMosaicTheme.defaults().containerColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28.r),
          bottomRight: Radius.circular(28.r),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 4.h, 0, 4.h),
        child: content,
      ),
    );
  }

  Widget _buildMiniTileGrid(List<_MiniAssetTileSpec> miniTiles) {
    final double spacing = 8.w;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double itemWidth = (constraints.maxWidth - spacing) / 2;
          final double itemHeight = itemWidth / 1.05;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List<Widget>.generate(4, (int index) {
              return SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _AssetMiniDealTile(
                  spec: miniTiles[index % miniTiles.length],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Fills [child] edge to edge with the uploaded picture (cover); a plain
/// gradient shows only while it loads or when none is uploaded.
class _TileArt extends StatelessWidget {
  const _TileArt({
    required this.imageUrl,
    required this.gradient,
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final String? imageUrl;
  final List<Color> gradient;
  final int cacheWidth;
  final int cacheHeight;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl == null || imageUrl!.trim().isEmpty
        ? null
        : (ApiConstants.resolveMediaUrl(imageUrl) ?? imageUrl);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradient.length >= 2
                  ? gradient
                  : <Color>[gradient.first, gradient.first],
            ),
          ),
        ),
        if (url != null)
          AppImage(
            imageUrl: url,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            filterQuality: FilterQuality.high,
            errorWidget: const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _HeroSeasonalDealTile extends StatelessWidget {
  const _HeroSeasonalDealTile({
    required this.product,
    required this.gradient,
    this.imageUrl,
    this.action,
  });

  final ProductEntity product;
  final List<Color> gradient;
  final String? imageUrl;
  final MosaicTileAction? action;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(28.r);
    // No uploaded picture: fall back to the product's own image.
    final String? art = (imageUrl != null && imageUrl!.trim().isNotEmpty)
        ? imageUrl
        : ApiConstants.optimizedMedia(
            _firstRenderableImage(product),
            profile: CustomerImageProfile.seasonalHeroArtwork,
          ).url;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => resolveMosaicTap(context, action, product.id),
        borderRadius: radius,
        child: ClipRRect(
          borderRadius: radius,
          child: _TileArt(
            imageUrl: art,
            gradient: gradient,
            cacheWidth: 600,
            cacheHeight: 1100,
          ),
        ),
      ),
    );
  }
}

class _AssetMiniDealTile extends StatelessWidget {
  const _AssetMiniDealTile({required this.spec});

  final _MiniAssetTileSpec spec;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(24.r);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => resolveMosaicTap(context, spec.action, spec.product.id),
        borderRadius: radius,
        child: ClipRRect(
          borderRadius: radius,
          child: _TileArt(
            imageUrl: spec.imageUrl,
            gradient: spec.gradient,
            cacheWidth: 500,
            cacheHeight: 500,
          ),
        ),
      ),
    );
  }
}

class _MiniAssetTileSpec {
  const _MiniAssetTileSpec({
    required this.product,
    required this.imageUrl,
    required this.gradient,
    this.action,
  });

  final ProductEntity product;
  final String? imageUrl;
  final List<Color> gradient;
  final MosaicTileAction? action;
}

/// Resolves a mosaic tile tap. When [action] is actionable it is honoured;
/// otherwise we fall back to opening the resolved product (legacy behaviour).
void resolveMosaicTap(
  BuildContext context,
  MosaicTileAction? action,
  String fallbackProductId,
) {
  if (action != null && action.isActionable) {
    switch (action.type) {
      case 'product':
        context.push('/product/${action.value}');
        return;
      case 'category':
        context.push('/categories/${action.value}/products');
        return;
      case 'tab':
        final route = _mosaicTabRoute(action.value!);
        if (route != null) {
          context.go(route);
          return;
        }
        break;
      case 'app_page':
        context.push(action.value!);
        return;
      case 'external_url':
        final uri = Uri.tryParse(action.value!);
        if (uri != null) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
          return;
        }
        break;
      default:
        break;
    }
  }
  context.push('/product/$fallbackProductId');
}

String? _mosaicTabRoute(String key) {
  switch (key) {
    case 'home':
      return '/home';
  }
  return null;
}

List<ProductEntity> _buildHeroProducts(List<ProductEntity> products) {
  final renderable = products
      .where((product) => _firstRenderableImage(product) != null)
      .toList(growable: false);
  final source = renderable.isNotEmpty ? renderable : products;
  if (source.isEmpty) {
    return const <ProductEntity>[];
  }

  final exactRealMango = source.where((product) {
    final name = product.name.toLowerCase();
    return name.contains('real mango juice');
  }).toList(growable: false);
  if (exactRealMango.isNotEmpty) {
    return <ProductEntity>[exactRealMango.first];
  }

  final ranked = source.toList(growable: false)
    ..sort(
      (left, right) =>
          _heroProductScore(right).compareTo(_heroProductScore(left)),
    );
  final lead = ranked.first;

  return <ProductEntity>[lead];
}

const List<List<List<String>>> _miniTileKeywordGroups = <List<List<String>>>[
  <List<String>>[
    <String>['coca-cola', 'cola', 'soft drink'],
    <String>['real mango juice', 'mango juice', 'juice'],
    <String>['amul vanilla magic', 'ice cream', 'vanilla magic'],
  ],
  <List<String>>[
    <String>['amul vanilla magic', 'ice cream', 'vanilla magic'],
    <String>['amul', 'frozen'],
  ],
  <List<String>>[
    <String>['lays classic', 'lays', 'chips', 'salted'],
    <String>['real mango juice', 'mango juice', 'juice'],
  ],
  <List<String>>[
    <String>['milky mist paneer', 'paneer'],
    <String>['amul taaza', 'taaza milk', 'milk'],
    <String>['egg', 'eggs'],
  ],
];

List<_MiniAssetTileSpec> _buildMiniAssetTiles(
  List<ProductEntity> products,
  SeasonalMosaicTheme? mosaicTheme,
) {
  final defaultMosaicTheme = SeasonalMosaicTheme.defaults();
  final renderable = products
      .where((product) => _firstRenderableImage(product) != null)
      .toList(growable: false);
  final source = renderable.isNotEmpty ? renderable : products;
  if (source.isEmpty) {
    return const <_MiniAssetTileSpec>[];
  }

  // Honour the configured tile count (e.g. 6 for the 2x3 layout) instead of
  // hard-coding 4. Falls back to the default 4-tile set when no theme tiles
  // are supplied.
  final themedCount =
      mosaicTheme?.miniTiles.length ?? defaultMosaicTheme.miniTiles.length;
  final count = themedCount.clamp(1, 8);

  final usedIds = <String>{};

  return List<_MiniAssetTileSpec>.generate(count, (int index) {
    final themed = _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, index);
    final fallbackTile = defaultMosaicTheme
        .miniTiles[index % defaultMosaicTheme.miniTiles.length];
    return _MiniAssetTileSpec(
      product: _pickMiniTileProduct(
        source,
        usedIds,
        _miniTileKeywordGroups[index % _miniTileKeywordGroups.length],
      ),
      imageUrl: themed?.imageUrl,
      gradient: themed?.gradient ?? fallbackTile.gradient,
      action: themed?.action,
    );
  });
}

MiniTileTheme? _miniTileThemeAt(
  SeasonalMosaicTheme? mosaicTheme,
  SeasonalMosaicTheme defaultMosaicTheme,
  int index,
) {
  final themedTiles = mosaicTheme?.miniTiles;
  if (themedTiles != null && themedTiles.length > index) {
    return themedTiles[index];
  }
  if (defaultMosaicTheme.miniTiles.length > index) {
    return defaultMosaicTheme.miniTiles[index];
  }
  return null;
}

ProductEntity _pickMiniTileProduct(
  List<ProductEntity> source,
  Set<String> usedIds,
  List<List<String>> keywordGroups,
) {
  for (final group in keywordGroups) {
    for (final product in source) {
      if (usedIds.contains(product.id)) {
        continue;
      }
      if (_matchesKeywordGroup(product, group)) {
        usedIds.add(product.id);
        return product;
      }
    }
  }

  for (final group in keywordGroups) {
    for (final product in source) {
      if (_matchesKeywordGroup(product, group)) {
        return product;
      }
    }
  }

  for (final product in source) {
    if (!usedIds.contains(product.id)) {
      usedIds.add(product.id);
      return product;
    }
  }

  return source.first;
}

bool _matchesKeywordGroup(ProductEntity product, List<String> keywords) {
  final haystack = <String?>[
    product.name,
    product.categoryName,
    product.description,
    if (product.tags.isNotEmpty) product.tags.join(' '),
  ].whereType<String>().join(' ').toLowerCase();

  return keywords.any(haystack.contains);
}

int _heroProductScore(ProductEntity product) {
  final haystack = <String?>[
    product.name,
    product.categoryName,
    if (product.tags.isNotEmpty) product.tags.join(' '),
  ].whereType<String>().join(' ').toLowerCase();

  const primaryKeywords = <String, int>{
    'nescafe': 18,
    'coffee': 14,
    'latte': 12,
    'chocolate': 11,
    'amul': 10,
    'milk': 8,
    'tea': 7,
    'butter': 6,
  };
  const secondaryKeywords = <String, int>{
    'biscuit': 4,
    'ice': 4,
    'snack': 3,
    'juice': 3,
    'mango': 3,
  };
  const avoidKeywords = <String>[
    'baby',
    'pampers',
    'diaper',
    'cerelac',
    'stage',
    'care',
    'beverage',
    'cola',
    'water',
    'tonic',
    'apple',
    'banana',
    'potato',
    'tomato',
    'spinach',
    'onion',
    'vegetable',
    'atta',
    'dal',
    'rice',
  ];

  var score = 0;
  primaryKeywords.forEach((keyword, weight) {
    if (haystack.contains(keyword)) {
      score += weight;
    }
  });
  secondaryKeywords.forEach((keyword, weight) {
    if (haystack.contains(keyword)) {
      score += weight;
    }
  });
  for (final keyword in avoidKeywords) {
    if (haystack.contains(keyword)) {
      score -= 6;
    }
  }

  if (product.isFeatured) {
    score += 2;
  }
  if (product.isOnSale) {
    score += 3;
  }
  if (product.thumbnailUrl != null && product.thumbnailUrl!.isNotEmpty) {
    score += 2;
  }

  return score;
}

String? _firstRenderableImage(ProductEntity product) {
  final candidates = <String?>[product.thumbnailUrl, ...product.images];

  for (final candidate in candidates) {
    final value = ApiConstants.resolveMediaUrl(candidate)?.trim();
    if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }

  return null;
}
