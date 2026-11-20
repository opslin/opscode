// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(productDetail)
const productDetailProvider = ProductDetailFamily._();

final class ProductDetailProvider extends $FunctionalProvider<
        AsyncValue<ProductEntity>, ProductEntity, FutureOr<ProductEntity>>
    with $FutureModifier<ProductEntity>, $FutureProvider<ProductEntity> {
  const ProductDetailProvider._(
      {required ProductDetailFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'productDetailProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$productDetailHash();

  @override
  String toString() {
    return r'productDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ProductEntity> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ProductEntity> create(Ref ref) {
    final argument = this.argument as String;
    return productDetail(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProductDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$productDetailHash() => r'01b67aea42f012cb116c7152ae25628ae11519a3';

final class ProductDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ProductEntity>, String> {
  const ProductDetailFamily._()
      : super(
          retry: null,
          name: r'productDetailProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ProductDetailProvider call(
    String productId,
  ) =>
      ProductDetailProvider._(argument: productId, from: this);

  @override
  String toString() => r'productDetailProvider';
}

@ProviderFor(relatedProducts)
const relatedProductsProvider = RelatedProductsFamily._();

final class RelatedProductsProvider extends $FunctionalProvider<
        AsyncValue<List<ProductEntity>>,
        List<ProductEntity>,
        FutureOr<List<ProductEntity>>>
    with
        $FutureModifier<List<ProductEntity>>,
        $FutureProvider<List<ProductEntity>> {
  const RelatedProductsProvider._(
      {required RelatedProductsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'relatedProductsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$relatedProductsHash();

  @override
  String toString() {
    return r'relatedProductsProvider'
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
    return relatedProducts(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RelatedProductsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$relatedProductsHash() => r'8bbe367066aba581f2e66a2645d1caa0359e1550';

final class RelatedProductsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ProductEntity>>, String> {
  const RelatedProductsFamily._()
      : super(
          retry: null,
          name: r'relatedProductsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  RelatedProductsProvider call(
    String productId,
  ) =>
      RelatedProductsProvider._(argument: productId, from: this);

  @override
  String toString() => r'relatedProductsProvider';
}

@ProviderFor(pairWithProducts)
const pairWithProductsProvider = PairWithProductsFamily._();

final class PairWithProductsProvider extends $FunctionalProvider<
        AsyncValue<List<ProductEntity>>,
        List<ProductEntity>,
        FutureOr<List<ProductEntity>>>
    with
        $FutureModifier<List<ProductEntity>>,
        $FutureProvider<List<ProductEntity>> {
  const PairWithProductsProvider._(
      {required PairWithProductsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'pairWithProductsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$pairWithProductsHash();

  @override
  String toString() {
    return r'pairWithProductsProvider'
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
    return pairWithProducts(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PairWithProductsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pairWithProductsHash() => r'e60b2a62ca1daf44b4aa1ef9216e6b6b91eae56f';

final class PairWithProductsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ProductEntity>>, String> {
  const PairWithProductsFamily._()
      : super(
          retry: null,
          name: r'pairWithProductsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  PairWithProductsProvider call(
    String productId,
  ) =>
      PairWithProductsProvider._(argument: productId, from: this);

  @override
  String toString() => r'pairWithProductsProvider';
}
