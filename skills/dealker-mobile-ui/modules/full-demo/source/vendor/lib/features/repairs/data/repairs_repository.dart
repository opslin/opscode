import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';

const _base = '/manage/repairs';

/// Everything behind the vendor Repair flow. Vendor-scoped server-side (the JWT carries the vendor).
class RepairsRepository {
  RepairsRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? query, Object? body, Options? options}) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(path,
          data: body,
          queryParameters: query,
          options: (options ?? Options()).copyWith(method: method));
      return res.data ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> b) =>
      (b['data'] as Map?)?.cast<String, dynamic>() ?? const {};

  // ── inbox ────────────────────────────────────────────────────────────

  /// tab: all (new + quoted) | new | quoted | rejected
  Future<IncomingPage> incoming(String tab) async {
    final d = _data(
        await _send('GET', '$_base/market/incoming', query: {'tab': tab}));
    return IncomingPage(
      [
        for (final r in (d['items'] as List? ?? const []))
          if (r is Map) IncomingRequest.fromJson(r.cast<String, dynamic>())
      ],
      IncomingCounts.fromJson(
          (d['counts'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }

  Future<IncomingRequest> incomingDetail(String id) async =>
      IncomingRequest.fromJson(
          _data(await _send('GET', '$_base/market/incoming/$id')));

  Future<SuggestedQuote> suggestedQuote(String id) async =>
      SuggestedQuote.fromJson(_data(
          await _send('GET', '$_base/market/incoming/$id/suggested-quote')));

  /// Signed link for one customer photo (relative to the API host).
  Future<String> incomingMediaUrl(String requestId, String mediaId) async =>
      '${_data(await _send('GET', '$_base/market/incoming/$requestId/media/$mediaId/link'))['url']}';

  Future<void> decline(String id, {String? reason}) =>
      _send('POST', '$_base/market/incoming/$id/decline', body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()
      });

  Future<void> undecline(String id) =>
      _send('DELETE', '$_base/market/incoming/$id/decline');

  Future<MyOffer> sendOffer(
    String id, {
    required List<QuoteLine> lines,
    required int estDaysMin,
    required int estDaysMax,
    required int warrantyDays,
    required bool pickupDelivery,
    required bool shopVisit,
    num discount = 0,
    String? note,
  }) async =>
      MyOffer.fromJson(
          _data(await _send('POST', '$_base/market/incoming/$id/offer', body: {
        'lines': [for (final l in lines) l.toJson()],
        'estDaysMin': estDaysMin,
        'estDaysMax': estDaysMax,
        'warrantyDays': warrantyDays,
        'pickupDelivery': pickupDelivery,
        'shopVisit': shopVisit,
        if (discount > 0) 'discount': discount,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      })));

  Future<void> withdrawOffer(String id) =>
      _send('DELETE', '$_base/market/incoming/$id/offer');

  // ── my jobs ──────────────────────────────────────────────────────────

  /// tab: active | completed
  Future<List<JobRow>> jobs(String tab) async {
    final d =
        _data(await _send('GET', _base, query: {'tab': tab, 'limit': 50}));
    return [
      for (final r in (d['items'] as List? ?? const []))
        if (r is Map) JobRow.fromJson(r.cast<String, dynamic>())
    ];
  }

  /// The shop's own price-list prices for this job's phones and problems (`missing` = no saved price).
  Future<SuggestedQuote> jobSuggestedQuote(String id) async =>
      SuggestedQuote.fromJson(
          _data(await _send('GET', '$_base/$id/suggested-quote')));

  /// Sends the shop's price to the customer for approval (one line per phone and problem).
  Future<RepairJob> sendEstimate(String id,
          {required List<QuoteLine> lines, String? note}) =>
      step(id, 'quotes', body: {
        'lines': [for (final l in lines) l.toJson()],
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  Future<RepairJob> job(String id) async =>
      RepairJob.fromJson(_data(await _send('GET', '$_base/$id')));

  /// receive | start | send-to-qc | ready | deliver | confirm-price | picked-up …
  Future<RepairJob> step(String id, String action,
          {Map<String, dynamic>? body}) async =>
      RepairJob.fromJson(
          _data(await _send('POST', '$_base/$id/$action', body: body ?? {})));

  Future<RepairJob> schedulePickup(String id, DateTime slot, {String? note}) =>
      step(id, 'schedule-pickup', body: {
        'slot': slot.toUtc().toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  Future<RepairJob> outForDelivery(String id,
          {String? courier, String? trackingUrl}) =>
      step(id, 'out-for-delivery', body: {
        if (courier != null && courier.trim().isNotEmpty)
          'courier': courier.trim(),
        if (trackingUrl != null && trackingUrl.trim().isNotEmpty)
          'trackingUrl': trackingUrl.trim(),
      });

  Future<RepairJob> qc(String id,
          {required List<String> itemIds,
          required bool passed,
          String? note}) =>
      step(id, 'qc', body: {
        'results': [
          for (final i in itemIds)
            {
              'itemId': i,
              'passed': passed,
              if (note != null && note.isNotEmpty) 'notes': note
            }
        ],
      });

  /// Technician update. All extras are optional; the server validates them.
  Future<RepairJob> update(
    String id, {
    required String stage,
    String? note,
    bool notify = true,
    List<String> mediaIds = const [],
    String? issue,
    String? issueStatus,
    String? itemId,
    List<String> beforeMediaIds = const [],
    ({String name, num? price, int warrantyDays})? part,
    List<({String key, String label, String result})>? checks,
  }) =>
      step(id, 'update', body: {
        'stage': stage,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'notify': notify,
        if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
        if (beforeMediaIds.isNotEmpty) 'beforeMediaIds': beforeMediaIds,
        if (issue != null) 'issue': issue,
        if (issueStatus != null) 'issueStatus': issueStatus,
        if (itemId != null) 'itemId': itemId,
        if (part != null)
          'part': {
            'name': part.name,
            if (part.price != null) 'price': part.price,
            'warrantyDays': part.warrantyDays,
          },
        if (checks != null)
          'checks': [
            for (final c in checks)
              {'key': c.key, 'label': c.label, 'result': c.result}
          ],
      });

  Future<RepairJob> setTechnician(String id,
          {required String name, String? phone}) async =>
      RepairJob.fromJson(
          _data(await _send('PUT', '$_base/$id/technician', body: {
        'name': name,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim()
      })));

  Future<RepairJob> reportMismatch(String id,
          {String? itemId,
          required String title,
          String? note,
          List<String> mediaIds = const []}) =>
      step(id, 'mismatch', body: {
        if (itemId != null) 'itemId': itemId,
        'title': title,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
      });

  Future<List<ChatMessage>> messages(String id) async {
    final d = _data(await _send('GET', '$_base/$id/messages'));
    return [
      for (final m in (d['messages'] as List? ?? const []))
        if (m is Map) ChatMessage.fromJson(m.cast<String, dynamic>())
    ];
  }

  Future<void> sendMessage(String id, String body) =>
      _send('POST', '$_base/$id/messages', body: {'body': body});

  /// The invoice PDF (bytes). Needs the document id from the finished job.
  Future<List<int>> invoicePdf(String invoiceId) async {
    try {
      final res = await _dio.get<List<int>>(
          '/manage/sales-invoices/$invoiceId/pdf',
          options: Options(responseType: ResponseType.bytes));
      return res.data ?? const [];
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<RepairJob> recordPayment(String id,
          {required String kind,
          required String method,
          required num amount,
          required String idempotencyKey,
          String? reference}) =>
      step(id, 'payments', body: {
        'kind': kind,
        'method': method,
        'amount': amount,
        'idempotencyKey': idempotencyKey,
        if (reference != null && reference.trim().isNotEmpty)
          'reference': reference.trim(),
      });

  /// One photo/video → an unattached upload id the next `update` claims.
  Future<String> uploadEvidence(String filePath) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/media',
        data:
            FormData.fromMap({'files': await MultipartFile.fromFile(filePath)}),
        options: Options(
            sendTimeout: const Duration(minutes: 5),
            receiveTimeout: const Duration(minutes: 5)),
      );
      final files = (_data(res.data ?? const {})['files'] as List?) ?? const [];
      final f = files.isEmpty ? null : files.first as Map?;
      if (f == null || f['ok'] != true) {
        throw ServerFailure(message: '${f?['message'] ?? 'Upload failed'}');
      }
      return '${(f['media'] as Map)['id']}';
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  // ── price list ───────────────────────────────────────────────────────

  Future<List<ServiceRow>> services() async {
    final b = await _send('GET', '$_base/market/services');
    return [
      for (final r in (b['data'] as List? ?? const []))
        if (r is Map) ServiceRow.fromJson(r.cast<String, dynamic>())
    ];
  }

  Future<void> saveServices({
    required String deviceCategory,
    required String brand,
    required String model,
    required List<Map<String, dynamic>> services,
    bool pickupDelivery = true,
  }) =>
      _send('POST', '$_base/market/services/bulk', body: {
        'deviceCategory': deviceCategory,
        'brand': brand,
        'model': model,
        'pickupDelivery': pickupDelivery,
        'services': services,
      });

  Future<void> deleteService(String id) =>
      _send('DELETE', '$_base/market/services/$id');

  Future<void> setActive(String id, bool active) =>
      _send('PUT', '$_base/market/services/$id', body: {'isActive': active});

  Future<({bool accepting, int activeServices})> profile() async {
    final d = _data(await _send('GET', '$_base/market/profile'));
    return (
      accepting: d['acceptingRequests'] != false,
      activeServices: (d['activeServices'] as num?)?.toInt() ?? 0
    );
  }

  Future<void> setAccepting(bool v) =>
      _send('PUT', '$_base/market/profile', body: {'acceptingRequests': v});

  // ── catalogue (shared with the customer app) ─────────────────────────

  Future<List<CatalogBrand>> brands() async {
    final b = await _send('GET', '/repairs/catalogue/brands');
    return [
      for (final r in (b['data'] as List? ?? const []))
        if (r is Map) CatalogBrand('${r['name']}', r['logoUrl'] as String?)
    ];
  }

  Future<List<CatalogModel>> models(String brand, {String? q}) async {
    final b = await _send('GET', '/repairs/catalogue/models',
        query: {'brand': brand, if (q != null && q.isNotEmpty) 'q': q});
    return [
      for (final r in (b['data'] as List? ?? const []))
        if (r is Map)
          CatalogModel(
              '${r['name']}', '${r['category']}', r['imageUrl'] as String?)
    ];
  }

  Future<List<RepairIssueOption>> issueOptions() async {
    final b = await _send('GET', '/repairs/config');
    final d = _data(b);
    return [
      for (final r in (d['issues'] as List? ?? const []))
        if (r is Map) RepairIssueOption('${r['key']}', '${r['label']}')
    ];
  }
}
