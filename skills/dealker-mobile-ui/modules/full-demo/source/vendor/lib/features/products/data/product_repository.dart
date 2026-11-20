import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';

/// Vendor product calls. Everything is scoped to the signed-in vendor by the
/// JWT (`/vendor/listings`), so a vendor only ever sees and edits their own.
class ProductRepository {
  ProductRepository(this._dio);
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

  Future<List<CategoryOption>> categories() async {
    final b = await _send('GET', '/categories');
    return _rows(b['data'])
        .where((c) => c['is_active'] != false)
        .map((c) => CategoryOption(
              '${c['id']}',
              '${c['name']}',
              slug: '${c['slug'] ?? ''}',
              imageUrl: _nonEmpty(c['image_url']),
              parentId: _nonEmpty(c['parent_id']),
            ))
        .toList();
  }

  String? _nonEmpty(dynamic v) {
    final s = v == null ? '' : '$v'.trim();
    return s.isEmpty ? null : s;
  }

  Future<ListingStats> stats() async => ListingStats.fromJson(
      _map((await _send('GET', '/vendor/listings/stats'))['data']));

  /// [approval]: PENDING | APPROVED | REJECTED (null = all).
  Future<ListingPage> list({
    String? approval,
    String search = '',
    int limit = 50,
  }) async {
    final b = await _send('GET', '/vendor/listings', query: {
      'limit': limit,
      if (approval != null) 'approval': approval,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return ListingPage(
      items: _rows(b['data']).map(ListingCard.fromJson).toList(),
      total: ((_map(b['pagination'])['total']) as num?)?.toInt() ?? 0,
    );
  }

  Future<ListingDetail> detail(String id) async => ListingDetail.fromJson(
      _map((await _send('GET', '/vendor/listings/$id'))['data']));

  Future<ListingDetail> create(Map<String, dynamic> body) async =>
      ListingDetail.fromJson(
          _map((await _send('POST', '/vendor/listings', body: body))['data']));

  Future<ListingDetail> update(String id, Map<String, dynamic> body) async =>
      ListingDetail.fromJson(_map(
          (await _send('PATCH', '/vendor/listings/$id', body: body))['data']));

  /// [status]: ACTIVE | PAUSED
  Future<ListingDetail> setStatus(String id, String status) async =>
      ListingDetail.fromJson(_map((await _send(
          'PATCH', '/vendor/listings/$id/status',
          body: {'listingStatus': status}))['data']));

  Future<void> remove(String id) => _send('DELETE', '/vendor/listings/$id');

  Future<String> uploadImage(String filePath) =>
      _upload('/uploads/image', filePath, query: {'kind': 'listing'});

  /// Quality-evidence video (MP4 / MOV / WebM, up to 100 MB).
  Future<String> uploadVideo(String filePath) =>
      _upload('/uploads/video', filePath);

  Future<String> _upload(String path, String filePath,
      {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        path,
        queryParameters: query,
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
}
