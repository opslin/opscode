// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active price mode — server-authoritative (mirrors the business
/// account's b2b_enabled once APPROVED), with a Hive-backed value used only
/// as a fast-launch guess so the UI doesn't flash 'retail' for a split
/// second on every cold start before the live account status loads.
///
/// [toggle] is the single place that flips B2B pricing on/off across the
/// whole app: it calls PATCH /business-accounts/me/toggle, then drops every
/// cache that could otherwise keep showing prices from the old mode
/// (product list/detail cache, cart, and — since audience follows the same
/// APPROVED+enabled flag — the active theme/banners).

@ProviderFor(PriceModeNotifier)
const priceModeProvider = PriceModeNotifierProvider._();

/// The active price mode — server-authoritative (mirrors the business
/// account's b2b_enabled once APPROVED), with a Hive-backed value used only
/// as a fast-launch guess so the UI doesn't flash 'retail' for a split
/// second on every cold start before the live account status loads.
///
/// [toggle] is the single place that flips B2B pricing on/off across the
/// whole app: it calls PATCH /business-accounts/me/toggle, then drops every
/// cache that could otherwise keep showing prices from the old mode
/// (product list/detail cache, cart, and — since audience follows the same
/// APPROVED+enabled flag — the active theme/banners).
final class PriceModeNotifierProvider
    extends $NotifierProvider<PriceModeNotifier, PriceMode> {
  /// The active price mode — server-authoritative (mirrors the business
  /// account's b2b_enabled once APPROVED), with a Hive-backed value used only
  /// as a fast-launch guess so the UI doesn't flash 'retail' for a split
  /// second on every cold start before the live account status loads.
  ///
  /// [toggle] is the single place that flips B2B pricing on/off across the
  /// whole app: it calls PATCH /business-accounts/me/toggle, then drops every
  /// cache that could otherwise keep showing prices from the old mode
  /// (product list/detail cache, cart, and — since audience follows the same
  /// APPROVED+enabled flag — the active theme/banners).
  const PriceModeNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'priceModeProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$priceModeNotifierHash();

  @$internal
  @override
  PriceModeNotifier create() => PriceModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PriceMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PriceMode>(value),
    );
  }
}

String _$priceModeNotifierHash() => r'f2a2cfe26b328f6e114f0d030d0e9bec748caaf5';

/// The active price mode — server-authoritative (mirrors the business
/// account's b2b_enabled once APPROVED), with a Hive-backed value used only
/// as a fast-launch guess so the UI doesn't flash 'retail' for a split
/// second on every cold start before the live account status loads.
///
/// [toggle] is the single place that flips B2B pricing on/off across the
/// whole app: it calls PATCH /business-accounts/me/toggle, then drops every
/// cache that could otherwise keep showing prices from the old mode
/// (product list/detail cache, cart, and — since audience follows the same
/// APPROVED+enabled flag — the active theme/banners).

abstract class _$PriceModeNotifier extends $Notifier<PriceMode> {
  PriceMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PriceMode, PriceMode>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<PriceMode, PriceMode>, PriceMode, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

/// Whether the current price mode is wholesale — a plain bool convenience
/// for widgets that don't need the enum itself (e.g. a "Wholesale pricing
/// active" banner on the cart/product screens).

@ProviderFor(isWholesalePricingActive)
const isWholesalePricingActiveProvider = IsWholesalePricingActiveProvider._();

/// Whether the current price mode is wholesale — a plain bool convenience
/// for widgets that don't need the enum itself (e.g. a "Wholesale pricing
/// active" banner on the cart/product screens).

final class IsWholesalePricingActiveProvider
    extends $FunctionalProvider<bool, bool, bool> with $Provider<bool> {
  /// Whether the current price mode is wholesale — a plain bool convenience
  /// for widgets that don't need the enum itself (e.g. a "Wholesale pricing
  /// active" banner on the cart/product screens).
  const IsWholesalePricingActiveProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isWholesalePricingActiveProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isWholesalePricingActiveHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isWholesalePricingActive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isWholesalePricingActiveHash() =>
    r'15cfc9f6a7861e36e75bc93f4975acf767193458';
