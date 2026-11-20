// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spin_wheel_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active wheel — active prizes fetched from `GET /spin-wheel/config`,
/// 2-8 entries, admin-configured. Falls back to [kSpinWheelPrizes] on any
/// failure so the dialog still renders a wheel instead of a blank/broken
/// state; [SpinWinDialog] disables the SPIN action while showing that
/// fallback (see its own doc comment — a fallback id never matches a real
/// backend spin result).

@ProviderFor(spinConfig)
const spinConfigProvider = SpinConfigProvider._();

/// The active wheel — active prizes fetched from `GET /spin-wheel/config`,
/// 2-8 entries, admin-configured. Falls back to [kSpinWheelPrizes] on any
/// failure so the dialog still renders a wheel instead of a blank/broken
/// state; [SpinWinDialog] disables the SPIN action while showing that
/// fallback (see its own doc comment — a fallback id never matches a real
/// backend spin result).

final class SpinConfigProvider extends $FunctionalProvider<
        AsyncValue<List<SpinPrize>>, List<SpinPrize>, FutureOr<List<SpinPrize>>>
    with $FutureModifier<List<SpinPrize>>, $FutureProvider<List<SpinPrize>> {
  /// The active wheel — active prizes fetched from `GET /spin-wheel/config`,
  /// 2-8 entries, admin-configured. Falls back to [kSpinWheelPrizes] on any
  /// failure so the dialog still renders a wheel instead of a blank/broken
  /// state; [SpinWinDialog] disables the SPIN action while showing that
  /// fallback (see its own doc comment — a fallback id never matches a real
  /// backend spin result).
  const SpinConfigProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'spinConfigProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$spinConfigHash();

  @$internal
  @override
  $FutureProviderElement<List<SpinPrize>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<SpinPrize>> create(Ref ref) {
    return spinConfig(ref);
  }
}

String _$spinConfigHash() => r'35699d28c2c9b992540c1f194722121b2c9aa886';

/// Popup background image + banner-box copy, dashboard-configured. Falls
/// back to an all-null [SpinAppearance] on any failure (offline, new
/// account not yet reaching this endpoint, etc.) — `spin_win_dialog.dart`
/// reads a null field as "use the bundled default asset / hardcoded copy",
/// same fail-open philosophy as [spinConfig] falling back to
/// [kSpinWheelPrizes].

@ProviderFor(spinWheelAppearance)
const spinWheelAppearanceProvider = SpinWheelAppearanceProvider._();

/// Popup background image + banner-box copy, dashboard-configured. Falls
/// back to an all-null [SpinAppearance] on any failure (offline, new
/// account not yet reaching this endpoint, etc.) — `spin_win_dialog.dart`
/// reads a null field as "use the bundled default asset / hardcoded copy",
/// same fail-open philosophy as [spinConfig] falling back to
/// [kSpinWheelPrizes].

final class SpinWheelAppearanceProvider extends $FunctionalProvider<
        AsyncValue<SpinAppearance>, SpinAppearance, FutureOr<SpinAppearance>>
    with $FutureModifier<SpinAppearance>, $FutureProvider<SpinAppearance> {
  /// Popup background image + banner-box copy, dashboard-configured. Falls
  /// back to an all-null [SpinAppearance] on any failure (offline, new
  /// account not yet reaching this endpoint, etc.) — `spin_win_dialog.dart`
  /// reads a null field as "use the bundled default asset / hardcoded copy",
  /// same fail-open philosophy as [spinConfig] falling back to
  /// [kSpinWheelPrizes].
  const SpinWheelAppearanceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'spinWheelAppearanceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$spinWheelAppearanceHash();

  @$internal
  @override
  $FutureProviderElement<SpinAppearance> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SpinAppearance> create(Ref ref) {
    return spinWheelAppearance(ref);
  }
}

String _$spinWheelAppearanceHash() =>
    r'e353b01fa0a9c6da63ddeea6ef83b0659a159ad4';

/// Whether the fetched wheel is real (backend-configured) vs. the offline
/// fallback — [SpinWinDialog] uses this to decide whether SPIN is allowed.

@ProviderFor(spinConfigIsLive)
const spinConfigIsLiveProvider = SpinConfigIsLiveProvider._();

/// Whether the fetched wheel is real (backend-configured) vs. the offline
/// fallback — [SpinWinDialog] uses this to decide whether SPIN is allowed.

final class SpinConfigIsLiveProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the fetched wheel is real (backend-configured) vs. the offline
  /// fallback — [SpinWinDialog] uses this to decide whether SPIN is allowed.
  const SpinConfigIsLiveProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'spinConfigIsLiveProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$spinConfigIsLiveHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return spinConfigIsLive(ref);
  }
}

String _$spinConfigIsLiveHash() => r'cd8549690f13c2f5f70d414c9a7f6d2d0e5c7d73';

/// How many spins the user has right now, and where the popup should
/// auto-trigger. Deliberately a plain [FutureProvider] (not keepAlive) —
/// re-fetched fresh every time something reads it (see
/// `spin_win_dialog.dart`'s `ref.invalidate` after each spin, and
/// `home_screen.dart`'s one-shot read on the onboarding chain).

@ProviderFor(spinEligibility)
const spinEligibilityProvider = SpinEligibilityProvider._();

/// How many spins the user has right now, and where the popup should
/// auto-trigger. Deliberately a plain [FutureProvider] (not keepAlive) —
/// re-fetched fresh every time something reads it (see
/// `spin_win_dialog.dart`'s `ref.invalidate` after each spin, and
/// `home_screen.dart`'s one-shot read on the onboarding chain).

final class SpinEligibilityProvider extends $FunctionalProvider<
        AsyncValue<SpinEligibility>, SpinEligibility, FutureOr<SpinEligibility>>
    with $FutureModifier<SpinEligibility>, $FutureProvider<SpinEligibility> {
  /// How many spins the user has right now, and where the popup should
  /// auto-trigger. Deliberately a plain [FutureProvider] (not keepAlive) —
  /// re-fetched fresh every time something reads it (see
  /// `spin_win_dialog.dart`'s `ref.invalidate` after each spin, and
  /// `home_screen.dart`'s one-shot read on the onboarding chain).
  const SpinEligibilityProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'spinEligibilityProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$spinEligibilityHash();

  @$internal
  @override
  $FutureProviderElement<SpinEligibility> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SpinEligibility> create(Ref ref) {
    return spinEligibility(ref);
  }
}

String _$spinEligibilityHash() => r'247f62ed9ed52bb54764324cb8b7a8c54a075050';
