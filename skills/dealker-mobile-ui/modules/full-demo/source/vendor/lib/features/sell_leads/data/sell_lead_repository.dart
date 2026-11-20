import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/sell_leads/data/sell_lead_models.dart';

/// `/manage/sell-requests` as a vendor: browse customers' phones, make an offer, talk to the seller.
class SellLeadRepository {
  SellLeadRepository(this._dio);
  final Dio _dio;

  Map<String, dynamic> _data(Response<dynamic> r) =>
      ((r.data as Map?)?['data'] as Map?)?.cast<String, dynamic>() ?? const {};

  /// [tab] is the server's tab: `pending` (open to offers) or `progress` (a seller accepted an offer).
  Future<SellLeadPage> list({String tab = 'pending', int limit = 40}) async {
    try {
      final d = _data(await _dio.get<dynamic>('/manage/sell-requests',
          queryParameters: {'status': tab, 'limit': limit}));
      final rows = (d['items'] as List? ?? const []).whereType<Map>();
      return SellLeadPage(
        items: rows
            .map((m) => SellLead.fromJson(m.cast<String, dynamic>()))
            .toList(),
        total: (d['total'] as num?)?.toInt() ?? rows.length,
      );
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<SellLead> get(String id) async {
    try {
      return SellLead.fromJson(
          _data(await _dio.get<dynamic>('/manage/sell-requests/$id')));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<SellLead> placeOffer(String id, num amount, String note) async {
    try {
      return SellLead.fromJson(_data(await _dio
          .post<dynamic>('/manage/sell-requests/$id/offers', data: {
        'amount': amount,
        if (note.trim().isNotEmpty) 'note': note.trim()
      })));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<SellLead> withdrawOffer(String id) async {
    try {
      return SellLead.fromJson(_data(
          await _dio.delete<dynamic>('/manage/sell-requests/$id/offers')));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<LeadThread> thread(String id) async {
    try {
      return LeadThread.fromJson(
          _data(await _dio.get<dynamic>('/manage/sell-requests/$id/messages')));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<LeadThread> send(String id, String body) async {
    try {
      return LeadThread.fromJson(_data(await _dio.post<dynamic>(
          '/manage/sell-requests/$id/messages',
          data: {'body': body})));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  // ── after the seller accepts: pay, collect, inspect ────────────────────

  Future<SellLead> _post(String id, String path,
      [Map<String, dynamic>? body]) async {
    try {
      await _dio.post<dynamic>('/manage/sell-requests/$id/$path',
          data: body ?? const {});
      return await get(id);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<RazorpayOrder> razorpayOrder(String id) async {
    try {
      return RazorpayOrder.fromJson(_data(await _dio.post<dynamic>(
          '/manage/sell-requests/$id/vendor-payment/razorpay/order',
          data: const {})));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<SellLead> razorpayVerify(String id,
          {required String orderId,
          required String paymentId,
          required String signature}) =>
      _post(id, 'vendor-payment/razorpay/verify', {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      });

  /// Safety net when Checkout closed without a callback: asks the server to look the payment up.
  Future<SellLead> razorpaySync(String id) =>
      _post(id, 'vendor-payment/razorpay/sync');

  Future<SellLead> arrangePickup(String id,
          {required String provider,
          String? awb,
          String? courierName,
          String? trackingUrl,
          String? note}) =>
      _post(id, 'pickup', {
        'provider': provider,
        if ((awb ?? '').trim().isNotEmpty) 'awb': awb!.trim(),
        if ((courierName ?? '').trim().isNotEmpty)
          'courierName': courierName!.trim(),
        if ((trackingUrl ?? '').trim().isNotEmpty)
          'trackingUrl': trackingUrl!.trim(),
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      });

  Future<SellLead> pickupStatus(String id, String status, {String? note}) =>
      _post(id, 'pickup/status',
          {'status': status, if ((note ?? '').isNotEmpty) 'note': note});

  Future<SellLead> markReceived(String id) => _post(id, 'received');
  Future<SellLead> simulatePickup(String id) => _post(id, 'pickup/simulate');
  Future<SellLead> storeClosed(String id, {String? note}) => _post(
      id, 'pickup/store-closed', {if ((note ?? '').isNotEmpty) 'note': note});
  Future<SellLead> markReturned(String id) => _post(id, 'returned');

  /// Uploads one inspection photo and returns its media id.
  Future<String> uploadEvidence(String path) async {
    try {
      final res = await _dio.post<dynamic>('/manage/sell-requests/media',
          data:
              FormData.fromMap({'files': await MultipartFile.fromFile(path)}));
      final files = (_data(res)['files'] as List? ?? const []).whereType<Map>();
      final first = files.isEmpty ? null : files.first.cast<String, dynamic>();
      if (first == null || first['ok'] == false) {
        throw StateError((first?['message'] as String?) ?? 'Upload failed');
      }
      return '${(first['media'] as Map)['id']}';
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<SellLead> attachEvidence(String id, List<String> mediaIds) =>
      _post(id, 'media', {'mediaIds': mediaIds, 'stage': 'TECHNICIAN_QC'});

  Future<SellLead> startInspection(String id) => _post(id, 'qc/start');

  Future<SellLead> submitInspection(String id, Map<String, dynamic> findings) =>
      _post(id, 'qc/inspection', findings);

  Future<SellLead> decideInspection(String id,
          {required String result, String? note, num? finalValuation}) =>
      _post(id, 'qc/decision', {
        'result': result,
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        if (finalValuation != null) 'finalValuation': finalValuation,
      });
}
