// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_slot_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deliverySlots)
const deliverySlotsProvider = DeliverySlotsProvider._();

final class DeliverySlotsProvider extends $FunctionalProvider<
        AsyncValue<List<DeliverySlotDayEntity>>,
        List<DeliverySlotDayEntity>,
        FutureOr<List<DeliverySlotDayEntity>>>
    with
        $FutureModifier<List<DeliverySlotDayEntity>>,
        $FutureProvider<List<DeliverySlotDayEntity>> {
  const DeliverySlotsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'deliverySlotsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$deliverySlotsHash();

  @$internal
  @override
  $FutureProviderElement<List<DeliverySlotDayEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<DeliverySlotDayEntity>> create(Ref ref) {
    return deliverySlots(ref);
  }
}

String _$deliverySlotsHash() => r'1ea155cb45301ef655f66908534314ee1f064d72';
