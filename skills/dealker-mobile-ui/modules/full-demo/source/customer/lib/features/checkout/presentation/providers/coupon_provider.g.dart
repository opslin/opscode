// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(availableCoupons)
const availableCouponsProvider = AvailableCouponsProvider._();

final class AvailableCouponsProvider extends $FunctionalProvider<
        AsyncValue<List<CouponEntity>>,
        List<CouponEntity>,
        FutureOr<List<CouponEntity>>>
    with
        $FutureModifier<List<CouponEntity>>,
        $FutureProvider<List<CouponEntity>> {
  const AvailableCouponsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'availableCouponsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$availableCouponsHash();

  @$internal
  @override
  $FutureProviderElement<List<CouponEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<CouponEntity>> create(Ref ref) {
    return availableCoupons(ref);
  }
}

String _$availableCouponsHash() => r'5f5763e810d4f7984ae30782b71ddc7471911b2c';
