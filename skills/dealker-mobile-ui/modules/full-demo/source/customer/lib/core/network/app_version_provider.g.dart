// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_version_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Checked once per app launch, entirely independent of auth state and of
/// [dioClientProvider]'s shared interceptor chain (availability monitoring,
/// auth-refresh, etc.) — a bare, short-timeout client so a slow/unreachable
/// backend can never affect anything else in the app, and always fails open
/// (returns [AppVersionCheckResult.none]) rather than blocking the app on a
/// network hiccup.

@ProviderFor(appVersionCheck)
const appVersionCheckProvider = AppVersionCheckProvider._();

/// Checked once per app launch, entirely independent of auth state and of
/// [dioClientProvider]'s shared interceptor chain (availability monitoring,
/// auth-refresh, etc.) — a bare, short-timeout client so a slow/unreachable
/// backend can never affect anything else in the app, and always fails open
/// (returns [AppVersionCheckResult.none]) rather than blocking the app on a
/// network hiccup.

final class AppVersionCheckProvider extends $FunctionalProvider<
        AsyncValue<AppVersionCheckResult>,
        AppVersionCheckResult,
        FutureOr<AppVersionCheckResult>>
    with
        $FutureModifier<AppVersionCheckResult>,
        $FutureProvider<AppVersionCheckResult> {
  /// Checked once per app launch, entirely independent of auth state and of
  /// [dioClientProvider]'s shared interceptor chain (availability monitoring,
  /// auth-refresh, etc.) — a bare, short-timeout client so a slow/unreachable
  /// backend can never affect anything else in the app, and always fails open
  /// (returns [AppVersionCheckResult.none]) rather than blocking the app on a
  /// network hiccup.
  const AppVersionCheckProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appVersionCheckProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appVersionCheckHash();

  @$internal
  @override
  $FutureProviderElement<AppVersionCheckResult> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppVersionCheckResult> create(Ref ref) {
    return appVersionCheck(ref);
  }
}

String _$appVersionCheckHash() => r'a6cc1df512db729f15a64cbef6384aa7508500bf';
