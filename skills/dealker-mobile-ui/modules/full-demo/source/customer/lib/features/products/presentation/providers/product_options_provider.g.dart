// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_options_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(productOptions)
const productOptionsProvider = ProductOptionsFamily._();

final class ProductOptionsProvider extends $FunctionalProvider<
        AsyncValue<ProductOptionsResponse>,
        ProductOptionsResponse,
        FutureOr<ProductOptionsResponse>>
    with
        $FutureModifier<ProductOptionsResponse>,
        $FutureProvider<ProductOptionsResponse> {
  const ProductOptionsProvider._(
      {required ProductOptionsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'productOptionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$productOptionsHash();

  @override
  String toString() {
    return r'productOptionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ProductOptionsResponse> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ProductOptionsResponse> create(Ref ref) {
    final argument = this.argument as String;
    return productOptions(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProductOptionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$productOptionsHash() => r'0726ed6b330604e26ba97a18910ee8aa6dde6197';

final class ProductOptionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ProductOptionsResponse>, String> {
  const ProductOptionsFamily._()
      : super(
          retry: null,
          name: r'productOptionsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ProductOptionsProvider call(
    String productId,
  ) =>
      ProductOptionsProvider._(argument: productId, from: this);

  @override
  String toString() => r'productOptionsProvider';
}
