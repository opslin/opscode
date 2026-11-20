// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(secureStorage)
const secureStorageProvider = SecureStorageProvider._();

final class SecureStorageProvider extends $FunctionalProvider<
    SecureStorageService,
    SecureStorageService,
    SecureStorageService> with $Provider<SecureStorageService> {
  const SecureStorageProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'secureStorageProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$secureStorageHash();

  @$internal
  @override
  $ProviderElement<SecureStorageService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureStorageService create(Ref ref) {
    return secureStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureStorageService>(value),
    );
  }
}

String _$secureStorageHash() => r'c67bfca83b6a2754117438cf67e2e5f4500a66d7';

@ProviderFor(hiveService)
const hiveServiceProvider = HiveServiceProvider._();

final class HiveServiceProvider
    extends $FunctionalProvider<HiveService, HiveService, HiveService>
    with $Provider<HiveService> {
  const HiveServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'hiveServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$hiveServiceHash();

  @$internal
  @override
  $ProviderElement<HiveService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HiveService create(Ref ref) {
    return hiveService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HiveService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HiveService>(value),
    );
  }
}

String _$hiveServiceHash() => r'6c38c38e71e5b7d6775f5f6db1e69f473eef4b2d';

@ProviderFor(dioClient)
const dioClientProvider = DioClientProvider._();

final class DioClientProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  const DioClientProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dioClientProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dioClientHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return dioClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$dioClientHash() => r'3a8014d52f799ea90b30737fd4f21113eb77535a';

@ProviderFor(apiClient)
const apiClientProvider = ApiClientProvider._();

final class ApiClientProvider
    extends $FunctionalProvider<ApiClient, ApiClient, ApiClient>
    with $Provider<ApiClient> {
  const ApiClientProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'apiClientProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<ApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApiClient create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiClient>(value),
    );
  }
}

String _$apiClientHash() => r'a8e5da1c4919c73d47c4e41afc0ea0d78ea92c00';
