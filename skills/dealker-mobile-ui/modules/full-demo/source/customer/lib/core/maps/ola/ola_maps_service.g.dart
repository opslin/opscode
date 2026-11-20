// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ola_maps_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(olaMapsService)
const olaMapsServiceProvider = OlaMapsServiceProvider._();

final class OlaMapsServiceProvider
    extends $FunctionalProvider<OlaMapsService, OlaMapsService, OlaMapsService>
    with $Provider<OlaMapsService> {
  const OlaMapsServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'olaMapsServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$olaMapsServiceHash();

  @$internal
  @override
  $ProviderElement<OlaMapsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OlaMapsService create(Ref ref) {
    return olaMapsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OlaMapsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OlaMapsService>(value),
    );
  }
}

String _$olaMapsServiceHash() => r'cafa3d376c641b73214571806b197d0befa703f4';

/// Cached copy of [OlaMapsService.getStyle], shared by every widget that
/// just needs a style URL to render a map (e.g. static preview thumbnails)
/// without each one triggering its own backend round-trip.

@ProviderFor(olaMapsStyle)
const olaMapsStyleProvider = OlaMapsStyleProvider._();

/// Cached copy of [OlaMapsService.getStyle], shared by every widget that
/// just needs a style URL to render a map (e.g. static preview thumbnails)
/// without each one triggering its own backend round-trip.

final class OlaMapsStyleProvider extends $FunctionalProvider<
        AsyncValue<OlaMapsStyle>, OlaMapsStyle, FutureOr<OlaMapsStyle>>
    with $FutureModifier<OlaMapsStyle>, $FutureProvider<OlaMapsStyle> {
  /// Cached copy of [OlaMapsService.getStyle], shared by every widget that
  /// just needs a style URL to render a map (e.g. static preview thumbnails)
  /// without each one triggering its own backend round-trip.
  const OlaMapsStyleProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'olaMapsStyleProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$olaMapsStyleHash();

  @$internal
  @override
  $FutureProviderElement<OlaMapsStyle> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OlaMapsStyle> create(Ref ref) {
    return olaMapsStyle(ref);
  }
}

String _$olaMapsStyleHash() => r'92609bb72e44129cf2ca029f7a22da900e9a2b56';
