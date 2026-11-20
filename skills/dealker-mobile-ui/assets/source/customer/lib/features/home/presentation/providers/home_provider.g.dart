// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(home)
const homeProvider = HomeProvider._();

final class HomeProvider extends $FunctionalProvider<AsyncValue<HomeScreenData>,
        HomeScreenData, FutureOr<HomeScreenData>>
    with $FutureModifier<HomeScreenData>, $FutureProvider<HomeScreenData> {
  const HomeProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'homeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$homeHash();

  @$internal
  @override
  $FutureProviderElement<HomeScreenData> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<HomeScreenData> create(Ref ref) {
    return home(ref);
  }
}

String _$homeHash() => r'55d5bbb81c506bea460b8c3c3e8f8669abe16123';

@ProviderFor(homeNewArrivals)
const homeNewArrivalsProvider = HomeNewArrivalsProvider._();

final class HomeNewArrivalsProvider extends $FunctionalProvider<
        AsyncValue<List<ProductEntity>>,
        List<ProductEntity>,
        FutureOr<List<ProductEntity>>>
    with
        $FutureModifier<List<ProductEntity>>,
        $FutureProvider<List<ProductEntity>> {
  const HomeNewArrivalsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'homeNewArrivalsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$homeNewArrivalsHash();

  @$internal
  @override
  $FutureProviderElement<List<ProductEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProductEntity>> create(Ref ref) {
    return homeNewArrivals(ref);
  }
}

String _$homeNewArrivalsHash() => r'fe224c8c3731b4a2074ae81211cd0ace9afa6661';

@ProviderFor(homeDeals)
const homeDealsProvider = HomeDealsProvider._();

final class HomeDealsProvider extends $FunctionalProvider<
        AsyncValue<List<ProductEntity>>,
        List<ProductEntity>,
        FutureOr<List<ProductEntity>>>
    with
        $FutureModifier<List<ProductEntity>>,
        $FutureProvider<List<ProductEntity>> {
  const HomeDealsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'homeDealsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$homeDealsHash();

  @$internal
  @override
  $FutureProviderElement<List<ProductEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProductEntity>> create(Ref ref) {
    return homeDeals(ref);
  }
}

String _$homeDealsHash() => r'11b87509d25bf1889672449c52152170011ef96a';

@ProviderFor(homeTrendingProducts)
const homeTrendingProductsProvider = HomeTrendingProductsProvider._();

final class HomeTrendingProductsProvider extends $FunctionalProvider<
        AsyncValue<List<ProductEntity>>,
        List<ProductEntity>,
        FutureOr<List<ProductEntity>>>
    with
        $FutureModifier<List<ProductEntity>>,
        $FutureProvider<List<ProductEntity>> {
  const HomeTrendingProductsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'homeTrendingProductsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$homeTrendingProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<ProductEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProductEntity>> create(Ref ref) {
    return homeTrendingProducts(ref);
  }
}

String _$homeTrendingProductsHash() =>
    r'c209a5b08ece5eb4121c9ce17e5046c4d500dc4a';

@ProviderFor(homeCategoryProducts)
const homeCategoryProductsProvider = HomeCategoryProductsFamily._();

final class HomeCategoryProductsProvider extends $FunctionalProvider<
        AsyncValue<List<ProductEntity>>,
        List<ProductEntity>,
        FutureOr<List<ProductEntity>>>
    with
        $FutureModifier<List<ProductEntity>>,
        $FutureProvider<List<ProductEntity>> {
  const HomeCategoryProductsProvider._(
      {required HomeCategoryProductsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'homeCategoryProductsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$homeCategoryProductsHash();

  @override
  String toString() {
    return r'homeCategoryProductsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ProductEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProductEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return homeCategoryProducts(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeCategoryProductsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeCategoryProductsHash() =>
    r'7c27cf75ddb7f28a82a7efd86a73c78a4ae2f6d4';

final class HomeCategoryProductsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ProductEntity>>, String> {
  const HomeCategoryProductsFamily._()
      : super(
          retry: null,
          name: r'homeCategoryProductsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  HomeCategoryProductsProvider call(
    String categoryId,
  ) =>
      HomeCategoryProductsProvider._(argument: categoryId, from: this);

  @override
  String toString() => r'homeCategoryProductsProvider';
}
