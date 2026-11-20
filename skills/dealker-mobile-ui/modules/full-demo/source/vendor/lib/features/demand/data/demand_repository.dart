import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dealker_vendor/features/repair_book/shims/picked_file_upload.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';

/// Everything the Demand flow sends or reads. The JWT carries the vendor, so a vendor only
/// ever sees demand meant for them and orders they are part of (`/vendor/b2b/*`).
class DemandRepository {
  DemandRepository(this._dio);
  final Dio _dio;

  static const _base = '/vendor/b2b';

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(
        '$_base$path',
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      return res.data ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Map<String, dynamic> _map(dynamic v) =>
      (v as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> _rows(dynamic v) =>
      ((v as List?) ?? const []).whereType<Map<String, dynamic>>().toList();

  // ── demand (what buyers want) ───────────────────────────────────────

  Future<DemandSummary> summary() async => DemandSummary.fromJson(
      _map((await _send('GET', '/demand/summary'))['data']));

  /// [scope]: open · new · matched · mine · quoted (+ [tab] active | pending | closed).
  Future<RequirementPage> requirements({
    String scope = 'open',
    String? tab,
    String search = '',
    int page = 1,
    int limit = 30,
  }) async {
    final b = await _send('GET', '/requirements', query: {
      'scope': scope,
      'page': page,
      'limit': limit,
      if (tab != null) 'tab': tab,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return RequirementPage(
      items: _rows(b['data']).map(Requirement.fromJson).toList(),
      total: ((_map(b['pagination'])['total']) as num?)?.toInt() ?? 0,
    );
  }

  /// Opening a requirement also marks it "seen" for this vendor.
  Future<RequirementDetail> detail(String id) async =>
      RequirementDetail.fromJson(
          _map((await _send('GET', '/requirements/$id'))['data']));

  Future<MatchResult> match(String id) async => MatchResult.fromJson(
      _map((await _send('GET', '/requirements/$id/match'))['data']));

  Future<void> dismiss(String id) => _send('POST', '/requirements/$id/dismiss');

  // ── buying (posting demand) ─────────────────────────────────────────

  Future<Requirement> create(Map<String, dynamic> body) async =>
      Requirement.fromJson(
          _map((await _send('POST', '/requirements', body: body))['data']));

  Future<void> cancelRequirement(String id, {String? reason}) =>
      _send('POST', '/requirements/$id/cancel',
          body: {if (reason != null && reason.isNotEmpty) 'reason': reason});

  Future<List<DemandOrder>> award(String id, List<Selection> picks) async {
    final b = await _send('POST', '/requirements/$id/award',
        body: {'selections': picks.map((s) => s.toJson()).toList()});
    return _rows(b['data']).map(DemandOrder.fromJson).toList();
  }

  Future<WalletInfo> wallet() async =>
      WalletInfo.fromJson(_map((await _send('GET', '/wallet'))['data']));

  /// Pays every unpaid order of the requirement from the Dealkr wallet; the money is held
  /// in escrow until the buyer confirms receipt.
  Future<void> pay(String requirementId) =>
      _send('POST', '/requirements/$requirementId/pay',
          body: {'method': 'WALLET'});

  // ── Razorpay Checkout (one payment for one or many orders) ─────────

  /// Starts (or resumes) a Checkout for the unpaid orders of these requirements.
  Future<GatewayOrder> razorpayOrder(List<String> requirementIds) async =>
      GatewayOrder.fromJson(_map((await _send('POST', '/pay/razorpay/order',
          body: {'requirementIds': requirementIds}))['data']));

  /// Success callback of Checkout: the server checks Razorpay's signature and the payment itself, then holds the money.
  Future<void> razorpayVerify(
          {required String orderId,
          required String paymentId,
          required String signature}) =>
      _send('POST', '/pay/razorpay/verify', body: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      });

  /// Asks the server to look the payment up at Razorpay (when the app never got the callback).
  Future<void> razorpaySync(String orderId) =>
      _send('POST', '/pay/razorpay/sync', body: {'razorpayOrderId': orderId});

  // ── selling (answering demand) ──────────────────────────────────────

  Future<void> sendOffer(String requirementId, Map<String, dynamic> body) =>
      _send('POST', '/requirements/$requirementId/quote', body: body);

  Future<void> withdrawOffer(String quoteId) =>
      _send('POST', '/quotes/$quoteId/withdraw');

  // ── orders ──────────────────────────────────────────────────────────

  /// [role]: buying | selling · [bucket]: active | done.
  Future<OrderPage> orders(
      {String role = 'buying', String? bucket, int limit = 40}) async {
    final b = await _send('GET', '/orders', query: {
      'role': role,
      'limit': limit,
      if (bucket != null) 'bucket': bucket,
    });
    return OrderPage(
      items: _rows(b['data']).map(DemandOrder.fromJson).toList(),
      total: ((_map(b['pagination'])['total']) as num?)?.toInt() ?? 0,
    );
  }

  Future<OrderDetail> orderDetail(String id) async =>
      OrderDetail.fromJson(_map((await _send('GET', '/orders/$id'))['data']));

  /// Seller moves the order along: PACKED · DISPATCHED (courier or pickup) · DELIVERED.
  Future<void> setOrderStatus(String id, Map<String, dynamic> body) =>
      _send('POST', '/orders/$id/status', body: body);

  /// Seller ticks a device of a paid order as packed (or un-ticks it).
  Future<void> packDevice(String orderId, int unitNo, bool packed) =>
      _send('POST', '/orders/$orderId/devices/$unitNo/pack', body: {'packed': packed});

  /// Seller's own invoice (photo) for the order — packing and dispatch are blocked without it.
  Future<void> uploadOrderInvoice(String id, XFile file, {String? number}) async {
    final form = FormData.fromMap({
      if (number != null && number.trim().isNotEmpty) 'invoiceNumber': number.trim(),
      'file': await pickedFileMultipart(file),
    });
    await _send('POST', '/orders/$id/invoice', body: form);
  }

  /// Seller cannot deliver a paid order — the buyer is refunded in full.
  Future<void> cancelOrder(String id, String reason) =>
      _send('POST', '/orders/$id/cancel', body: {'reason': reason});

  /// Buyer confirms what arrived. Everything fine → payment is released to the seller;
  /// anything short or wrong → dispute for Dealkr to resolve.
  Future<void> receive(String id,
          {required int quantity, required bool ok, String? note}) =>
      _send('POST', '/orders/$id/receive', body: {
        'receivedQuantity': quantity,
        'ok': ok,
        if (note != null && note.isNotEmpty) 'note': note,
      });
}
