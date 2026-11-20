import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';

String _s(dynamic v) => v == null ? '' : '$v';
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
DateTime? _d(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// Support phone, email and opening hours (edited by the admin in Dashboard → Settings).
class SupportContact {
  const SupportContact({this.phone, this.email, this.hours});
  final String? phone;
  final String? email;
  final String? hours;

  factory SupportContact.fromJson(Map<String, dynamic> j) {
    String? n(dynamic v) => _s(v).trim().isEmpty ? null : _s(v).trim();
    return SupportContact(phone: n(j['phone']), email: n(j['email']), hours: n(j['hours']));
  }
}

/// One support conversation. [number] is the token the vendor quotes (e.g. TKT-1042).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.number,
    required this.subject,
    required this.status,
    required this.category,
    required this.unread,
    this.preview,
    this.lastAt,
    this.createdAt,
  });
  final String id;
  final String number;
  final String subject;
  final String status; // OPEN | ASSIGNED | IN_PROGRESS | RESOLVED | CLOSED | REOPENED
  final String category;
  final int unread;
  final String? preview;
  final DateTime? lastAt;
  final DateTime? createdAt;

  bool get closed => status == 'CLOSED';
  bool get resolved => status == 'RESOLVED' || status == 'CLOSED';

  /// What the vendor should read: where this conversation stands.
  String get statusLabel => switch (status) {
        'OPEN' => 'Waiting for support',
        'ASSIGNED' => 'Assigned',
        'IN_PROGRESS' => 'Support is on it',
        'REOPENED' => 'Reopened',
        'RESOLVED' => 'Resolved',
        'CLOSED' => 'Closed',
        _ => status,
      };

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: _s(j['id']),
        number: _s(j['ticket_number']),
        subject: _s(j['subject']),
        status: _s(j['status']),
        category: _s(j['category']),
        unread: _i(j['customer_unread']),
        preview: _s(j['last_message_preview']).isEmpty ? null : _s(j['last_message_preview']),
        lastAt: _d(j['last_message_at']),
        createdAt: _d(j['created_at']),
      );
}

class SupportMessage {
  const SupportMessage({required this.id, required this.mine, required this.body, this.at, this.system = false});
  final String id;
  final bool mine;
  final String body;
  final DateTime? at;
  final bool system;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.data,
    this.at,
  });
  final String id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final Map<String, dynamic> data;
  final DateTime? at;

  /// Set on "customer asked for a return" notifications (type RETURN) — opens that return.
  String? get returnId => type == 'RETURN' && data['refundRequestId'] != null ? '${data['refundRequestId']}' : null;

  String? get ticketId => type == 'SUPPORT' ? (data['ticketId'] == null ? null : '${data['ticketId']}') : null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _s(j['id']),
        title: _s(j['title']),
        body: _s(j['body']),
        type: _s(j['type']),
        read: j['is_read'] == true,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        at: _d(j['created_at']),
      );
}

/// Help & Support (tickets + chat) and the notification centre for the signed-in vendor.
class SupportRepository {
  SupportRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(path,
          data: body, queryParameters: query, options: Options(method: method));
      return res.data ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> b) => (b['data'] as Map?)?.cast<String, dynamic>() ?? const {};

  Future<SupportContact> contact() async =>
      SupportContact.fromJson(_data(await _send('GET', '/vendor/store/support-contact')));

  Future<List<SupportTicket>> tickets() async {
    final b = await _send('GET', '/support/tickets');
    return [
      for (final t in (b['data'] as List? ?? const []))
        if (t is Map) SupportTicket.fromJson(t.cast<String, dynamic>())
    ];
  }

  /// Start a conversation; returns it so the app can open the chat room.
  Future<SupportTicket> createTicket({required String subject, required String message, required String category}) async {
    final d = _data(await _send('POST', '/support/tickets',
        body: {'subject': subject, 'message': message, 'category': category}));
    return SupportTicket.fromJson((d['ticket'] as Map?)?.cast<String, dynamic>() ?? d);
  }

  Future<({SupportTicket ticket, List<SupportMessage> messages})> ticket(String id) async {
    final d = _data(await _send('GET', '/support/tickets/$id'));
    final t = SupportTicket.fromJson((d['ticket'] as Map).cast<String, dynamic>());
    final msgs = [
      for (final m in (d['messages'] as List? ?? const []))
        if (m is Map)
          SupportMessage(
            id: _s(m['id']),
            mine: _s(m['sender_type']) == 'CUSTOMER',
            system: _s(m['sender_type']) == 'SYSTEM',
            body: _s(m['body']),
            at: _d(m['created_at']),
          )
    ];
    return (ticket: t, messages: msgs);
  }

  Future<void> sendMessage(String id, String body) =>
      _send('POST', '/support/tickets/$id/messages', body: {'body': body});

  // ── notifications ───────────────────────────────────────────────────

  Future<({List<AppNotification> items, int unread})> notifications({int limit = 50}) async {
    final d = _data(await _send('GET', '/notifications', query: {'limit': limit}));
    final items = [
      for (final n in (d['notifications'] as List? ?? const []))
        if (n is Map) AppNotification.fromJson(n.cast<String, dynamic>())
    ];
    return (items: items, unread: _i(d['unreadCount']));
  }

  Future<void> markRead(String id) => _send('PATCH', '/notifications/$id/read');
  Future<void> markAllRead() => _send('PATCH', '/notifications/read-all');
}
