// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_limits_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PurchaseLimitsNotifier)
const purchaseLimitsProvider = PurchaseLimitsNotifierProvider._();

final class PurchaseLimitsNotifierProvider extends $AsyncNotifierProvider<
    PurchaseLimitsNotifier, Map<String, PurchaseLimitStatusEntity?>> {
  const PurchaseLimitsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'purchaseLimitsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$purchaseLimitsNotifierHash();

  @$internal
  @override
  PurchaseLimitsNotifier create() => PurchaseLimitsNotifier();
}

String _$purchaseLimitsNotifierHash() =>
    r'23cfac793e2ac0091def3aa5bc34602b20b9ac59';

abstract class _$PurchaseLimitsNotifier
    extends $AsyncNotifier<Map<String, PurchaseLimitStatusEntity?>> {
  FutureOr<Map<String, PurchaseLimitStatusEntity?>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<
        AsyncValue<Map<String, PurchaseLimitStatusEntity?>>,
        Map<String, PurchaseLimitStatusEntity?>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<Map<String, PurchaseLimitStatusEntity?>>,
            Map<String, PurchaseLimitStatusEntity?>>,
        AsyncValue<Map<String, PurchaseLimitStatusEntity?>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
