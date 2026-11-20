// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banner_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(banner)
const bannerProvider = BannerProvider._();

final class BannerProvider extends $FunctionalProvider<
        AsyncValue<List<BannerEntity>>,
        List<BannerEntity>,
        FutureOr<List<BannerEntity>>>
    with
        $FutureModifier<List<BannerEntity>>,
        $FutureProvider<List<BannerEntity>> {
  const BannerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'bannerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$bannerHash();

  @$internal
  @override
  $FutureProviderElement<List<BannerEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<BannerEntity>> create(Ref ref) {
    return banner(ref);
  }
}

String _$bannerHash() => r'20a02ce6493970984bf15c3a114a2fd52a7385db';

/// Profile-screen placement — a distinct admin-configured set of banners
/// from the home screen's [banner] above, resolved server-side by the same
/// audience (B2C/B2B) and optional customer-segment targeting every other
/// banner already gets; nothing extra to do client-side for that part.

@ProviderFor(profileBanner)
const profileBannerProvider = ProfileBannerProvider._();

/// Profile-screen placement — a distinct admin-configured set of banners
/// from the home screen's [banner] above, resolved server-side by the same
/// audience (B2C/B2B) and optional customer-segment targeting every other
/// banner already gets; nothing extra to do client-side for that part.

final class ProfileBannerProvider extends $FunctionalProvider<
        AsyncValue<List<BannerEntity>>,
        List<BannerEntity>,
        FutureOr<List<BannerEntity>>>
    with
        $FutureModifier<List<BannerEntity>>,
        $FutureProvider<List<BannerEntity>> {
  /// Profile-screen placement — a distinct admin-configured set of banners
  /// from the home screen's [banner] above, resolved server-side by the same
  /// audience (B2C/B2B) and optional customer-segment targeting every other
  /// banner already gets; nothing extra to do client-side for that part.
  const ProfileBannerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'profileBannerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$profileBannerHash();

  @$internal
  @override
  $FutureProviderElement<List<BannerEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<BannerEntity>> create(Ref ref) {
    return profileBanner(ref);
  }
}

String _$profileBannerHash() => r'2b0e1cf781e32c59d3f94e7d84db966f5a43a132';

@ProviderFor(homeFeaturedProducts)
const homeFeaturedProductsProvider = HomeFeaturedProductsProvider._();

final class HomeFeaturedProductsProvider extends $FunctionalProvider<
        AsyncValue<List<ProductEntity>>,
        List<ProductEntity>,
        FutureOr<List<ProductEntity>>>
    with
        $FutureModifier<List<ProductEntity>>,
        $FutureProvider<List<ProductEntity>> {
  const HomeFeaturedProductsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'homeFeaturedProductsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$homeFeaturedProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<ProductEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProductEntity>> create(Ref ref) {
    return homeFeaturedProducts(ref);
  }
}

String _$homeFeaturedProductsHash() =>
    r'459525452ef96a7c36b21ebe82ba1284b8f18274';
