// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_account_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The caller's own business account — null when they've never applied.
/// Drives the Business Account screen and (via PriceModeNotifier) whether
/// the wholesale-pricing toggle is offered anywhere else in the app.

@ProviderFor(myBusinessAccount)
const myBusinessAccountProvider = MyBusinessAccountProvider._();

/// The caller's own business account — null when they've never applied.
/// Drives the Business Account screen and (via PriceModeNotifier) whether
/// the wholesale-pricing toggle is offered anywhere else in the app.

final class MyBusinessAccountProvider extends $FunctionalProvider<
        AsyncValue<BusinessAccountEntity?>,
        BusinessAccountEntity?,
        FutureOr<BusinessAccountEntity?>>
    with
        $FutureModifier<BusinessAccountEntity?>,
        $FutureProvider<BusinessAccountEntity?> {
  /// The caller's own business account — null when they've never applied.
  /// Drives the Business Account screen and (via PriceModeNotifier) whether
  /// the wholesale-pricing toggle is offered anywhere else in the app.
  const MyBusinessAccountProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'myBusinessAccountProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$myBusinessAccountHash();

  @$internal
  @override
  $FutureProviderElement<BusinessAccountEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<BusinessAccountEntity?> create(Ref ref) {
    return myBusinessAccount(ref);
  }
}

String _$myBusinessAccountHash() => r'b4af0269adb3660d8cf3efee23510f2e37d9ac2f';

@ProviderFor(BusinessAccountNotifier)
const businessAccountProvider = BusinessAccountNotifierProvider._();

final class BusinessAccountNotifierProvider
    extends $NotifierProvider<BusinessAccountNotifier, AsyncValue<void>> {
  const BusinessAccountNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'businessAccountProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$businessAccountNotifierHash();

  @$internal
  @override
  BusinessAccountNotifier create() => BusinessAccountNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$businessAccountNotifierHash() =>
    r'061e97babc94970d9269bb75777906e4befe240d';

abstract class _$BusinessAccountNotifier extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
        AsyncValue<void>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
