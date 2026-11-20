import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_models.dart';

/// All abandoned-cart calls. The JWT carries the vendor; the server returns only
/// this vendor's own lines of each cart and masks the customer.
class CartRepository {
  CartRepository(this._dio);
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

  Future<CartSummary> summary({CartChannel channel = CartChannel.all}) async =>
      CartSummary.fromJson(_map((await _send(
          'GET', '/manage/abandoned-carts/summary',
          query: {'channel': channel.api}))['data']));

  Future<CartPage> list(CartQuery q, {int limit = 50}) async {
    final b = await _send('GET', '/manage/abandoned-carts', query: {
      'channel': q.channel.api,
      if (q.openOnly) 'state': CartState.abandoned,
      'limit': limit,
    });
    final rows = ((b['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CartRow.fromJson)
        .toList();
    return CartPage(
        items: rows,
        total:
            ((_map(b['pagination'])['total']) as num?)?.toInt() ?? rows.length);
  }

  Future<CartDetail> detail(String id) async => CartDetail.fromJson(
      _map((await _send('GET', '/manage/abandoned-carts/$id'))['data']));

  Future<ReminderPreview> preview(
          String id, String templateKey, List<String> productIds) async =>
      ReminderPreview.fromJson(_map(
          (await _send('GET', '/manage/abandoned-carts/$id/preview', query: {
        'templateKey': templateKey,
        if (productIds.isNotEmpty) 'productIds': productIds.join(','),
      }))['data']));

  /// Sends a push reminder about [productIds] (empty = all of this vendor's items).
  Future<CartDetail> remind(
          String id, String templateKey, List<String> productIds) async =>
      CartDetail.fromJson(_map(
          (await _send('POST', '/manage/abandoned-carts/$id/remind', body: {
        'templateKey': templateKey,
        if (productIds.isNotEmpty) 'productIds': productIds,
      }))['data']));

  /// Sends a one-time coupon for [productId] (flat ₹ or percentage) to the shopper. Returns the refreshed cart.
  Future<CartDetail> sendCoupon(String id,
          {required String productId,
          required String discountType,
          required num value,
          required int validDays}) async =>
      CartDetail.fromJson(_map(
          (await _send('POST', '/manage/abandoned-carts/$id/coupons', body: {
        'productId': productId,
        'discountType': discountType,
        'value': value,
        'validDays': validDays,
      }))['data']));

  Future<CartDetail> cancelCoupon(String id, String couponId) async =>
      CartDetail.fromJson(_map(
          (await _send('DELETE', '/manage/abandoned-carts/$id/coupons/$couponId'))['data']));
}
