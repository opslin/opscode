// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_guards.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AuthGuard)
const authGuardProvider = AuthGuardProvider._();

final class AuthGuardProvider extends $NotifierProvider<AuthGuard, void> {
  const AuthGuardProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authGuardProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authGuardHash();

  @$internal
  @override
  AuthGuard create() => AuthGuard();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$authGuardHash() => r'388d2ede0d71cc77088abcc50925f32ccd17b878';

abstract class _$AuthGuard extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<void, void>, void, Object?, Object?>;
    element.handleValue(ref, null);
  }
}
