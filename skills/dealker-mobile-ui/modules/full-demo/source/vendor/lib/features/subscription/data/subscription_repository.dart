import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/repair_book/shims/picked_file_upload.dart';

num _n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

/// A paid plan a vendor can buy (GET /subscriptions/plans).
class SubPlan {
  const SubPlan({
    required this.tier,
    required this.name,
    required this.description,
    required this.priceMonthly,
    required this.priceYearly,
    required this.listingLimit,
    required this.features,
  });
  final String tier; // PAID | PREMIUM | UNLIMITED
  final String name;
  final String description;
  final num priceMonthly;
  final num priceYearly;
  final int? listingLimit; // null = unlimited
  final List<String> features;

  num price(bool yearly) => yearly ? priceYearly : priceMonthly;

  /// What the yearly price saves compared with twelve months.
  num get yearlySaving => priceMonthly * 12 - priceYearly;

  factory SubPlan.fromJson(Map<String, dynamic> j) => SubPlan(
        tier: _s(j['tier']),
        name: _s(j['name']),
        description: _s(j['description']),
        priceMonthly: _n(j['priceMonthly']),
        priceYearly: _n(j['priceYearly']),
        listingLimit: j['listingLimit'] == null ? null : _n(j['listingLimit']).toInt(),
        features: [for (final f in (j['features'] as List? ?? const [])) '$f'],
      );
}

/// Razorpay order for a plan purchase (POST /subscriptions/checkout).
class SubCheckout {
  const SubCheckout(this.orderId, this.amount, this.keyId, this.planName);
  final String orderId;
  final num amount;
  final String keyId;
  final String planName;
  int get amountPaise => (amount * 100).round();
}

/// Followers of the vendor's shop and the shop photo (GET /vendor/growth).
class Growth {
  const Growth({
    required this.followers,
    required this.thisWeek,
    required this.thisMonth,
    this.shopName,
    this.logoUrl,
  });
  final int followers;
  final int thisWeek;
  final int thisMonth;
  final String? shopName;
  final String? logoUrl;

  factory Growth.fromJson(Map<String, dynamic> j) => Growth(
        followers: _n(j['followers']).toInt(),
        thisWeek: _n(j['followersThisWeek']).toInt(),
        thisMonth: _n(j['followersThisMonth']).toInt(),
        shopName: _s(j['shopName']).isEmpty ? null : _s(j['shopName']),
        logoUrl: _s(j['logoUrl']).isEmpty ? null : _s(j['logoUrl']),
      );
}

class SubscriptionRepository {
  SubscriptionRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body}) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(path,
          data: body, options: Options(method: method));
      return res.data ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> b) =>
      (b['data'] as Map?)?.cast<String, dynamic>() ?? const {};

  Future<List<SubPlan>> plans() async {
    final b = await _send('GET', '/subscriptions/plans');
    return [
      for (final p in (b['data'] as List? ?? const []))
        if (p is Map) SubPlan.fromJson(p.cast<String, dynamic>())
    ];
  }

  Future<SubCheckout> checkout(String tier, bool yearly) async {
    final d = _data(await _send('POST', '/subscriptions/checkout',
        body: {'tier': tier, 'cycle': yearly ? 'YEARLY' : 'MONTHLY'}));
    return SubCheckout(_s(d['razorpayOrderId']), _n(d['amount']), _s(d['keyId']), _s(d['planName']));
  }

  Future<void> verify({
    required String orderId,
    required String paymentId,
    required String signature,
  }) =>
      _send('POST', '/subscriptions/verify',
          body: {'orderId': orderId, 'paymentId': paymentId, 'signature': signature});

  Future<Growth> growth() async =>
      Growth.fromJson(_data(await _send('GET', '/vendor/growth')));

  /// Upload a picked photo, then set it as the shop profile photo. Returns the new image link.
  Future<String> setShopPhoto(XFile file) async {
    final up = await _send('POST', '/uploads/local?kind=shop',
        body: FormData.fromMap({'file': await pickedFileMultipart(file)}));
    final urls = (_data(up)['urls'] as List?) ?? const [];
    if (urls.isEmpty) throw StateError('Upload failed');
    final url = '${urls.first}';
    await _send('PUT', '/vendor/growth/logo', body: {'url': url});
    return url;
  }
}
