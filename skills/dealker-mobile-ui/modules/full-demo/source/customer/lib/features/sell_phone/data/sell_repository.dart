import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dealker_app/core/network/picked_file_upload.dart';

import 'package:dealker_app/features/exchange/data/exchange_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_models.dart';

/// `/sell-requests` (customer API). The server owns every price, offer and status; this only sends answers.
class SellRepository {
  const SellRepository(this._dio);
  final Dio _dio;

  Future<SellConfig> config() async => SellConfig.fromJson(
        _data(await _dio.get<dynamic>('/sell-requests/journey-config')),
      );

  /// Same device catalogue as the Exchange flow (brand logos, variants, colours).
  Future<List<ExchangeModel>> catalog() async {
    final Response<dynamic> r = await _dio
        .get<dynamic>('/sell-requests/catalog')
        .timeout(const Duration(seconds: 25));
    return ((r.data as Map)['data'] as List? ?? <Object?>[])
        .whereType<Map>()
        .map((Map e) => ExchangeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ImeiCheck> verifyImei(String imei, {String? modelId}) async =>
      ImeiCheck.fromJson(
        _data(
          await _dio.post<dynamic>(
            '/sell-requests/verify-imei',
            data: <String, dynamic>{
              'imei': imei,
              if (modelId != null) 'modelId': modelId,
            },
          ),
        ),
      );

  Map<String, dynamic> _body({
    required ExchangeModel? model,
    required String variant,
    required String color,
    required String imei,
    required ExchangeQa qa,
    Map<String, dynamic>? custom,
    Map<String, dynamic>? location,
    String? city,
  }) =>
      <String, dynamic>{
        'type': 'SELL_TO_AB',
        if (model != null) 'modelId': model.id,
        if (custom != null) 'custom': custom,
        'variant': variant,
        'color': color,
        'imei': imei,
        'qa': qa.toJson(),
        if (location != null) 'location': location,
        if (city != null) 'customer': <String, dynamic>{'city': city},
      };

  Future<SellEstimate> estimate({
    required ExchangeModel? model,
    required String variant,
    required String color,
    required String imei,
    required ExchangeQa qa,
    Map<String, dynamic>? custom,
    Map<String, dynamic>? location,
    String? city,
  }) async =>
      SellEstimate.fromJson(
        _data(
          await _dio.post<dynamic>(
            '/sell-requests/estimate',
            data: _body(
              model: model,
              variant: variant,
              color: color,
              imei: imei,
              qa: qa,
              custom: custom,
              location: location,
              city: city,
            ),
          ),
        ),
      );

  /// Photos go to the private evidence store; the request references the returned ids.
  Future<String> uploadPhoto(XFile file) async {
    final Response<dynamic> r = await _dio.post<dynamic>(
      '/sell-requests/media',
      data: FormData.fromMap(
        <String, dynamic>{'files': await pickedFileMultipart(file)},
      ),
      options: Options(
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    final Object? files = _data(r)['files'];
    final Map<String, dynamic> first =
        Map<String, dynamic>.from((files as List).first as Map);
    if (first['ok'] != true) {
      throw StateError('${first['message'] ?? 'Upload failed'}');
    }
    return '${(first['media'] as Map)['id']}';
  }

  /// Creates the listing; vendors near the customer can now offer. Returns the request id.
  Future<String> submit({
    required ExchangeModel? model,
    required String variant,
    required String color,
    required String imei,
    required ExchangeQa qa,
    Map<String, dynamic>? custom,
    required String imeiCheckId,
    List<String> mediaIds = const <String>[],
    required double askingPrice,
    String? description,
    Map<String, dynamic>? location,
    String? city,
  }) async {
    final Map<String, dynamic> d = _data(
      await _dio.post<dynamic>(
        '/sell-requests',
        data: <String, dynamic>{
          ..._body(
            model: model,
            variant: variant,
            color: color,
            imei: imei,
            qa: qa,
            custom: custom,
            location: location,
            city: city,
          ),
          'imeiCheckId': imeiCheckId,
          'expectedPrice': askingPrice.round(),
          if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
      ),
    );
    return '${d['id']}';
  }

  Future<List<SellListItem>> mine() async {
    final Response<dynamic> r = await _dio.get<dynamic>(
      '/sell-requests/mine',
      queryParameters: <String, dynamic>{'limit': 30},
    );
    final Object? data = (r.data as Map)['data'];
    final List<dynamic> items =
        data is Map ? (data['items'] as List? ?? <Object?>[]) : <Object?>[];
    return items
        .whereType<Map>()
        .map((Map e) => SellListItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<SellThreadSummary>> threads(String id) async =>
      (_data(await _dio.get<dynamic>('/sell-requests/$id/threads'))['threads']
                  as List? ??
              <Object?>[])
          .whereType<Map>()
          .map(
            (Map e) => SellThreadSummary.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();

  Future<SellThread> thread(String id, String vendorId) async =>
      SellThread.fromJson(
        _data(await _dio.get<dynamic>('/sell-requests/$id/threads/$vendorId')),
      );

  Future<SellThread> sendMessage(
    String id,
    String vendorId,
    String body,
  ) async =>
      SellThread.fromJson(
        _data(
          await _dio.post<dynamic>(
            '/sell-requests/$id/threads/$vendorId/messages',
            data: <String, dynamic>{'body': body},
          ),
        ),
      );

  Future<SellJourney> journey(String id) async => SellJourney.fromJson(
        _data(await _dio.get<dynamic>('/sell-requests/$id/journey')),
      );

  Future<Map<String, dynamic>> request(String id) async =>
      _data(await _dio.get<dynamic>('/sell-requests/$id'));

  Future<SellOffers> offers(String id) async => SellOffers.fromJson(
        _data(await _dio.get<dynamic>('/sell-requests/$id/offers')),
      );

  Future<SellOffers> refreshOffers(String id) async => SellOffers.fromJson(
        _data(await _dio.post<dynamic>('/sell-requests/$id/offers/refresh',
            data: const <String, dynamic>{})),
      );

  Future<SellJourney> acceptOffer(String id, String offerId) async =>
      SellJourney.fromJson(
        _data(
          await _dio.post<dynamic>(
            '/sell-requests/$id/offers/$offerId/accept',
            data: const <String, dynamic>{},
          ),
        ),
      );

  Future<SellJourney> bookFulfilment(
    String id,
    Map<String, dynamic> body,
  ) async =>
      SellJourney.fromJson(
        _data(
          await _dio.post<dynamic>('/sell-requests/$id/fulfilment', data: body),
        ),
      );

  Future<void> decidePrice(String id, {required bool accept}) async {
    await _dio.post<dynamic>(
      '/sell-requests/$id/qc/decision',
      data: <String, dynamic>{'decision': accept ? 'ACCEPT' : 'DECLINE'},
    );
  }

  Future<SellJourney> choosePayout(
    String id,
    Map<String, dynamic> body,
  ) async =>
      SellJourney.fromJson(
        _data(
          await _dio.post<dynamic>('/sell-requests/$id/payout', data: body),
        ),
      );

  Future<void> cancel(String id, String reason) async {
    await _dio.post<dynamic>(
      '/sell-requests/$id/cancel',
      data: <String, dynamic>{'reason': reason},
    );
  }

  Map<String, dynamic> _data(Response<dynamic> r) =>
      Map<String, dynamic>.from((r.data as Map)['data'] as Map);
}

/// The server's own message for a failed call, else a plain fallback.
String sellErrorMessage(
  Object e, [
  String fallback = 'Something went wrong. Please try again.',
]) {
  if (e is DioException) {
    final Object? d = e.response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Check your connection and try again.';
    }
  }
  return fallback;
}
