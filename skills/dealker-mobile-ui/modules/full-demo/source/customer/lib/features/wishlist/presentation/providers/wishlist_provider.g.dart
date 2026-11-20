// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WishlistNotifier)
const wishlistProvider = WishlistNotifierProvider._();

final class WishlistNotifierProvider
    extends $AsyncNotifierProvider<WishlistNotifier, WishlistEntity> {
  const WishlistNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'wishlistProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$wishlistNotifierHash();

  @$internal
  @override
  WishlistNotifier create() => WishlistNotifier();
}

String _$wishlistNotifierHash() => r'd801253815da7008638d7c1ee2185d2e97c0a208';

abstract class _$WishlistNotifier extends $AsyncNotifier<WishlistEntity> {
  FutureOr<WishlistEntity> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<WishlistEntity>, WishlistEntity>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<WishlistEntity>, WishlistEntity>,
        AsyncValue<WishlistEntity>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
