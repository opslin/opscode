import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/deals/data/deal_models.dart';

/// `/vendor/deals`: deals opened to vendors — browse, enter own products, withdraw.
class DealRepository {
  DealRepository(this._dio);
  final Dio _dio;

  Object? _data(Response<dynamic> r) => (r.data as Map?)?['data'];

  Future<List<OpenDeal>> list() async {
    try {
      final rows = (_data(await _dio.get<dynamic>('/vendor/deals')) as List? ?? const []);
      return rows
          .whereType<Map>()
          .map((m) => OpenDeal.fromJson(m.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<OpenDealDetail> detail(String id) async {
    try {
      final m = ((_data(await _dio.get<dynamic>('/vendor/deals/$id')) as Map?) ?? const {})
          .cast<String, dynamic>();
      final entries = (m['entries'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => DealEntry.fromJson(e.cast<String, dynamic>()))
          .toList();
      return OpenDealDetail(deal: OpenDeal.fromJson(m), entries: entries);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<List<DealListing>> listings(String id) async {
    try {
      final rows = (_data(await _dio.get<dynamic>('/vendor/deals/$id/listings')) as List? ?? const []);
      return rows
          .whereType<Map>()
          .map((m) => DealListing.fromJson(m.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  /// Returns the status the entries got (`PENDING` when the admin must approve).
  Future<String> apply(String id, List<String> listingIds) async {
    try {
      final m = ((_data(await _dio.post<dynamic>('/vendor/deals/$id/entries',
              data: {'listingIds': listingIds})) as Map?) ??
          const {});
      return '${m['status'] ?? 'PENDING'}';
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<void> withdraw(String id, String entryId) async {
    try {
      await _dio.delete<dynamic>('/vendor/deals/$id/entries/$entryId');
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }
}
