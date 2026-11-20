// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recently_viewed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RecentlyViewedNotifier)
const recentlyViewedProvider = RecentlyViewedNotifierProvider._();

final class RecentlyViewedNotifierProvider
    extends $NotifierProvider<RecentlyViewedNotifier, List<String>> {
  const RecentlyViewedNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'recentlyViewedProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$recentlyViewedNotifierHash();

  @$internal
  @override
  RecentlyViewedNotifier create() => RecentlyViewedNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$recentlyViewedNotifierHash() =>
    r'e2accb3d048fc163180e73123dee2cd75f4ebfb1';

abstract class _$RecentlyViewedNotifier extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<String>, List<String>>,
        List<String>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

/// Live product entities for the recently-viewed carousel, excluding the
/// product currently being viewed. Each id is fetched live via the same
/// single-product endpoint the rest of the detail screen uses (not the
/// locally-cached snapshot), so price/stock/images are always current —
/// any id that fails to load (deleted) or is out of stock is dropped
/// rather than shown stale/unavailable.

@ProviderFor(recentlyViewedProducts)
const recentlyViewedProductsProvider = RecentlyViewedProductsFamily._();

/// Live product entities for the recently-viewed carousel, excluding the
/// product currently being viewed. Each id is fetched live via the same
/// single-product endpoint the rest of the detail screen uses (not the
/// locally-cached snapshot), so price/stock/images are always current —
/// any id that fails to load (deleted) or is out of stock is dropped
/// rather than shown stale/unavailable.

final class RecentlyViewedProductsProvider extends $FunctionalProvider<
        AsyncValue<List<ProductEntity>>,
        List<ProductEntity>,
        FutureOr<List<ProductEntity>>>
    with
        $FutureModifier<List<ProductEntity>>,
        $FutureProvider<List<ProductEntity>> {
  /// Live product entities for the recently-viewed carousel, excluding the
  /// product currently being viewed. Each id is fetched live via the same
  /// single-product endpoint the rest of the detail screen uses (not the
  /// locally-cached snapshot), so price/stock/images are always current —
  /// any id that fails to load (deleted) or is out of stock is dropped
  /// rather than shown stale/unavailable.
  const RecentlyViewedProductsProvider._(
      {required RecentlyViewedProductsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'recentlyViewedProductsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$recentlyViewedProductsHash();

  @override
  String toString() {
    return r'recentlyViewedProductsProvider'
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
    return recentlyViewedProducts(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecentlyViewedProductsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recentlyViewedProductsHash() =>
    r'cc49a88c50462296150723d0179244054dfd9056';

/// Live product entities for the recently-viewed carousel, excluding the
/// product currently being viewed. Each id is fetched live via the same
/// single-product endpoint the rest of the detail screen uses (not the
/// locally-cached snapshot), so price/stock/images are always current —
/// any id that fails to load (deleted) or is out of stock is dropped
/// rather than shown stale/unavailable.

final class RecentlyViewedProductsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ProductEntity>>, String> {
  const RecentlyViewedProductsFamily._()
      : super(
          retry: null,
          name: r'recentlyViewedProductsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Live product entities for the recently-viewed carousel, excluding the
  /// product currently being viewed. Each id is fetched live via the same
  /// single-product endpoint the rest of the detail screen uses (not the
  /// locally-cached snapshot), so price/stock/images are always current —
  /// any id that fails to load (deleted) or is out of stock is dropped
  /// rather than shown stale/unavailable.

  RecentlyViewedProductsProvider call(
    String excludeProductId,
  ) =>
      RecentlyViewedProductsProvider._(argument: excludeProductId, from: this);

  @override
  String toString() => r'recentlyViewedProductsProvider';
}
