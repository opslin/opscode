import 'package:dealker_app/core/network/api_client.dart';
import 'package:dealker_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';

class RefundRequestRemoteDataSource {
  const RefundRequestRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<void> createRequest(Map<String, dynamic> body) async {
    await _apiClient.createRefundRequest(body);
  }

  Future<RefundRequestStatusEntity?> getByOrder(String orderId) async {
    final response = await _apiClient.getRefundRequestByOrder(orderId);
    final payload = response.data;
    final data = payload is Map ? payload['data'] : null;
    if (data is! Map) {
      return null;
    }
    return parseStatus(Map<String, dynamic>.from(data));
  }

  Future<void> cancelRequest(String requestId) async {
    await _apiClient.cancelRefundRequest(requestId);
  }

  /// Customer view of a refund request (`toCustomerView` on the backend) → entity.
  static RefundRequestStatusEntity parseStatus(Map<String, dynamic> json) {
    final Object? rawEvidence = json['evidence'];
    final Object? rawTimeline = json['timeline'];
    final Object? rawItems = json['items'];
    final Object? rawPickup = json['pickup'];
    final Object? rawQc = json['qc'];
    return RefundRequestStatusEntity(
      id: (json['id'] ?? '').toString(),
      orderId: _readNullableString(json, <String>['order_id']),
      returnApprovedAt: _readDateTime(json, <String>['return_approved_at']),
      pickup: rawPickup is Map
          ? _parsePickup(Map<String, dynamic>.from(rawPickup))
          : null,
      qc: rawQc is Map ? _parseQc(Map<String, dynamic>.from(rawQc)) : null,
      orderNumber: _readNullableString(json, <String>['order_number']),
      returnNumber: _readNullableString(json, <String>['return_number']),
      reasonCode: _readNullableString(json, <String>['reason_code']),
      sellerName: _readNullableString(json, <String>['seller_name']),
      refundReference: _readNullableString(json, <String>['refund_reference']),
      refundedAt: _readDateTime(json, <String>['refunded_at']),
      resolvedAt: _readDateTime(json, <String>['resolved_at']),
      evidence: rawEvidence is List
          ? rawEvidence
              .whereType<Map>()
              .map(
                (Map e) => ReturnEvidence(
                  url: (e['url'] ?? '').toString(),
                  isVideo: e['kind'] == 'VIDEO',
                ),
              )
              .where((ReturnEvidence e) => e.url.isNotEmpty)
              .toList()
          : const <ReturnEvidence>[],
      timeline: rawTimeline is List
          ? rawTimeline
              .whereType<Map>()
              .map(
                (Map e) => ReturnTimelineStep(
                  key: (e['key'] ?? '').toString(),
                  title: (e['title'] ?? '').toString(),
                  at: DateTime.tryParse((e['at'] ?? '').toString()),
                  current: e['current'] == true,
                ),
              )
              .toList()
          : const <ReturnTimelineStep>[],
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((Map e) => (e['name'] ?? '').toString())
              .where((String n) => n.isNotEmpty)
              .toList()
          : const <String>[],
      itemScope: (json['item_scope'] ?? json['itemScope'] ?? 'ALL').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'PENDING').toString(),
      adminNote: _readNullableString(json, <String>['admin_note', 'adminNote']),
      refundAmount: _toDouble(json['refund_amount'] ?? json['refundAmount']),
      refundTo: _readNullableString(json, <String>['refund_to', 'refundTo']),
      createdAt: _readDateTime(json, <String>['created_at', 'createdAt']) ??
          DateTime.now(),
    );
  }

  static ReturnPickup _parsePickup(Map<String, dynamic> j) => ReturnPickup(
        status: (j['status'] ?? 'PICKUP_SCHEDULED').toString(),
        provider: _readNullableString(j, <String>['provider']),
        awb: _readNullableString(j, <String>['awb']),
        courierName: _readNullableString(j, <String>['courier_name']),
        trackingUrl: _readNullableString(j, <String>['tracking_url']),
        scheduledAt: _readDateTime(j, <String>['scheduled_at']),
        pickedUpAt: _readDateTime(j, <String>['picked_up_at']),
        receivedAt: _readDateTime(j, <String>['received_at']),
      );

  static ReturnQc _parseQc(Map<String, dynamic> j) {
    final Object? rawChecks = j['checks'];
    return ReturnQc(
      checks: rawChecks is List
          ? rawChecks
              .whereType<Map>()
              .map(
                (Map c) => ReturnQcCheck(
                  label: (c['label'] ?? '').toString(),
                  status: (c['status'] ?? 'OK').toString(),
                  note: (c['note'] as String?)?.trim().isEmpty ?? true
                      ? null
                      : (c['note'] as String).trim(),
                ),
              )
              .toList()
          : const <ReturnQcCheck>[],
      originalPrice: _toDouble(j['original_price']) ?? 0,
      revisedPrice: _toDouble(j['revised_price']),
      priceStatus: (j['price_status'] ?? 'NONE').toString(),
      summary: _readNullableString(j, <String>['summary']),
      customerMessage: _readNullableString(j, <String>['customer_message']),
    );
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}
