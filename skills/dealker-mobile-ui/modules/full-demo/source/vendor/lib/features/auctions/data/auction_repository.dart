import 'package:dealker_vendor/shared/widgets/chat_ui.dart' show ChatEntry;
import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';

/// All auction calls. Seller side lives under /manage/auctions (the JWT carries
/// the vendor, so a vendor only ever sees and touches their own auctions);
/// bidder side uses /auctions, which the server scopes so a vendor only sees
/// business (B2B) lots — customer (B2C) auctions never appear here.
class AuctionRepository {
  AuctionRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(
        path,
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
  int _total(Map<String, dynamic> b) =>
      ((b['pagination'] as Map?)?['total'] as num?)?.toInt() ?? 0;

  // ── create flow ─────────────────────────────────────────────────────

  Future<AuctionRules> rules() async => AuctionRules.fromJson(
      _map((await _send('GET', '/manage/auctions/rules'))['data']));

  /// The vendor's own in-stock products that are not already in an auction.
  Future<List<ProductOption>> products({String q = ''}) async {
    final b = await _send('GET', '/manage/auctions/products',
        query: {if (q.isNotEmpty) 'q': q});
    return _rows(b['data']).map(ProductOption.fromJson).toList();
  }

  Future<String> uploadImage(String filePath) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/image',
        queryParameters: {'kind': 'listing'},
        data:
            FormData.fromMap({'file': await MultipartFile.fromFile(filePath)}),
      );
      final url = _map(_map(res.data)['data'])['url'] as String?;
      if (url == null || url.isEmpty) {
        throw const FormatException('Upload returned no URL');
      }
      return url;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  /// Quality-evidence video (MP4 / MOV / WebM) — same endpoint the product flow uses.
  Future<String> uploadVideo(String filePath) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/video',
        data:
            FormData.fromMap({'file': await MultipartFile.fromFile(filePath)}),
        options: Options(
            sendTimeout: const Duration(minutes: 5),
            receiveTimeout: const Duration(minutes: 5)),
      );
      final url = _map(_map(res.data)['data'])['url'] as String?;
      if (url == null || url.isEmpty) {
        throw const FormatException('Upload returned no URL');
      }
      return url;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<AuctionItem> create(CreateAuctionRequest req) async {
    final b = await _send('POST', '/manage/auctions', body: req.toJson());
    return AuctionItem.fromJson(_map(b['data']));
  }

  // ── manage ──────────────────────────────────────────────────────────

  Future<AuctionList> list({List<String>? statuses, int limit = 30}) async {
    final b = await _send('GET', '/manage/auctions', query: {
      'limit': limit,
      if (statuses != null && statuses.isNotEmpty) 'status': statuses.join(','),
    });
    return AuctionList(
      items: _rows(b['data']).map(AuctionItem.fromJson).toList(),
      total: _total(b),
      counts: _map(b['counts']).map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  Future<AuctionDetail> detail(String id) async => AuctionDetail.fromJson(
      _map((await _send('GET', '/manage/auctions/$id'))['data']));

  Future<void> cancel(String id, {String? reason}) =>
      _send('POST', '/manage/auctions/$id/cancel',
          body: {if (reason != null) 'reason': reason});

  /// Chat with the winning buyer (opens once the auction has a winner).
  Future<List<ChatEntry>> chat(String id) async {
    final d = _map((await _send('GET', '/manage/auctions/$id/chat'))['data']);
    return [
      for (final m in (d['messages'] as List? ?? const []))
        if (m is Map)
          ChatEntry(
              id: int.tryParse('${m['id']}') ?? 0,
              mine: m['mine'] == true,
              body: '${m['body']}',
              at: DateTime.tryParse('${m['at']}')?.toLocal())
    ];
  }

  Future<void> sendChat(String id, String body) =>
      _send('POST', '/manage/auctions/$id/chat', body: {'body': body});

  Future<int> chatUnread(String id) async => ((_map(
              (await _send('GET', '/manage/auctions/$id/chat/unread'))['data'])['unread']
          as num?) ??
      0)
      .toInt();

  /// Seller closes their own live auction now and sells to the current top bidder.
  Future<void> endNow(String id, {bool waiveReserve = false}) =>
      _send('POST', '/manage/auctions/$id/end-now',
          body: {if (waiveReserve) 'waiveReserve': true});

  /// The seller order created when the winner paid, or null while the buyer has not paid yet.
  Future<SaleOrder?> saleOrder(String orderId) async {
    final list = await _send('GET', '/seller-orders',
        query: {'orderId': orderId, 'limit': 1});
    final rows = _rows(list['data']);
    if (rows.isEmpty) return null;
    final d = await _send('GET', '/seller-orders/${rows.first['id']}');
    return SaleOrder.fromJson(_map(d['data']));
  }

  Future<void> setSaleStatus(String sellerOrderId, String status) =>
      _send('POST', '/seller-orders/$sellerOrderId/status',
          body: {'status': status});

  Future<void> shipSale(String sellerOrderId,
          {required String courier, String? awb}) =>
      _send('POST', '/seller-orders/$sellerOrderId/ship', body: {
        'courierName': courier,
        if (awb != null && awb.trim().isNotEmpty) 'awb': awb.trim(),
      });

  Future<AuctionItem> submit(String id) async => AuctionItem.fromJson(
      _map((await _send('POST', '/manage/auctions/$id/submit'))['data']));

  /// Re-creates a finished, unsold auction as a draft.
  Future<AuctionItem> relist(String id) async => AuctionItem.fromJson(_map(
      (await _send('POST', '/manage/auctions/$id/relist', body: {}))['data']));

  // ── bidding on other vendors' B2B lots ──────────────────────────────

  /// B2B lots a vendor can bid on, filtered like the customer Auctions page.
  Future<LotList> lots(
      {LotQuery query = const LotQuery(), int limit = 30}) async {
    final b = await _send('GET', '/auctions', query: {
      'tab': query.tab,
      'limit': limit,
      'sort': query.sort,
      if (query.q.isNotEmpty) 'q': query.q,
      if (query.categoryId != null) 'categoryId': query.categoryId,
      if (query.brand != null) 'brand': query.brand,
      if (query.min != null) 'min': query.min,
      if (query.max != null) 'max': query.max,
    });
    final offset = DateTime.tryParse('${b['server_time']}')
        ?.toLocal()
        .difference(DateTime.now());
    final facets = _map(b['facets']);
    return LotList(
      items: _rows(b['data'])
          .map((j) => LotView.fromJson(j, offset: offset))
          .toList(),
      total: _total(b),
      counts: _map(b['counts'])
          .map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      brands: [
        for (final x in _rows(facets['brands']))
          (name: '${x['name']}', count: (x['count'] as num?)?.toInt() ?? 0)
      ],
      categories: [
        for (final x in _rows(facets['categories']))
          (
            id: '${x['id']}',
            name: '${x['name']}',
            count: (x['count'] as num?)?.toInt() ?? 0
          )
      ],
    );
  }

  /// Lots this vendor registered for or won, any state.
  Future<LotList> myLots() async {
    final b = await _send('GET', '/auctions/mine',
        query: {'tab': 'all', 'limit': 50});
    final offset = DateTime.tryParse('${b['server_time']}')
        ?.toLocal()
        .difference(DateTime.now());
    final items = _rows(b['data'])
        .map((j) => LotView.fromJson(j, offset: offset))
        .toList();
    return LotList(items: items, total: items.length);
  }

  /// Pays for a won lot from the wallet. A business winner needs no address: the server
  /// delivers to the business address on the vendor profile.
  Future<String> checkoutLot(String id) async {
    final b = await _send('POST', '/auctions/$id/checkout',
        body: {'paymentMethod': 'WALLET'});
    return '${_map(b['data'])['order_number'] ?? ''}';
  }

  /// Starts the "pay online" route for a won lot: creates the (unpaid) order. The app then opens
  /// Razorpay for [orderId]; the server marks the lot sold once the payment is confirmed.
  Future<({String orderId, String orderNumber})> checkoutLotOnline(String id) async {
    final d = _map((await _send('POST', '/auctions/$id/checkout',
        body: {'paymentMethod': 'ONLINE'}))['data']);
    return (
      orderId: '${d['order_id'] ?? ''}',
      orderNumber: '${d['order_number'] ?? ''}',
    );
  }

  /// Razorpay order for an existing unpaid order of this vendor (same endpoint the customer app uses).
  Future<OrderGateway> gatewayOrder(String orderId) async {
    final d = _map((await _send('POST', '/payments/create-order',
        body: {'orderId': orderId}))['data']);
    final amount = d['amount'];
    return OrderGateway(
      keyId: '${d['keyId'] ?? ''}',
      razorpayOrderId: '${d['razorpayOrderId'] ?? ''}',
      amountPaise:
          ((amount is num ? amount : num.tryParse('$amount') ?? 0) * 100).round(),
    );
  }

  Future<void> verifyGateway(
          {required String orderId,
          required String paymentId,
          required String signature}) =>
      _send('POST', '/payments/verify', body: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      });

  Future<void> watchLot(String id, {required bool on}) =>
      _send(on ? 'POST' : 'DELETE', '/auctions/$id/watch');

  Future<LotView> lot(String id) async =>
      LotView.fromJson(_map((await _send('GET', '/auctions/$id'))['data']));

  Future<List<BidEntry>> lotBids(String id) async {
    final b = await _send('GET', '/auctions/$id/bids', query: {'limit': 50});
    return _rows(b['data']).map(BidEntry.fromJson).toList();
  }

  Future<String> consentText() async {
    final b = await _send('GET', '/auctions/info');
    return '${_map(b['data'])['consent_text'] ?? ''}';
  }

  Future<void> register(String id) =>
      _send('POST', '/auctions/$id/register', body: {'consent': true});

  Future<void> placeBid(String id, num maxAmount) =>
      _send('POST', '/auctions/$id/bids', body: {'maxAmount': maxAmount});
}

class OrderGateway {
  const OrderGateway(
      {required this.keyId, required this.razorpayOrderId, required this.amountPaise});
  final String keyId;
  final String razorpayOrderId;
  final int amountPaise;
}
