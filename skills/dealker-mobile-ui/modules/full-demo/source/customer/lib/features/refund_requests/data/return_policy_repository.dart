import 'package:dio/dio.dart';

/// One rule on the "Our Return Policy" screen.
class ReturnPolicyPoint {
  const ReturnPolicyPoint({required this.title, required this.text});

  final String title;
  final String text;
}

/// Return window and rules, edited in the dashboard (Settings → Returns Policy).
class ReturnPolicy {
  const ReturnPolicy({
    required this.windowDays,
    required this.freePickup,
    required this.points,
  });

  final int windowDays;
  final bool freePickup;
  final List<ReturnPolicyPoint> points;

  /// Last day a delivered order can still be returned.
  DateTime lastDate(DateTime deliveredAt) =>
      deliveredAt.add(Duration(days: windowDays));

  bool isOpen(DateTime deliveredAt, {DateTime? now}) =>
      !(now ?? DateTime.now()).isAfter(lastDate(deliveredAt));
}

/// Return-flow calls that are not part of the refund request itself: policy + answering the QC price.
class ReturnPolicyRepository {
  const ReturnPolicyRepository(this._dio);

  final Dio _dio;

  Future<ReturnPolicy> fetch() async {
    final Response<dynamic> r =
        await _dio.get<dynamic>('/refund-requests/policy');
    final Map<dynamic, dynamic> d = (r.data as Map)['data'] as Map;
    final Object? raw = d['points'];
    return ReturnPolicy(
      windowDays: (d['window_days'] as num?)?.toInt() ?? 7,
      freePickup: d['free_pickup'] != false,
      points: raw is List
          ? raw
              .whereType<Map>()
              .map(
                (Map p) => ReturnPolicyPoint(
                  title: '${p['title'] ?? ''}',
                  text: '${p['text'] ?? ''}',
                ),
              )
              .toList()
          : const <ReturnPolicyPoint>[],
    );
  }

  Future<void> acceptPrice(String refundId) async {
    // An empty JSON body: Fastify rejects a JSON content-type with no body.
    await _dio.post<dynamic>(
      '/refund-requests/$refundId/qc/accept',
      data: <String, dynamic>{},
    );
  }

  Future<void> askAboutPrice(String refundId, String message) async {
    await _dio.post<dynamic>(
      '/refund-requests/$refundId/qc/clarify',
      data: <String, dynamic>{'message': message},
    );
  }
}
