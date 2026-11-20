// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single source of truth for "is the storefront open right now" — every
/// widget that needs to gate ASAP ordering or show a "closed" message
/// (cart header, schedule sheet, checkout submit guard, and later the
/// closed-store banner / store-hours sheet) watches this one provider
/// rather than re-fetching independently.

@ProviderFor(storeStatus)
const storeStatusProvider = StoreStatusProvider._();

/// Single source of truth for "is the storefront open right now" — every
/// widget that needs to gate ASAP ordering or show a "closed" message
/// (cart header, schedule sheet, checkout submit guard, and later the
/// closed-store banner / store-hours sheet) watches this one provider
/// rather than re-fetching independently.

final class StoreStatusProvider extends $FunctionalProvider<
        AsyncValue<StoreStatusEntity>,
        StoreStatusEntity,
        FutureOr<StoreStatusEntity>>
    with
        $FutureModifier<StoreStatusEntity>,
        $FutureProvider<StoreStatusEntity> {
  /// Single source of truth for "is the storefront open right now" — every
  /// widget that needs to gate ASAP ordering or show a "closed" message
  /// (cart header, schedule sheet, checkout submit guard, and later the
  /// closed-store banner / store-hours sheet) watches this one provider
  /// rather than re-fetching independently.
  const StoreStatusProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'storeStatusProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$storeStatusHash();

  @$internal
  @override
  $FutureProviderElement<StoreStatusEntity> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<StoreStatusEntity> create(Ref ref) {
    return storeStatus(ref);
  }
}

String _$storeStatusHash() => r'15bd13cdd32dd2b7de4ec7596f9ebec8cdc7a4de';
