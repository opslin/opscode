// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CartNotifier)
const cartProvider = CartNotifierProvider._();

final class CartNotifierProvider
    extends $AsyncNotifierProvider<CartNotifier, CartEntity> {
  const CartNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'cartProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$cartNotifierHash();

  @$internal
  @override
  CartNotifier create() => CartNotifier();
}

String _$cartNotifierHash() => r'51ef16bfc0697e0dc773858b754db15c8bd5c778';

abstract class _$CartNotifier extends $AsyncNotifier<CartEntity> {
  FutureOr<CartEntity> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<CartEntity>, CartEntity>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<CartEntity>, CartEntity>,
        AsyncValue<CartEntity>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(cartCount)
const cartCountProvider = CartCountProvider._();

final class CartCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  const CartCountProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'cartCountProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$cartCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return cartCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$cartCountHash() => r'ea004be32cd98d3735207c8d567bc3813f175b95';

@ProviderFor(cartItemQuantity)
const cartItemQuantityProvider = CartItemQuantityFamily._();

final class CartItemQuantityProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  const CartItemQuantityProvider._(
      {required CartItemQuantityFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'cartItemQuantityProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$cartItemQuantityHash();

  @override
  String toString() {
    return r'cartItemQuantityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    final argument = this.argument as String;
    return cartItemQuantity(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CartItemQuantityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cartItemQuantityHash() => r'b59d604c2858be735b8b8da4d58ba7e1eb76ce9f';

final class CartItemQuantityFamily extends $Family
    with $FunctionalFamilyOverride<int, String> {
  const CartItemQuantityFamily._()
      : super(
          retry: null,
          name: r'cartItemQuantityProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  CartItemQuantityProvider call(
    String productId,
  ) =>
      CartItemQuantityProvider._(argument: productId, from: this);

  @override
  String toString() => r'cartItemQuantityProvider';
}
