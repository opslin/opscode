// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The caller's own ledger (B2B credit) account — null when none has been
/// set up for them by an admin yet. Drives whether "Pay via Ledger" is
/// offered at checkout.

@ProviderFor(myLedgerAccount)
const myLedgerAccountProvider = MyLedgerAccountProvider._();

/// The caller's own ledger (B2B credit) account — null when none has been
/// set up for them by an admin yet. Drives whether "Pay via Ledger" is
/// offered at checkout.

final class MyLedgerAccountProvider extends $FunctionalProvider<
        AsyncValue<LedgerAccountEntity?>,
        LedgerAccountEntity?,
        FutureOr<LedgerAccountEntity?>>
    with
        $FutureModifier<LedgerAccountEntity?>,
        $FutureProvider<LedgerAccountEntity?> {
  /// The caller's own ledger (B2B credit) account — null when none has been
  /// set up for them by an admin yet. Drives whether "Pay via Ledger" is
  /// offered at checkout.
  const MyLedgerAccountProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'myLedgerAccountProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$myLedgerAccountHash();

  @$internal
  @override
  $FutureProviderElement<LedgerAccountEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<LedgerAccountEntity?> create(Ref ref) {
    return myLedgerAccount(ref);
  }
}

String _$myLedgerAccountHash() => r'b406ca3c08bb4a5e642ed712e4bc75fb323ae636';

@ProviderFor(LedgerNotifier)
const ledgerProvider = LedgerNotifierProvider._();

final class LedgerNotifierProvider
    extends $NotifierProvider<LedgerNotifier, AsyncValue<void>> {
  const LedgerNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'ledgerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$ledgerNotifierHash();

  @$internal
  @override
  LedgerNotifier create() => LedgerNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$ledgerNotifierHash() => r'6f8cd278925d66c7e416d803c873600c6fca85d8';

abstract class _$LedgerNotifier extends $Notifier<AsyncValue<void>> {
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
