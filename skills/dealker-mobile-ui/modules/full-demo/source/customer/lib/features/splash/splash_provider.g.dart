// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'splash_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SplashController)
const splashControllerProvider = SplashControllerProvider._();

final class SplashControllerProvider
    extends $NotifierProvider<SplashController, void> {
  const SplashControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'splashControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$splashControllerHash();

  @$internal
  @override
  SplashController create() => SplashController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$splashControllerHash() => r'263ddcc4d629a7bbb833d469a35b0df590cd5121';

abstract class _$SplashController extends $Notifier<void> {
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
