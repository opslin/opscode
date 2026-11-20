import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/home/data/home_models.dart';

/// Read-only calls behind the Partner Hub home. Every endpoint is vendor-scoped
/// server-side (the JWT carries the vendor), nothing is filtered client-side.
class HomeRepository {
  HomeRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, dynamic>? q]) async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>(path, queryParameters: q);
      return res.data ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  List<Map<String, dynamic>> _rows(dynamic v) =>
      ((v as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
  int _total(Map<String, dynamic> body) =>
      ((body['pagination'] as Map?)?['total'] as num?)?.toInt() ?? 0;

  Future<PagedTotal<SellerOrderRow>> sellerOrders(
      {String? status, int limit = 1}) async {
    final b = await _get('/seller-orders',
        {'limit': limit, if (status != null) 'status': status});
    return PagedTotal(
        items: _rows(b['data']).map(SellerOrderRow.fromJson).toList(),
        total: _total(b));
  }

  /// scope: open (requirements I can quote on) | quoted (ones I already quoted).
  Future<PagedTotal<B2bRequirementRow>> b2bRequirements(
      {required String scope, int limit = 1}) async {
    final b = await _get(
        '/vendor/b2b/requirements', {'scope': scope, 'limit': limit});
    return PagedTotal(
        items: _rows(b['data']).map(B2bRequirementRow.fromJson).toList(),
        total: _total(b));
  }

  Future<PagedTotal<SellRequestRow>> pendingSellRequests(
      {int limit = 3}) async {
    final b = await _get(
        '/manage/sell-requests', {'status': 'pending', 'limit': limit});
    final d = (b['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PagedTotal(
      items: _rows(d['items']).map(SellRequestRow.fromJson).toList(),
      total: (d['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<WalletSummary> walletSummary() async {
    final b = await _get('/settlements/summary');
    return WalletSummary.fromJson(
        (b['data'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  Future<AuctionStats> auctionStats() async {
    final b = await _get('/manage/auctions/stats');
    return AuctionStats.fromJson(
        (b['data'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  Future<List<AuctionRow>> liveAuctions({int limit = 2}) async {
    final b =
        await _get('/manage/auctions', {'status': 'LIVE', 'limit': limit});
    return _rows(b['data']).map(AuctionRow.fromJson).toList();
  }

  Future<List<CampaignRow>> activeCampaigns({int limit = 2}) async {
    final b = await _get('/manage/ads', {'status': 'ACTIVE', 'limit': limit});
    return _rows(b['data']).map(CampaignRow.fromJson).toList();
  }
}
