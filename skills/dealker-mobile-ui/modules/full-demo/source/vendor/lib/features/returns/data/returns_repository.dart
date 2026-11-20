import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/returns/data/return_models.dart';

/// Customer returns on the vendor's own order lines (`/manage/returns`; the JWT decides whose).
/// The vendor can read them, answer once ("I agree" / "I dispute"), and open a chat with Dealkr Support —
/// the Dealkr team decides, moves the money and arranges the pickup.
class ReturnsRepository {
  ReturnsRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _send(String method, String path,
      {Object? body, Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(path,
          data: body, queryParameters: query, options: Options(method: method));
      return res.data ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> b) => (b['data'] as Map?)?.cast<String, dynamic>() ?? const {};

  Future<ReturnSummary> summary() async =>
      ReturnSummary.fromJson(_data(await _send('GET', '/manage/returns/summary')));

  /// [state]: '' (all) | 'open' | 'needs_response' | 'closed'.
  Future<ReturnPage> list({String state = '', String search = '', String? sellerOrderId, int limit = 50}) async {
    final b = await _send('GET', '/manage/returns', query: {
      'limit': limit,
      if (state.isNotEmpty) 'state': state,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (sellerOrderId != null) 'sellerOrderId': sellerOrderId,
    });
    final rows = [
      for (final r in (b['data'] as List? ?? const []))
        if (r is Map) ReturnRow.fromJson(r.cast<String, dynamic>())
    ];
    final total = (((b['pagination'] as Map?)?['total']) as num?)?.toInt() ?? rows.length;
    return ReturnPage(items: rows, total: total);
  }

  Future<ReturnDetail> detail(String id) async =>
      ReturnDetail.fromJson(_data(await _send('GET', '/manage/returns/$id')));

  Future<ReturnDetail> respond(String id,
          {required String stance, required String note, List<ReturnEvidence> evidence = const []}) async =>
      ReturnDetail.fromJson(_data(await _send('POST', '/manage/returns/$id/respond', body: {
        'stance': stance,
        'note': note,
        if (evidence.isNotEmpty) 'evidence': [for (final e in evidence) e.toJson()],
      })));

  /// Get-or-create the vendor's chat with Dealkr Support for this return.
  /// Messages then flow through the normal support-ticket endpoints (SupportRepository).
  Future<ReturnChatRef> openChat(String id, {String? message}) async =>
      ReturnChatRef.fromJson(_data(await _send('POST', '/manage/returns/$id/chat',
          body: {if (message != null && message.trim().isNotEmpty) 'message': message.trim()})));

  /// Proof photo for an answer — the same endpoint the product flow uses.
  Future<String> uploadImage(String filePath) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/image',
        queryParameters: {'kind': 'listing'},
        data: FormData.fromMap({'file': await MultipartFile.fromFile(filePath)}),
      );
      final url = ((res.data?['data'] as Map?)?['url']) as String?;
      if (url == null || url.isEmpty) throw const FormatException('Upload returned no URL');
      return url;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }
}
