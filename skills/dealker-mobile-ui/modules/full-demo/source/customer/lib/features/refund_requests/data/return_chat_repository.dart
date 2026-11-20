import 'package:dio/dio.dart';

/// One message in the return conversation.
class ReturnChatMessage {
  const ReturnChatMessage({
    required this.id,
    required this.body,
    required this.fromCustomer,
    required this.senderName,
    required this.at,
  });

  final String id;
  final String body;
  final bool fromCustomer;
  final String? senderName;
  final DateTime at;
}

class ReturnChatThread {
  const ReturnChatThread({
    required this.ticketId,
    required this.ticketNumber,
    required this.status,
    required this.messages,
  });

  final String ticketId;
  final String ticketNumber;
  final String status;
  final List<ReturnChatMessage> messages;

  bool get isClosed => status == 'CLOSED';
}

/// The customer support chat (`/support/tickets`) tied to one refund request.
class ReturnChatRepository {
  const ReturnChatRepository(this._dio);

  final Dio _dio;

  /// The conversation for this refund request, or null when none was started yet.
  Future<ReturnChatThread?> find(String refundRequestId) async {
    final Response<dynamic> r = await _dio.get<dynamic>('/support/tickets');
    final Object? list = (r.data as Map)['data'];
    if (list is! List) return null;
    for (final Object? t in list) {
      if (t is Map &&
          t['refund'] is Map &&
          (t['refund'] as Map)['id'] == refundRequestId) {
        return open('${t['id']}');
      }
    }
    return null;
  }

  /// The customer's latest open general conversation (one not tied to a
  /// refund request), or null when none exists — the Account screen's
  /// "Chat with Support" continues it instead of opening a new ticket.
  Future<ReturnChatThread?> findGeneral() async {
    final Response<dynamic> r = await _dio.get<dynamic>('/support/tickets');
    final Object? list = (r.data as Map)['data'];
    if (list is! List) return null;
    for (final Object? t in list) {
      if (t is Map && t['refund'] == null && t['status'] != 'CLOSED') {
        return open('${t['id']}');
      }
    }
    return null;
  }

  Future<ReturnChatThread> startGeneral(String message,
      {String? orderNumber}) async {
    final Response<dynamic> r = await _dio.post<dynamic>(
      '/support/tickets',
      data: <String, dynamic>{
        'subject':
            orderNumber == null ? 'Customer support' : 'Order $orderNumber',
        'message': message,
        'category': 'GENERAL',
      },
    );
    return _thread((r.data as Map)['data'] as Map);
  }

  Future<ReturnChatThread> open(String ticketId) async {
    final Response<dynamic> r =
        await _dio.get<dynamic>('/support/tickets/$ticketId');
    return _thread((r.data as Map)['data'] as Map);
  }

  Future<ReturnChatThread> start({
    required String orderId,
    required String refundRequestId,
    required String returnNumber,
    required String message,
  }) async {
    final Response<dynamic> r = await _dio.post<dynamic>(
      '/support/tickets',
      data: <String, dynamic>{
        'subject': 'Return $returnNumber',
        'message': message,
        'category': 'RETURN_REFUND',
        'orderId': orderId,
        'refundRequestId': refundRequestId,
      },
    );
    return _thread((r.data as Map)['data'] as Map);
  }

  Future<void> send(String ticketId, String body) async {
    await _dio.post<dynamic>(
      '/support/tickets/$ticketId/messages',
      data: <String, dynamic>{'body': body},
    );
  }

  ReturnChatThread _thread(Map<dynamic, dynamic> d) {
    final Map<dynamic, dynamic> t =
        (d['ticket'] as Map?) ?? const <String, dynamic>{};
    final List<dynamic> msgs = (d['messages'] as List?) ?? const <dynamic>[];
    return ReturnChatThread(
      ticketId: '${t['id']}',
      ticketNumber: '${t['ticket_number'] ?? ''}',
      status: '${t['status'] ?? 'OPEN'}',
      messages: msgs
          .whereType<Map>()
          .map(
            (Map m) => ReturnChatMessage(
              id: '${m['id']}',
              body: '${m['body'] ?? ''}',
              fromCustomer: m['sender_type'] == 'CUSTOMER',
              senderName: m['sender_name'] as String?,
              at: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
                  DateTime.now(),
            ),
          )
          .toList(),
    );
  }

  static String errorMessage(Object e) {
    if (e is DioException) {
      final Object? d = e.response?.data;
      if (d is Map && d['message'] is String) return d['message'] as String;
    }
    return 'Something went wrong. Please try again.';
  }
}
