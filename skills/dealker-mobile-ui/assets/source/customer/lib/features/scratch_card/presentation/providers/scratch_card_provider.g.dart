// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scratch_card_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cover ("foil") image, dashboard-configured. Falls back to an all-null
/// [ScratchAppearance] on any failure — `scratch_card_dialog.dart` reads a
/// null cover as "use a plain branded color instead of an image", same
/// fail-open philosophy as spin-wheel's appearance provider.
///
/// `keepAlive: true` deliberately, unlike most providers in this feature —
/// this rarely changes, and the popup can open/close many times in one
/// session (auto-prompt, then Profile tile, then again...). Without it,
/// autoDispose tears this down moments after each close, so the NEXT open
/// briefly shows the default foil again while it re-fetches — a visible
/// "wrong cover flashes before the real one" flicker on every open after
/// the first. Caching for the session's lifetime means only the very
/// first open ever pays that fetch.

@ProviderFor(scratchCardAppearance)
const scratchCardAppearanceProvider = ScratchCardAppearanceProvider._();

/// Cover ("foil") image, dashboard-configured. Falls back to an all-null
/// [ScratchAppearance] on any failure — `scratch_card_dialog.dart` reads a
/// null cover as "use a plain branded color instead of an image", same
/// fail-open philosophy as spin-wheel's appearance provider.
///
/// `keepAlive: true` deliberately, unlike most providers in this feature —
/// this rarely changes, and the popup can open/close many times in one
/// session (auto-prompt, then Profile tile, then again...). Without it,
/// autoDispose tears this down moments after each close, so the NEXT open
/// briefly shows the default foil again while it re-fetches — a visible
/// "wrong cover flashes before the real one" flicker on every open after
/// the first. Caching for the session's lifetime means only the very
/// first open ever pays that fetch.

final class ScratchCardAppearanceProvider extends $FunctionalProvider<
        AsyncValue<ScratchAppearance>,
        ScratchAppearance,
        FutureOr<ScratchAppearance>>
    with
        $FutureModifier<ScratchAppearance>,
        $FutureProvider<ScratchAppearance> {
  /// Cover ("foil") image, dashboard-configured. Falls back to an all-null
  /// [ScratchAppearance] on any failure — `scratch_card_dialog.dart` reads a
  /// null cover as "use a plain branded color instead of an image", same
  /// fail-open philosophy as spin-wheel's appearance provider.
  ///
  /// `keepAlive: true` deliberately, unlike most providers in this feature —
  /// this rarely changes, and the popup can open/close many times in one
  /// session (auto-prompt, then Profile tile, then again...). Without it,
  /// autoDispose tears this down moments after each close, so the NEXT open
  /// briefly shows the default foil again while it re-fetches — a visible
  /// "wrong cover flashes before the real one" flicker on every open after
  /// the first. Caching for the session's lifetime means only the very
  /// first open ever pays that fetch.
  const ScratchCardAppearanceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'scratchCardAppearanceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$scratchCardAppearanceHash();

  @$internal
  @override
  $FutureProviderElement<ScratchAppearance> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ScratchAppearance> create(Ref ref) {
    return scratchCardAppearance(ref);
  }
}

String _$scratchCardAppearanceHash() =>
    r'a422cfbb71527e45ae96bde7ecbd42c9c2b081ef';

/// How many scratch cards the user has right now, and where the popup
/// should auto-trigger. Deliberately a plain [FutureProvider] (not
/// keepAlive), same reasoning as spinEligibilityProvider — re-fetched fresh
/// every time something reads it.

@ProviderFor(scratchEligibility)
const scratchEligibilityProvider = ScratchEligibilityProvider._();

/// How many scratch cards the user has right now, and where the popup
/// should auto-trigger. Deliberately a plain [FutureProvider] (not
/// keepAlive), same reasoning as spinEligibilityProvider — re-fetched fresh
/// every time something reads it.

final class ScratchEligibilityProvider extends $FunctionalProvider<
        AsyncValue<ScratchEligibility>,
        ScratchEligibility,
        FutureOr<ScratchEligibility>>
    with
        $FutureModifier<ScratchEligibility>,
        $FutureProvider<ScratchEligibility> {
  /// How many scratch cards the user has right now, and where the popup
  /// should auto-trigger. Deliberately a plain [FutureProvider] (not
  /// keepAlive), same reasoning as spinEligibilityProvider — re-fetched fresh
  /// every time something reads it.
  const ScratchEligibilityProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'scratchEligibilityProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$scratchEligibilityHash();

  @$internal
  @override
  $FutureProviderElement<ScratchEligibility> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ScratchEligibility> create(Ref ref) {
    return scratchEligibility(ref);
  }
}

String _$scratchEligibilityHash() =>
    r'130624ea20930fb117c030cb5c2aefce9345f5f1';
