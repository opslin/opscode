// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fcm_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fcmService)
const fcmServiceProvider = FcmServiceProvider._();

final class FcmServiceProvider
    extends $FunctionalProvider<FCMService, FCMService, FCMService>
    with $Provider<FCMService> {
  const FcmServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'fcmServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$fcmServiceHash();

  @$internal
  @override
  $ProviderElement<FCMService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FCMService create(Ref ref) {
    return fcmService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FCMService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FCMService>(value),
    );
  }
}

String _$fcmServiceHash() => r'f6f957cfec6890feca865ddaf5b6ba575c1b9409';

@ProviderFor(initializeFcm)
const initializeFcmProvider = InitializeFcmProvider._();

final class InitializeFcmProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const InitializeFcmProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'initializeFcmProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$initializeFcmHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return initializeFcm(ref);
  }
}

String _$initializeFcmHash() => r'f5ae1920048ee04be88a7942779d43863f5f6b65';
