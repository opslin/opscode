// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(currentUser)
const currentUserProvider = CurrentUserProvider._();

final class CurrentUserProvider
    extends $FunctionalProvider<UserEntity?, UserEntity?, UserEntity?>
    with $Provider<UserEntity?> {
  const CurrentUserProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentUserProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $ProviderElement<UserEntity?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserEntity? create(Ref ref) {
    return currentUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserEntity? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserEntity?>(value),
    );
  }
}

String _$currentUserHash() => r'c9b7cbfff420e0f22a52afa9419733dfa7f89c8e';

@ProviderFor(isAuthenticated)
const isAuthenticatedProvider = IsAuthenticatedProvider._();

final class IsAuthenticatedProvider
    extends $FunctionalProvider<bool, bool, bool> with $Provider<bool> {
  const IsAuthenticatedProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isAuthenticatedProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isAuthenticatedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isAuthenticated(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isAuthenticatedHash() => r'53530df1b2318dfd64fbb3973e155dcba48f4405';

@ProviderFor(appRouter)
const appRouterProvider = AppRouterProvider._();

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  const AppRouterProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appRouterProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'e1881c424a7592be62d5ad488b7e1d9256dfa543';
