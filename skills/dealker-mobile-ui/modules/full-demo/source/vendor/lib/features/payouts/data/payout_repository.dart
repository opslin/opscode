import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/payouts/data/payout_models.dart';

/// The vendor's own payouts (`GET /settlements/payouts`); the JWT decides whose.
class PayoutRepository {
  PayoutRepository(this._dio);
  final Dio _dio;

  Future<PayoutPage> list({String status = '', int limit = 50}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/settlements/payouts',
          queryParameters: {
            'limit': limit,
            if (status.isNotEmpty) 'status': status
          });
      final b = res.data ?? const {};
      final rows =
          ((b['data'] as List?) ?? const []).whereType<Map<String, dynamic>>();
      return PayoutPage(
        items: rows.map(Payout.fromJson).toList(),
        summary: PayoutSummary.fromJson(
            (b['summary'] as Map?)?.cast<String, dynamic>() ?? const {}),
        total: (((b['pagination'] as Map?)?['total']) as num?)?.toInt() ??
            rows.length,
      );
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }
}
