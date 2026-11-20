// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist_ids_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(wishlistIds)
const wishlistIdsProvider = WishlistIdsProvider._();

final class WishlistIdsProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  const WishlistIdsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'wishlistIdsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$wishlistIdsHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return wishlistIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$wishlistIdsHash() => r'54fa78b9dbd560c2d7568cdbae7ea953e2bc0ef3';
