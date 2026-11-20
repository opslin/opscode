import 'package:dio/dio.dart';

/// One courier event (status text only).
class ShipmentEvent {
  const ShipmentEvent({
    required this.status,
    this.note,
    this.location,
    this.at,
  });

  final String status;
  final String? note;
  final String? location;
  final DateTime? at;
}

/// A parcel of an order with its courier (Shiprocket / Porter / Blue Dart / seller's own).
class OrderShipment {
  const OrderShipment({
    required this.status,
    required this.events,
    this.parcel,
    this.sellerName,
    this.provider,
    this.courierName,
    this.awb,
    this.estimatedDelivery,
    this.trackingUrl,
  });

  /// CREATED, ASSIGNED, PICKUP_SCHEDULED, PICKED_UP, IN_TRANSIT, OUT_FOR_DELIVERY, DELIVERED, CANCELLED, FAILED or RTO.
  final String status;
  final String? parcel;
  final String? sellerName;
  final String? provider;
  final String? courierName;
  final String? awb;
  final DateTime? estimatedDelivery;
  final String? trackingUrl;
  final List<ShipmentEvent> events;

  String get statusLabel => switch (status) {
        'CREATED' || 'ASSIGNING' || 'ASSIGNED' => 'Preparing to ship',
        'PICKUP_SCHEDULED' => 'Pickup scheduled',
        'PICKED_UP' => 'Shipped',
        'IN_TRANSIT' => 'In transit',
        'OUT_FOR_DELIVERY' => 'Out for delivery',
        'DELIVERED' => 'Delivered',
        'CANCELLED' => 'Cancelled',
        'RTO' => 'Returning to seller',
        'FAILED' => 'Delivery problem',
        _ => status.replaceAll('_', ' ').toLowerCase(),
      };
}

/// `GET /orders/:id/shipments` — courier status per parcel. Status steps only (no rider / live location).
class ShipmentRepository {
  const ShipmentRepository(this._dio);

  final Dio _dio;

  Future<List<OrderShipment>> forOrder(String orderId) async {
    final Response<dynamic> r =
        await _dio.get<dynamic>('/orders/$orderId/shipments');
    final Object? list = (r.data as Map)['data'];
    if (list is! List) return const <OrderShipment>[];
    return list.whereType<Map>().map((Map m) {
      final Object? ev = m['events'];
      return OrderShipment(
        status: '${m['status'] ?? 'CREATED'}',
        parcel: m['parcel'] as String?,
        sellerName: m['seller_name'] as String?,
        provider: m['provider'] as String?,
        courierName: m['courier_name'] as String?,
        awb: m['awb'] as String?,
        estimatedDelivery:
            DateTime.tryParse('${m['estimated_delivery'] ?? ''}')?.toLocal(),
        trackingUrl: m['tracking_url'] as String?,
        events: ev is List
            ? ev
                .whereType<Map>()
                .map(
                  (Map e) => ShipmentEvent(
                    status: '${e['status'] ?? ''}',
                    note: e['note'] as String?,
                    location: e['location'] as String?,
                    at: DateTime.tryParse('${e['at'] ?? ''}')?.toLocal(),
                  ),
                )
                .toList()
                .reversed
                .toList()
            : const <ShipmentEvent>[],
      );
    }).toList();
  }
}
