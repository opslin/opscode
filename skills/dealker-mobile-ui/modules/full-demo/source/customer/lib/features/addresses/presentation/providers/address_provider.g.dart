// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AddressNotifier)
const addressProvider = AddressNotifierProvider._();

final class AddressNotifierProvider
    extends $AsyncNotifierProvider<AddressNotifier, List<AddressEntity>> {
  const AddressNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'addressProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$addressNotifierHash();

  @$internal
  @override
  AddressNotifier create() => AddressNotifier();
}

String _$addressNotifierHash() => r'500590c5938f7c47c2bb6dbd32e0e984f07fc451';

abstract class _$AddressNotifier extends $AsyncNotifier<List<AddressEntity>> {
  FutureOr<List<AddressEntity>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<AddressEntity>>, List<AddressEntity>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<AddressEntity>>, List<AddressEntity>>,
        AsyncValue<List<AddressEntity>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
