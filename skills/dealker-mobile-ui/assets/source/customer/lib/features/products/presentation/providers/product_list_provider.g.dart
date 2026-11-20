// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProductListNotifier)
const productListProvider = ProductListNotifierFamily._();

final class ProductListNotifierProvider
    extends $AsyncNotifierProvider<ProductListNotifier, ProductListViewState> {
  const ProductListNotifierProvider._(
      {required ProductListNotifierFamily super.from,
      required ProductListParams super.argument})
      : super(
          retry: null,
          name: r'productListProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$productListNotifierHash();

  @override
  String toString() {
    return r'productListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProductListNotifier create() => ProductListNotifier();

  @override
  bool operator ==(Object other) {
    return other is ProductListNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$productListNotifierHash() =>
    r'406b37cddf58602821abb7ee6250c47a45295409';

final class ProductListNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
            ProductListNotifier,
            AsyncValue<ProductListViewState>,
            ProductListViewState,
            FutureOr<ProductListViewState>,
            ProductListParams> {
  const ProductListNotifierFamily._()
      : super(
          retry: null,
          name: r'productListProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ProductListNotifierProvider call(
    ProductListParams params,
  ) =>
      ProductListNotifierProvider._(argument: params, from: this);

  @override
  String toString() => r'productListProvider';
}

abstract class _$ProductListNotifier
    extends $AsyncNotifier<ProductListViewState> {
  late final _$args = ref.$arg as ProductListParams;
  ProductListParams get params => _$args;

  FutureOr<ProductListViewState> build(
    ProductListParams params,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref
        as $Ref<AsyncValue<ProductListViewState>, ProductListViewState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<ProductListViewState>, ProductListViewState>,
        AsyncValue<ProductListViewState>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
