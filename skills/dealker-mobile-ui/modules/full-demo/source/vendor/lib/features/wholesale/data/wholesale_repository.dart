import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/wholesale/data/wholesale_models.dart';

/// Other vendors' wholesale stock (`/vendor/b2b/wholesale`). The JWT carries the
/// buyer; the server never returns the caller's own listings.
class WholesaleRepository {
  WholesaleRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? query, Object? body}) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>('/vendor/b2b$path',
          data: body, queryParameters: query, options: Options(method: method));
      return res.data ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<WholesalePage> list({
    String search = '',
    String sort = 'newest',
    String? brand,
    String? condition,
    String? category,
    bool deals = false,
    int limit = 40,
  }) async {
    final b = await _send('GET', '/wholesale', query: {
      'limit': limit,
      'sort': sort,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (condition != null && condition.isNotEmpty) 'condition': condition,
      if (category != null && category.isNotEmpty) 'category': category,
      if (deals) 'deals': 1,
    });
    final facets = (b['facets'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<FacetOption> opts(dynamic v) => ((v as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FacetOption.fromJson)
        .toList();
    final rows =
        ((b['data'] as List?) ?? const []).whereType<Map<String, dynamic>>();
    final total =
        (((b['pagination'] as Map?)?['total']) as num?)?.toInt() ?? rows.length;
    return WholesalePage(
      items: rows.map(WholesaleItem.fromJson).toList(),
      total: total,
      brands: opts(facets['brands']),
      conditions: opts(facets['conditions']),
    );
  }

  /// Category tree: only branches that hold stock this vendor could buy.
  Future<List<WholesaleCategory>> categories() async {
    final b = await _send('GET', '/wholesale/categories');
    return ((b['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WholesaleCategory.fromJson)
        .toList();
  }

  Future<WholesaleDetail> detail(String id) async => WholesaleDetail.fromJson(
      ((await _send('GET', '/wholesale/$id'))['data'] as Map)
          .cast<String, dynamic>());

  /// Creates the order (awaiting payment). Pay it from the Dealkr wallet afterwards.
  Future<WholesaleOrder> buy(String id, int quantity, {List<int>? unitNos}) async =>
      WholesaleOrder.fromJson(((await _send('POST', '/wholesale/$id/order',
              body: {'quantity': quantity, if (unitNos != null && unitNos.length == quantity) 'unitNos': unitNos}))['data'] as Map)
          .cast<String, dynamic>());
}
