// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_enhancement_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BillSummaryNotifier)
const billSummaryProvider = BillSummaryNotifierProvider._();

final class BillSummaryNotifierProvider
    extends $AsyncNotifierProvider<BillSummaryNotifier, BillSummaryEntity> {
  const BillSummaryNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'billSummaryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$billSummaryNotifierHash();

  @$internal
  @override
  BillSummaryNotifier create() => BillSummaryNotifier();
}

String _$billSummaryNotifierHash() =>
    r'10e76e105004e6c3d604f16855a0dc398192c3c3';

abstract class _$BillSummaryNotifier extends $AsyncNotifier<BillSummaryEntity> {
  FutureOr<BillSummaryEntity> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<BillSummaryEntity>, BillSummaryEntity>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<BillSummaryEntity>, BillSummaryEntity>,
        AsyncValue<BillSummaryEntity>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(PaymentOffersNotifier)
const paymentOffersProvider = PaymentOffersNotifierProvider._();

final class PaymentOffersNotifierProvider extends $AsyncNotifierProvider<
    PaymentOffersNotifier, List<PaymentOfferEntity>> {
  const PaymentOffersNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'paymentOffersProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$paymentOffersNotifierHash();

  @$internal
  @override
  PaymentOffersNotifier create() => PaymentOffersNotifier();
}

String _$paymentOffersNotifierHash() =>
    r'9ec1baa30f655eba654f00a51154a0514ed16b37';

abstract class _$PaymentOffersNotifier
    extends $AsyncNotifier<List<PaymentOfferEntity>> {
  FutureOr<List<PaymentOfferEntity>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref
        as $Ref<AsyncValue<List<PaymentOfferEntity>>, List<PaymentOfferEntity>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<PaymentOfferEntity>>,
            List<PaymentOfferEntity>>,
        AsyncValue<List<PaymentOfferEntity>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(tipPresets)
const tipPresetsProvider = TipPresetsProvider._();

final class TipPresetsProvider extends $FunctionalProvider<
        AsyncValue<List<TipPresetEntity>>,
        List<TipPresetEntity>,
        FutureOr<List<TipPresetEntity>>>
    with
        $FutureModifier<List<TipPresetEntity>>,
        $FutureProvider<List<TipPresetEntity>> {
  const TipPresetsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tipPresetsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tipPresetsHash();

  @$internal
  @override
  $FutureProviderElement<List<TipPresetEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<TipPresetEntity>> create(Ref ref) {
    return tipPresets(ref);
  }
}

String _$tipPresetsHash() => r'e2ecf039c897f2ce64d18a2ed09623f2bdfccc7c';

@ProviderFor(CartTipNotifier)
const cartTipProvider = CartTipNotifierProvider._();

final class CartTipNotifierProvider
    extends $NotifierProvider<CartTipNotifier, double> {
  const CartTipNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'cartTipProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$cartTipNotifierHash();

  @$internal
  @override
  CartTipNotifier create() => CartTipNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$cartTipNotifierHash() => r'daf77b7b5bc755b6c17b74ff4dbc0f57e73f7807';

abstract class _$CartTipNotifier extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<double, double>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<double, double>, double, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(DeliveryInstructionsNotifier)
const deliveryInstructionsProvider = DeliveryInstructionsNotifierProvider._();

final class DeliveryInstructionsNotifierProvider
    extends $NotifierProvider<DeliveryInstructionsNotifier, String> {
  const DeliveryInstructionsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'deliveryInstructionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$deliveryInstructionsNotifierHash();

  @$internal
  @override
  DeliveryInstructionsNotifier create() => DeliveryInstructionsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$deliveryInstructionsNotifierHash() =>
    r'8e18285ec91b68819b22a9883ff492cc55117cfa';

abstract class _$DeliveryInstructionsNotifier extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<String, String>, String, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(priceDropProducts)
const priceDropProductsProvider = PriceDropProductsProvider._();

final class PriceDropProductsProvider extends $FunctionalProvider<
        AsyncValue<List<Map<String, dynamic>>>,
        List<Map<String, dynamic>>,
        FutureOr<List<Map<String, dynamic>>>>
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  const PriceDropProductsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'priceDropProductsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$priceDropProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    return priceDropProducts(ref);
  }
}

String _$priceDropProductsHash() => r'32c576568e62c03bc1bd14cd27f1e6e86a30f62e';

@ProviderFor(lastMinuteProducts)
const lastMinuteProductsProvider = LastMinuteProductsProvider._();

final class LastMinuteProductsProvider extends $FunctionalProvider<
        AsyncValue<List<Map<String, dynamic>>>,
        List<Map<String, dynamic>>,
        FutureOr<List<Map<String, dynamic>>>>
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  const LastMinuteProductsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'lastMinuteProductsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$lastMinuteProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    return lastMinuteProducts(ref);
  }
}

String _$lastMinuteProductsHash() =>
    r'16bfc4574a2e786eaab24646d88ebb335b611195';

/// "Quick Add" rail on the cart screen — ~60% popular items from the same
/// categories already in the cart, ~30% from admin-configured related
/// categories, and the remainder a random popular pick (all resolved
/// server-side in cart.controller.js#getQuickAdd, which already excludes
/// whatever's currently in the cart). Re-fetches on every cart change since
/// the backend needs the up-to-date item/category set to exclude correctly.

@ProviderFor(cartQuickAddProducts)
const cartQuickAddProductsProvider = CartQuickAddProductsProvider._();

/// "Quick Add" rail on the cart screen — ~60% popular items from the same
/// categories already in the cart, ~30% from admin-configured related
/// categories, and the remainder a random popular pick (all resolved
/// server-side in cart.controller.js#getQuickAdd, which already excludes
/// whatever's currently in the cart). Re-fetches on every cart change since
/// the backend needs the up-to-date item/category set to exclude correctly.

final class CartQuickAddProductsProvider extends $FunctionalProvider<
        AsyncValue<List<ProductEntity>>,
        List<ProductEntity>,
        FutureOr<List<ProductEntity>>>
    with
        $FutureModifier<List<ProductEntity>>,
        $FutureProvider<List<ProductEntity>> {
  /// "Quick Add" rail on the cart screen — ~60% popular items from the same
  /// categories already in the cart, ~30% from admin-configured related
  /// categories, and the remainder a random popular pick (all resolved
  /// server-side in cart.controller.js#getQuickAdd, which already excludes
  /// whatever's currently in the cart). Re-fetches on every cart change since
  /// the backend needs the up-to-date item/category set to exclude correctly.
  const CartQuickAddProductsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'cartQuickAddProductsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$cartQuickAddProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<ProductEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProductEntity>> create(Ref ref) {
    return cartQuickAddProducts(ref);
  }
}

String _$cartQuickAddProductsHash() =>
    r'1ba11536149ce10b442b87206d81724e6a3eff68';

@ProviderFor(cartSelectedAddress)
const cartSelectedAddressProvider = CartSelectedAddressProvider._();

final class CartSelectedAddressProvider
    extends $FunctionalProvider<AddressEntity?, AddressEntity?, AddressEntity?>
    with $Provider<AddressEntity?> {
  const CartSelectedAddressProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'cartSelectedAddressProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$cartSelectedAddressHash();

  @$internal
  @override
  $ProviderElement<AddressEntity?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AddressEntity? create(Ref ref) {
    return cartSelectedAddress(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AddressEntity? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AddressEntity?>(value),
    );
  }
}

String _$cartSelectedAddressHash() =>
    r'bcb3ca5881a32a24cb880d25100314c5c54657ee';

@ProviderFor(TipTabNotifier)
const tipTabProvider = TipTabNotifierProvider._();

final class TipTabNotifierProvider
    extends $NotifierProvider<TipTabNotifier, int> {
  const TipTabNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tipTabProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tipTabNotifierHash();

  @$internal
  @override
  TipTabNotifier create() => TipTabNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$tipTabNotifierHash() => r'b80bb671f8a67af80226219d29231fa781cd12bb';

abstract class _$TipTabNotifier extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element = ref.element
        as $ClassProviderElement<AnyNotifier<int, int>, int, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
