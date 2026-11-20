import 'dart:async';

import 'package:dio/dio.dart';

import 'package:dealker_app/features/exchange/data/exchange_models.dart';

/// `/exchange-requests` (customer API). Price math is the server's; the app only sends answers.
class ExchangeRepository {
  const ExchangeRepository(this._dio);
  final Dio _dio;

  Future<ExchangeSummary> summary() async {
    final Response<dynamic> r =
        await _dio.get<dynamic>('/exchange-requests/summary');
    final Map<String, dynamic> d = _data(r);
    return ExchangeSummary(
      enabled: d['enabled'] == true,
      maxValue: (d['maxValue'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<ExchangeModel>> catalog() async {
    final Response<dynamic> r = await _dio
        .get<dynamic>('/exchange-requests/catalog')
        .timeout(const Duration(seconds: 25));
    final Object? d = (r.data as Map)['data'];
    return (d as List? ?? <Object?>[])
        .whereType<Map>()
        .map((Map e) => ExchangeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Guest-safe: is exchange offered on this product, which old devices count and what they fetch.
  Future<ExchangeOffer> forProduct(String productId) async {
    final Response<dynamic> r =
        await _dio.get<dynamic>('/exchange-requests/for-product/$productId');
    return ExchangeOffer.fromJson(_data(r));
  }

  /// The exchange flow's data for one product: accepted types (with their questions) and models.
  Future<ExchangeOptions> options(String productId) async {
    final Response<dynamic> r = await _dio
        .get<dynamic>('/exchange-requests/options/$productId')
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> d = _data(r);
    return ExchangeOptions(
      maxValue: (d['maxValue'] as num?)?.toDouble() ?? 0,
      types: (d['types'] as List? ?? <Object?>[])
          .whereType<Map>()
          .map((Map e) => ExchangeType.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      models: (d['models'] as List? ?? <Object?>[])
          .whereType<Map>()
          .map((Map e) => ExchangeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<ExchangeQuote> quote({
    required String productId,
    required ExchangeModel model,
    required String variant,
    required String color,
    required ExchangeQa qa,
  }) async {
    final Response<dynamic> r = await _dio.post<dynamic>(
      '/exchange-requests/quote',
      data: <String, dynamic>{
        'productId': productId,
        'modelId': model.id,
        'variant': variant,
        'color': color,
        'qa': qa.toJson(),
      },
    );
    return ExchangeQuote.fromJson(_data(r));
  }

  /// Returns the new request code (e.g. EXCH-200001).
  Future<String> submit({
    required ExchangeModel model,
    required String variant,
    required String color,
    required String? imei,
    required ExchangeQa qa,
    required ExchangeTarget target,
  }) async {
    final Response<dynamic> r = await _dio.post<dynamic>(
      '/exchange-requests',
      data: <String, dynamic>{
        'type': 'EXCHANGE',
        'modelId': model.id,
        'variant': variant,
        'color': color,
        if (imei != null && imei.isNotEmpty) 'imei': imei,
        'qa': qa.toJson(),
        'exchange': <String, dynamic>{
          'newProduct': target.name,
          'newProductPrice': target.price,
          'productId': target.productId,
        },
      },
    );
    return '${_data(r)['code'] ?? ''}';
  }

  Map<String, dynamic> _data(Response<dynamic> r) =>
      Map<String, dynamic>.from((r.data as Map)['data'] as Map);

  /// The server's own message for a failed call (e.g. "IMEI must be 15 digits…").
  static String errorMessage(Object e) {
    if (e is DioException) {
      final Object? d = e.response?.data;
      if (d is Map && d['message'] is String) return d['message'] as String;
    }
    if (e is TimeoutException)
      return 'The server is taking too long. Please try again.';
    return 'Something went wrong. Please try again.';
  }
}
