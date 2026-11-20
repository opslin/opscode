import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';

/// Everything the Campaigns module sends or reads. Campaigns are the platform's
/// sponsored-product ads (`/manage/ads`): the JWT carries the vendor, so a
/// vendor only ever sees and changes their own campaigns and ad wallet.
class CampaignRepository {
  CampaignRepository(this._dio);
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

  // ── create flow ─────────────────────────────────────────────────────

  Future<AdRules> rules() async =>
      AdRules.fromJson(_map((await _send('GET', '/manage/ads/rules'))['data']));

  /// The vendor's own live, approved products.
  Future<List<AdProduct>> products({String q = ''}) async {
    final b = await _send('GET', '/manage/ads/products',
        query: {if (q.isNotEmpty) 'q': q});
    return _rows(b['data']).map(AdProduct.fromJson).toList();
  }

  Future<BidEstimate> estimate(String keyword,
          {String matchType = 'BROAD'}) async =>
      BidEstimate.fromJson(_map((await _send('GET', '/manage/ads/estimate',
          query: {'keyword': keyword, 'matchType': matchType}))['data']));

  /// Creates the campaign and, when [submit] is true, sends it for review in the
  /// same call. The server returns the full campaign.
  Future<CampaignDetail> create(Map<String, dynamic> body) async =>
      CampaignDetail.fromJson(
          _map((await _send('POST', '/manage/ads', body: body))['data']));

  // ── manage ──────────────────────────────────────────────────────────

  Future<CampaignList> list({List<String>? statuses, int limit = 50}) async {
    final b = await _send('GET', '/manage/ads', query: {
      'limit': limit,
      if (statuses != null && statuses.isNotEmpty) 'status': statuses.join(','),
    });
    return CampaignList(
      items: _rows(b['data']).map(CampaignItem.fromJson).toList(),
      total: ((_map(b['pagination'])['total']) as num?)?.toInt() ?? 0,
      counts: _map(b['counts'])
          .map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
    );
  }

  Future<CampaignDetail> detail(String id) async => CampaignDetail.fromJson(
      _map((await _send('GET', '/manage/ads/$id'))['data']));

  Future<CampaignReport> report(String id, {int days = 30}) async =>
      CampaignReport.fromJson(_map((await _send('GET', '/manage/ads/$id/report',
          query: {'days': days}))['data']));

  Future<AdsOverview> overview({int days = 30}) async =>
      AdsOverview.fromJson(_map((await _send('GET', '/manage/ads/overview',
          query: {'days': days}))['data']));

  /// Name, bid, budgets and dates. Targeting cannot be changed after creation.
  Future<CampaignDetail> update(String id, Map<String, dynamic> body) async =>
      CampaignDetail.fromJson(
          _map((await _send('PUT', '/manage/ads/$id', body: body))['data']));

  Future<CampaignDetail> _action(String id, String name) async =>
      CampaignDetail.fromJson(
          _map((await _send('POST', '/manage/ads/$id/$name'))['data']));

  Future<CampaignDetail> submit(String id) => _action(id, 'submit');
  Future<CampaignDetail> pause(String id) => _action(id, 'pause');
  Future<CampaignDetail> resume(String id) => _action(id, 'resume');
  Future<CampaignDetail> end(String id) => _action(id, 'end');

  Future<CampaignDetail> addProducts(
          String id, List<String> productIds) async =>
      CampaignDetail.fromJson(_map((await _send(
          'POST', '/manage/ads/$id/products',
          body: {'productIds': productIds}))['data']));

  Future<CampaignDetail> setProductPaused(
          String id, String productId, bool paused) async =>
      CampaignDetail.fromJson(_map((await _send(
          'PATCH', '/manage/ads/$id/products/$productId',
          body: {'status': paused ? 'PAUSED' : 'ACTIVE'}))['data']));

  Future<CampaignDetail> removeProduct(String id, String productId) async =>
      CampaignDetail.fromJson(_map((await _send(
          'DELETE', '/manage/ads/$id/products/$productId'))['data']));

  Future<CampaignDetail> addKeywords(
          String id, List<KeywordDraft> keywords) async =>
      CampaignDetail.fromJson(_map((await _send(
          'POST', '/manage/ads/$id/keywords', body: {
        'keywords': keywords.map((k) => k.toJson()).toList()
      }))['data']));

  Future<CampaignDetail> removeKeyword(String id, String keywordId) async =>
      CampaignDetail.fromJson(_map((await _send(
          'DELETE', '/manage/ads/$id/keywords/$keywordId'))['data']));

  // ── ad wallet ───────────────────────────────────────────────────────

  Future<AdWallet> wallet() async => AdWallet.fromJson(
      _map((await _send('GET', '/manage/ads/wallet'))['data']));

  Future<WalletStatement> statement({int limit = 40}) async {
    final b = await _send('GET', '/manage/ads/wallet/statement',
        query: {'limit': limit});
    return WalletStatement(
      items: _rows(b['data']).map(WalletEntry.fromJson).toList(),
      total: ((_map(b['pagination'])['total']) as num?)?.toInt() ?? 0,
    );
  }

  /// Moves money from the vendor's settlement balance into the ad wallet. The
  /// idempotency key makes a retried tap safe.
  Future<void> topUp(num amount, {required String idempotencyKey}) =>
      _send('POST', '/manage/ads/wallet/topup',
          body: {'amount': amount, 'idempotencyKey': idempotencyKey});

  Future<void> withdraw(num amount) =>
      _send('POST', '/manage/ads/wallet/withdraw', body: {'amount': amount});
}
