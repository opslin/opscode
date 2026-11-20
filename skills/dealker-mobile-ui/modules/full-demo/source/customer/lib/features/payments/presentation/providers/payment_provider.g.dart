// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(walletBalance)
const walletBalanceProvider = WalletBalanceProvider._();

final class WalletBalanceProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  const WalletBalanceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'walletBalanceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$walletBalanceHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return walletBalance(ref);
  }
}

String _$walletBalanceHash() => r'33a5e72a109dbd80e1271dbc1150b78ace8d6989';

@ProviderFor(PaymentNotifier)
const paymentProvider = PaymentNotifierProvider._();

final class PaymentNotifierProvider
    extends $NotifierProvider<PaymentNotifier, PaymentState> {
  const PaymentNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'paymentProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$paymentNotifierHash();

  @$internal
  @override
  PaymentNotifier create() => PaymentNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentState>(value),
    );
  }
}

String _$paymentNotifierHash() => r'e64993d753f47a29886d90db9f5d6e1c70cb7e99';

abstract class _$PaymentNotifier extends $Notifier<PaymentState> {
  PaymentState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PaymentState, PaymentState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<PaymentState, PaymentState>,
        PaymentState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
