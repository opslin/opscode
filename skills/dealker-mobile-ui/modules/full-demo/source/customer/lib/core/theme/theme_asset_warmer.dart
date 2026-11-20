import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/theme/remote_animation_loader.dart';
import 'package:dealker_app/core/theme/remote_theme_model.dart';
import 'package:dealker_app/core/theme/section_manifest_model.dart';

/// Pre-downloads theme asset URLs for instant display on tab switch.
class ThemeAssetWarmer {
  static final Set<String> _warmedImageUrls = <String>{};
  static final Set<String> _warmingImageUrls = <String>{};
  static final Set<String> _warmedLottieUrls = <String>{};
  static final Set<String> _warmingLottieUrls = <String>{};

  static Future<void> warmAssets(TabThemesResponse response) async {
    final Set<String> imageUrls = <String>{};
    final Set<String> lottieUrls = <String>{};

    for (final TabThemeEntry tab in response.tabs) {
      _collectThemeUrls(imageUrls, lottieUrls, tab.themeData);
      if (tab.abTest != null) {
        _collectThemeUrls(imageUrls, lottieUrls, tab.abTest!.variantBData);
      }
      if (tab.tabIconUrl != null) {
        imageUrls.add(tab.tabIconUrl!);
      }
    }

    int cached = 0;
    for (final String url in imageUrls) {
      if (url.isEmpty ||
          _warmedImageUrls.contains(url) ||
          !_warmingImageUrls.add(url)) {
        continue;
      }
      try {
        await _warmImageUrl(url);
        cached++;
        _warmedImageUrls.add(url);
      } catch (error) {
        debugPrint('[AssetWarmer] Failed: $url - $error');
      } finally {
        _warmingImageUrls.remove(url);
      }
    }

    for (final String url in lottieUrls) {
      if (url.isEmpty ||
          _warmedLottieUrls.contains(url) ||
          !_warmingLottieUrls.add(url)) {
        continue;
      }
      try {
        await _warmLottieUrl(url);
        cached++;
        _warmedLottieUrls.add(url);
      } catch (error) {
        debugPrint('[AssetWarmer] Failed: $url - $error');
      } finally {
        _warmingLottieUrls.remove(url);
      }
    }

    final int totalUrls = imageUrls.length + lottieUrls.length;
    debugPrint('[AssetWarmer] Pre-cached $cached/$totalUrls assets');
  }

  static Future<void> warmSectionManifest(
    SectionManifestResponse response,
  ) async {
    final Set<String> imageUrls = <String>{};
    final Set<String> lottieUrls = <String>{};
    for (final SectionManifestEntry entry in response.sections) {
      final String? imageUrl = entry.imageUrl?.trim();
      final String? lottieUrl = entry.lottieUrl?.trim();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        imageUrls.add(imageUrl);
      }
      final dynamic rawItems = entry.config['items'];
      if (rawItems is List) {
        for (final dynamic rawItem in rawItems) {
          if (rawItem is! Map) {
            continue;
          }
          final dynamic rawIconUrl = rawItem['image_url'];
          if (rawIconUrl is String && rawIconUrl.trim().isNotEmpty) {
            imageUrls.add(rawIconUrl.trim());
          }
        }
      }
      if (lottieUrl != null && lottieUrl.isNotEmpty) {
        lottieUrls.add(lottieUrl);
      }
    }

    for (final String url in imageUrls) {
      if (url.isEmpty ||
          _warmedImageUrls.contains(url) ||
          !_warmingImageUrls.add(url)) {
        continue;
      }
      try {
        await _warmImageUrl(url);
        _warmedImageUrls.add(url);
      } catch (error) {
        debugPrint('[AssetWarmer] Failed: $url - $error');
      } finally {
        _warmingImageUrls.remove(url);
      }
    }

    for (final String url in lottieUrls) {
      if (url.isEmpty ||
          _warmedLottieUrls.contains(url) ||
          !_warmingLottieUrls.add(url)) {
        continue;
      }
      try {
        await _warmLottieUrl(url);
        _warmedLottieUrls.add(url);
      } catch (error) {
        debugPrint('[AssetWarmer] Failed: $url - $error');
      } finally {
        _warmingLottieUrls.remove(url);
      }
    }
  }

  static void _collectThemeUrls(
    Set<String> imageUrls,
    Set<String> lottieUrls,
    RemoteTheme theme,
  ) {
    if (theme.sections.feeStrip.imageUrl != null) {
      imageUrls.add(theme.sections.feeStrip.imageUrl!);
    }
    if (theme.sections.searchZone.promoBoxImageUrl != null) {
      imageUrls.add(theme.sections.searchZone.promoBoxImageUrl!);
    }
    if (theme.sections.searchZone.sellBoxImageUrl != null) {
      imageUrls.add(theme.sections.searchZone.sellBoxImageUrl!);
    }
    if (theme.sections.bannerAnimation.imageUrl != null) {
      imageUrls.add(theme.sections.bannerAnimation.imageUrl!);
    }
    if (theme.sections.bannerAnimation.lottieUrl != null) {
      lottieUrls.add(theme.sections.bannerAnimation.lottieUrl!);
    }
    for (final MiniTileTheme tile in theme.sections.seasonalMosaic.miniTiles) {
      if (tile.imageUrl != null) {
        imageUrls.add(tile.imageUrl!);
      }
    }
    for (final String bannerUrl in theme.sections.bankOffers.bannerImageUrls) {
      imageUrls.add(bannerUrl);
    }
  }

  /// Downloads the file into the shared image disk cache and stops there.
  ///
  /// This used to resolve a `CachedNetworkImageProvider`, which also DECODED every image
  /// at its original size into Flutter's in-memory image cache (a 1895x830 banner is
  /// ~6 MB decoded). Warming dozens of them at launch pushed the screen's own images out
  /// of that cache and competed with them for CPU. Widgets decode at their own (much
  /// smaller) size when they actually show the image, from this same disk cache.
  static Future<void> _warmImageUrl(String url) async {
    final String resolvedUrl = ApiConstants.proxyMediaUrl(url) ?? url;
    await DefaultCacheManager()
        .getSingleFile(resolvedUrl)
        .timeout(const Duration(seconds: 10));
  }

  static Future<void> _warmLottieUrl(String url) async {
    await RemoteAnimationLoader.load(url).timeout(const Duration(seconds: 15));
  }
}
