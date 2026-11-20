// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nav_button_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The single resolved 5th-nav-button for the current viewer, or null —
/// re-resolved (audience/segment can change) whenever this rebuilds, e.g.
/// after login/logout invalidates it the same way price-mode-sensitive
/// providers already do. No local Hive cache: the payload is tiny and a
/// stale cached button (wrong segment, expired schedule) would show the
/// wrong 5th tab until the next cache TTL — better to just ask fresh.

@ProviderFor(navButton)
const navButtonProvider = NavButtonProvider._();

/// The single resolved 5th-nav-button for the current viewer, or null —
/// re-resolved (audience/segment can change) whenever this rebuilds, e.g.
/// after login/logout invalidates it the same way price-mode-sensitive
/// providers already do. No local Hive cache: the payload is tiny and a
/// stale cached button (wrong segment, expired schedule) would show the
/// wrong 5th tab until the next cache TTL — better to just ask fresh.

final class NavButtonProvider extends $FunctionalProvider<
        AsyncValue<NavButtonEntity?>,
        NavButtonEntity?,
        FutureOr<NavButtonEntity?>>
    with $FutureModifier<NavButtonEntity?>, $FutureProvider<NavButtonEntity?> {
  /// The single resolved 5th-nav-button for the current viewer, or null —
  /// re-resolved (audience/segment can change) whenever this rebuilds, e.g.
  /// after login/logout invalidates it the same way price-mode-sensitive
  /// providers already do. No local Hive cache: the payload is tiny and a
  /// stale cached button (wrong segment, expired schedule) would show the
  /// wrong 5th tab until the next cache TTL — better to just ask fresh.
  const NavButtonProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'navButtonProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$navButtonHash();

  @$internal
  @override
  $FutureProviderElement<NavButtonEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<NavButtonEntity?> create(Ref ref) {
    return navButton(ref);
  }
}

String _$navButtonHash() => r'674371a18d7691536335dc9ead44a928ec68839a';

/// Every active PROFILE_MENU button for the current viewer (Business
/// Transaction, Games, and any others configured in the dashboard) —
/// same "never break the screen over a failed optional fetch" convention
/// as [navButton] above, and likewise no local cache (tiny payload, and a
/// stale cached list could show a button whose audience/segment no longer
/// matches this viewer).

@ProviderFor(navButtonProfileMenu)
const navButtonProfileMenuProvider = NavButtonProfileMenuProvider._();

/// Every active PROFILE_MENU button for the current viewer (Business
/// Transaction, Games, and any others configured in the dashboard) —
/// same "never break the screen over a failed optional fetch" convention
/// as [navButton] above, and likewise no local cache (tiny payload, and a
/// stale cached list could show a button whose audience/segment no longer
/// matches this viewer).

final class NavButtonProfileMenuProvider extends $FunctionalProvider<
        AsyncValue<List<NavButtonEntity>>,
        List<NavButtonEntity>,
        FutureOr<List<NavButtonEntity>>>
    with
        $FutureModifier<List<NavButtonEntity>>,
        $FutureProvider<List<NavButtonEntity>> {
  /// Every active PROFILE_MENU button for the current viewer (Business
  /// Transaction, Games, and any others configured in the dashboard) —
  /// same "never break the screen over a failed optional fetch" convention
  /// as [navButton] above, and likewise no local cache (tiny payload, and a
  /// stale cached list could show a button whose audience/segment no longer
  /// matches this viewer).
  const NavButtonProfileMenuProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'navButtonProfileMenuProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$navButtonProfileMenuHash();

  @$internal
  @override
  $FutureProviderElement<List<NavButtonEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<NavButtonEntity>> create(Ref ref) {
    return navButtonProfileMenu(ref);
  }
}

String _$navButtonProfileMenuHash() =>
    r'15584c4520133faefd085350b19a74de2b142cc8';
