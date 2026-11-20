// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WalletNotifier)
const walletProvider = WalletNotifierProvider._();

final class WalletNotifierProvider
    extends $AsyncNotifierProvider<WalletNotifier, WalletEntity> {
  const WalletNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'walletProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$walletNotifierHash();

  @$internal
  @override
  WalletNotifier create() => WalletNotifier();
}

String _$walletNotifierHash() => r'98ec0b3733c760163f6f5ff5f9c512395caf17bc';

abstract class _$WalletNotifier extends $AsyncNotifier<WalletEntity> {
  FutureOr<WalletEntity> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<WalletEntity>, WalletEntity>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<WalletEntity>, WalletEntity>,
        AsyncValue<WalletEntity>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
