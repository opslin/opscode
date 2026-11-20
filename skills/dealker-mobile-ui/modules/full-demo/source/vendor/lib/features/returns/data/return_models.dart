String _s(dynamic v) => v == null ? '' : '$v';
String? _n(dynamic v) => _s(v).trim().isEmpty ? null : _s(v).trim();
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
DateTime? _t(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
Map<String, dynamic> _m(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};
List<Map<String, dynamic>> _l(dynamic v) =>
    [for (final x in (v as List? ?? const [])) if (x is Map) x.cast<String, dynamic>()];

/// Where a return sits for the vendor (server field `stage`).
enum ReturnStage {
  needsResponse('NEEDS_RESPONSE', 'Needs your answer'),
  withTeam('WITH_TEAM', 'With Dealkr team'),
  refunded('REFUNDED', 'Refunded to customer'),
  rejected('REJECTED', 'Return rejected'),
  cancelled('CANCELLED', 'Cancelled by customer');

  const ReturnStage(this.code, this.label);
  final String code;
  final String label;

  static ReturnStage from(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => withTeam);

  bool get open => this == needsResponse || this == withTeam;
}

class ReturnSummary {
  const ReturnSummary({
    this.total = 0,
    this.open = 0,
    this.needsResponse = 0,
    this.withTeam = 0,
    this.closed = 0,
    this.unreadChat = 0,
  });
  final int total;
  final int open;
  final int needsResponse;
  final int withTeam;
  final int closed;
  final int unreadChat;

  factory ReturnSummary.fromJson(Map<String, dynamic> j) => ReturnSummary(
        total: _i(j['total']),
        open: _i(j['open']),
        needsResponse: _i(j['needs_response']),
        withTeam: _i(j['with_team']),
        closed: _i(j['closed']),
        unreadChat: _i(j['unread_chat']),
      );
}

class ReturnPreviewItem {
  const ReturnPreviewItem(this.name, this.image);
  final String name;
  final String? image;
}

/// One row of the returns list.
class ReturnRow {
  const ReturnRow({
    required this.id,
    required this.returnNumber,
    required this.orderNumber,
    required this.stage,
    required this.reason,
    required this.itemCount,
    required this.itemsPreview,
    required this.atRisk,
    required this.createdAt,
    this.reasonLabel,
    this.myStance,
    this.chatUnread = 0,
  });
  final String id;
  final String returnNumber;
  final String orderNumber;
  final ReturnStage stage;
  final String reason;
  final String? reasonLabel;
  final int itemCount;
  final List<ReturnPreviewItem> itemsPreview;

  /// What the covered lines on THIS vendor's parcels are worth (₹).
  final double atRisk;
  final DateTime? createdAt;
  final String? myStance; // AGREE | DISPUTE
  final int chatUnread;

  factory ReturnRow.fromJson(Map<String, dynamic> j) => ReturnRow(
        id: _s(j['id']),
        returnNumber: _s(j['return_number']),
        orderNumber: _s(j['order_number']),
        stage: ReturnStage.from(_n(j['stage'])),
        reason: _s(j['reason']),
        reasonLabel: _n(j['reason_label']),
        itemCount: _i(j['item_count']),
        itemsPreview: [
          for (final p in _l(j['items_preview']))
            ReturnPreviewItem(_s(p['name']), _n(p['image']))
        ],
        atRisk: _d(j['at_risk_amount']),
        createdAt: _t(j['created_at']),
        myStance: _n(j['my_stance']),
        chatUnread: _i(j['chat_unread']),
      );
}

class ReturnPage {
  const ReturnPage({required this.items, required this.total});
  final List<ReturnRow> items;
  final int total;
}

class ReturnLine {
  const ReturnLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.image,
    this.parcel,
  });
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? image;
  final String? parcel;

  factory ReturnLine.fromJson(Map<String, dynamic> j) => ReturnLine(
        name: _s(j['name']),
        quantity: _i(j['quantity']),
        unitPrice: _d(j['unit_price']),
        lineTotal: _d(j['line_total']),
        image: _n(j['image']),
        parcel: _n(j['parcel']),
      );
}

class ReturnEvidence {
  const ReturnEvidence(this.url, this.kind);
  final String url;
  final String kind; // IMAGE | VIDEO
  bool get isVideo => kind == 'VIDEO';
  Map<String, dynamic> toJson() => {'url': url, 'kind': kind};
}

class ReturnStep {
  const ReturnStep({required this.key, required this.title, this.at, this.current = false});
  final String key;
  final String title;
  final DateTime? at;
  final bool current;
}

class ReturnPickup {
  const ReturnPickup({
    required this.status,
    this.provider,
    this.courier,
    this.awb,
    this.trackingUrl,
    this.scheduledAt,
    this.pickedUpAt,
    this.receivedAt,
  });
  final String status;
  final String? provider;
  final String? courier;
  final String? awb;
  final String? trackingUrl;
  final DateTime? scheduledAt;
  final DateTime? pickedUpAt;
  final DateTime? receivedAt;

  String get label => switch (status) {
        'PICKUP_SCHEDULED' => 'Pickup scheduled',
        'PICKED_UP' => 'Picked up from the customer',
        'IN_TRANSIT' => 'On its way to Dealkr',
        'RECEIVED' => 'Received at the Dealkr centre',
        'FAILED' => 'Pickup failed',
        'CANCELLED' => 'Pickup cancelled',
        _ => status,
      };

  factory ReturnPickup.fromJson(Map<String, dynamic> j) => ReturnPickup(
        status: _s(j['status']),
        provider: _n(j['provider']),
        courier: _n(j['courier_name']),
        awb: _n(j['awb']),
        trackingUrl: _n(j['tracking_url']),
        scheduledAt: _t(j['scheduled_at']),
        pickedUpAt: _t(j['picked_up_at']),
        receivedAt: _t(j['received_at']),
      );
}

class ReturnQcCheck {
  const ReturnQcCheck(this.label, this.status, this.note);
  final String label;
  final String status; // OK | MINOR_ISSUE | FAILED
  final String? note;
}

class ReturnQc {
  const ReturnQc({required this.checks, this.summary, this.inspectedAt});
  final List<ReturnQcCheck> checks;
  final String? summary;
  final DateTime? inspectedAt;

  factory ReturnQc.fromJson(Map<String, dynamic> j) => ReturnQc(
        checks: [
          for (final c in _l(j['checks']))
            ReturnQcCheck(_s(c['label']), _s(c['status']), _n(c['note']))
        ],
        summary: _n(j['summary']),
        inspectedAt: _t(j['inspected_at']),
      );
}

/// The vendor's own answer ("I agree" / "I dispute").
class ReturnResponse {
  const ReturnResponse({required this.stance, required this.note, required this.evidence, this.at});
  final String stance; // AGREE | DISPUTE
  final String note;
  final List<ReturnEvidence> evidence;
  final DateTime? at;
  bool get agreed => stance == 'AGREE';

  factory ReturnResponse.fromJson(Map<String, dynamic> j) => ReturnResponse(
        stance: _s(j['stance']),
        note: _s(j['note']),
        evidence: [for (final e in _l(j['evidence'])) ReturnEvidence(_s(e['url']), _s(e['kind']))],
        at: _t(j['at']),
      );
}

/// The vendor's support conversation about this return (null until they open it).
class ReturnChatRef {
  const ReturnChatRef({required this.ticketId, required this.number, required this.status, this.unread = 0});
  final String ticketId;
  final String number;
  final String status;
  final int unread;

  factory ReturnChatRef.fromJson(Map<String, dynamic> j) => ReturnChatRef(
        ticketId: _s(j['ticket_id']),
        number: _s(j['ticket_number']),
        status: _s(j['status']),
        unread: _i(j['unread']),
      );
}

class ReturnDetail {
  const ReturnDetail({
    required this.row,
    required this.orderId,
    required this.customerName,
    required this.items,
    required this.evidence,
    required this.timeline,
    required this.canRespond,
    this.deliveredAt,
    this.pickup,
    this.qc,
    this.teamNote,
    this.response,
    this.chat,
  });
  final ReturnRow row;
  final String orderId;
  final DateTime? deliveredAt;
  final String customerName;
  final List<ReturnLine> items;
  final List<ReturnEvidence> evidence;
  final List<ReturnStep> timeline;
  final ReturnPickup? pickup;
  final ReturnQc? qc;
  final String? teamNote;
  final ReturnResponse? response;
  final bool canRespond;
  final ReturnChatRef? chat;

  factory ReturnDetail.fromJson(Map<String, dynamic> j) {
    final order = _m(j['order']);
    return ReturnDetail(
      row: ReturnRow.fromJson(j),
      orderId: _s(order['id']),
      deliveredAt: _t(order['delivered_at']),
      customerName: _s(_m(j['customer'])['name']),
      items: [for (final l in _l(j['items'])) ReturnLine.fromJson(l)],
      evidence: [for (final e in _l(j['evidence'])) ReturnEvidence(_s(e['url']), _s(e['kind']))],
      timeline: [
        for (final s in _l(j['timeline']))
          ReturnStep(key: _s(s['key']), title: _s(s['title']), at: _t(s['at']), current: s['current'] == true)
      ],
      pickup: j['pickup'] is Map ? ReturnPickup.fromJson(_m(j['pickup'])) : null,
      qc: j['qc'] is Map ? ReturnQc.fromJson(_m(j['qc'])) : null,
      teamNote: _n(j['team_note']),
      response: j['response'] is Map ? ReturnResponse.fromJson(_m(j['response'])) : null,
      canRespond: j['can_respond'] == true,
      chat: j['chat'] is Map ? ReturnChatRef.fromJson(_m(j['chat'])) : null,
    );
  }
}
