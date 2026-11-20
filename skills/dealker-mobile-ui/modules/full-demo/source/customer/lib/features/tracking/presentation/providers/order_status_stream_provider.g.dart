// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_status_stream_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(orderStatusStream)
const orderStatusStreamProvider = OrderStatusStreamProvider._();

final class OrderStatusStreamProvider extends $FunctionalProvider<
        AsyncValue<OrderStatusEvent>,
        OrderStatusEvent,
        Stream<OrderStatusEvent>>
    with $FutureModifier<OrderStatusEvent>, $StreamProvider<OrderStatusEvent> {
  const OrderStatusStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'orderStatusStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$orderStatusStreamHash();

  @$internal
  @override
  $StreamProviderElement<OrderStatusEvent> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<OrderStatusEvent> create(Ref ref) {
    return orderStatusStream(ref);
  }
}

String _$orderStatusStreamHash() => r'70db2ec0662318c9c2ca38c1c1ec1b189c247ab5';
