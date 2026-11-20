import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dealker_vendor/features/repair_book/shims/picked_file_upload.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/orders/data/order_models.dart';

/// Everything behind the vendor Orders section. Vendor-scoped server-side (the JWT carries the vendor).
class OrdersRepository {
  OrdersRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? query, Object? body}) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(path,
          data: body, queryParameters: query, options: Options(method: method));
      return res.data ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Map<String, int> _counts(dynamic v) => {
        for (final e in ((v as Map?) ?? const {}).entries)
          '${e.key}': (e.value as num?)?.toInt() ?? 0
      };

  Future<OrdersPage> list(OrdersQuery q, {int limit = 40}) async {
    final b = await _send('GET', '/manage/orders', query: {
      'type': q.type,
      'tab': q.tab,
      'limit': limit,
      if (q.q.isNotEmpty) 'q': q.q,
    });
    return OrdersPage(
      rows: [
        for (final r in (b['data'] as List? ?? const []))
          if (r is Map<String, dynamic>) OrderRow.fromJson(r)
      ],
      counts: _counts(b['counts']),
      types: _counts(b['types']),
      total: ((b['pagination'] as Map?)?['total'] as num?)?.toInt() ?? 0,
    );
  }

  // ── product + auction orders (seller orders) ────────────────────────

  Future<OrderDetail> detail(String id) async => OrderDetail.fromJson(
      ((await _send('GET', '/seller-orders/$id'))['data'] as Map)
          .cast<String, dynamic>());

  Future<void> setStatus(String id, String status, {String? reason}) =>
      _send('POST', '/seller-orders/$id/status',
          body: {'status': status, if (reason != null) 'reason': reason});

  /// Upload the seller's own invoice (photo) for this order — packing and shipping are blocked without it.
  Future<void> uploadInvoice(String id, XFile file, {String? number}) async {
    final form = FormData.fromMap({
      if (number != null && number.trim().isNotEmpty) 'invoiceNumber': number.trim(),
      'file': await pickedFileMultipart(file),
    });
    await _send('POST', '/seller-orders/$id/invoice', body: form);
  }

  Future<void> ship(String id,
          {required String courier, String? awb, String? trackingUrl}) =>
      _send('POST', '/seller-orders/$id/ship', body: {
        'courierName': courier,
        if (awb != null && awb.trim().isNotEmpty) 'awb': awb.trim(),
        if (trackingUrl != null && trackingUrl.trim().isNotEmpty)
          'trackingUrl': trackingUrl.trim(),
      });

  // ── repair jobs ─────────────────────────────────────────────────────

  Future<RepairDetail> repair(String id) async => RepairDetail.fromJson(
      ((await _send('GET', '/manage/repairs/$id'))['data'] as Map)
          .cast<String, dynamic>());

  /// receive | start | send-to-qc | ready | deliver | fail
  Future<void> repairAction(String id, String action,
          {Map<String, dynamic>? body}) =>
      _send('POST', '/manage/repairs/$id/$action', body: body ?? {});

  /// Final QC: one result per device being repaired. Any failure sends it back to rework.
  Future<void> repairQc(String id,
          {required List<String> itemIds,
          required bool passed,
          String? note}) =>
      _send('POST', '/manage/repairs/$id/qc', body: {
        'results': [
          for (final i in itemIds)
            {'itemId': i, 'passed': passed, if (note != null) 'notes': note}
        ],
        if (note != null) 'note': note,
      });
}
