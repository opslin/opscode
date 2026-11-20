// Models for the vendor's Abandoned Carts. Field names follow the real API
// (`/manage/abandoned-carts`, snake_case). A vendor only ever receives THEIR OWN
// lines of a cart and a masked customer name — never phone/email or other sellers' items.
// Parsing is defensive so a missing field never crashes a screen.

num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
int _i(dynamic v) => _n(v)?.toInt() ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';
Map<String, dynamic> _m(dynamic v) =>
    (v as Map?)?.cast<String, dynamic>() ?? const {};
List<Map<String, dynamic>> _l(dynamic v) =>
    ((v as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
DateTime? _ts(dynamic v) => DateTime.tryParse(_s(v))?.toLocal();

/// B2C = retail cart, B2B = wholesale cart. [api] is the server's filter value.
enum CartChannel {
  all('All', 'ALL'),
  b2b('B2B', 'B2B'),
  b2c('B2C', 'B2C');

  const CartChannel(this.label, this.api);
  final String label;
  final String api;
  static CartChannel of(String s) =>
      s == 'B2B' ? b2b : (s == 'B2C' ? b2c : all);
}

/// What the vendor can do about a cart, as the server states it.
class CartState {
  CartState._();
  static const abandoned = 'ABANDONED';
  static const ordered = 'ORDERED';
  static const backInCart = 'BACK_IN_CART';
  static const closed = 'CLOSED';
}

/// Percentage change vs the previous period, or null when there is nothing to compare.
double? _pct(dynamic v) => _n(v)?.toDouble();

class CartSummary {
  const CartSummary({
    this.days = 30,
    this.idleMinutes = 30,
    this.carts = 0,
    this.openCarts = 0,
    this.pendingValue = 0,
    this.recoveredOrders = 0,
    this.recoveredValue = 0,
    this.orderedAfterReminder = 0,
    this.recoveryRate = 0,
    this.cartsChange,
    this.valueChange,
    this.ordersChange,
    this.rateChange,
  });
  final int days;
  final int idleMinutes;
  final int carts;
  final int openCarts;
  final num pendingValue;
  final int recoveredOrders;
  final num recoveredValue;
  final int orderedAfterReminder;
  final double recoveryRate;
  final double? cartsChange;
  final double? valueChange;
  final double? ordersChange;
  final double? rateChange;

  factory CartSummary.fromJson(Map<String, dynamic> j) {
    final c = _m(j['change']);
    return CartSummary(
      days: _i(j['days']) == 0 ? 30 : _i(j['days']),
      idleMinutes: _i(j['idle_minutes']) == 0 ? 30 : _i(j['idle_minutes']),
      carts: _i(j['carts']),
      openCarts: _i(j['open_carts']),
      pendingValue: _n(j['pending_value']) ?? 0,
      recoveredOrders: _i(j['recovered_orders']),
      recoveredValue: _n(j['recovered_value']) ?? 0,
      orderedAfterReminder: _i(j['ordered_after_reminder']),
      recoveryRate: _n(j['recovery_rate'])?.toDouble() ?? 0,
      cartsChange: _pct(c['carts']),
      valueChange: _pct(c['pending_value']),
      ordersChange: _pct(c['recovered_orders']),
      rateChange: _pct(c['recovery_rate']),
    );
  }
}

/// One row of the list — the vendor's slice of a customer's cart.
class CartRow {
  const CartRow({
    required this.id,
    required this.channel,
    required this.state,
    required this.customer,
    required this.abandonedAt,
    required this.itemCount,
    required this.value,
    this.quantity = 0,
    this.topProduct = '',
    this.topThumbnail,
    this.myReminders = 0,
    this.lastReminderAt,
  });
  final String id;
  final CartChannel channel;
  final String state;
  final String customer;
  final DateTime? abandonedAt;
  final int itemCount;
  final int quantity;
  final num value;
  final String topProduct;
  final String? topThumbnail;
  final int myReminders;
  final DateTime? lastReminderAt;

  bool get open => state == CartState.abandoned;

  /// "iPhone 15 Pro Max" or "iPhone 15 Pro Max + 2 more".
  String get productLabel =>
      itemCount > 1 ? '$topProduct + ${itemCount - 1} more' : topProduct;

  factory CartRow.fromJson(Map<String, dynamic> j) => CartRow(
        id: _s(j['id']),
        channel: CartChannel.of(_s(j['channel'])),
        state: _s(j['state']),
        customer: _s(j['customer']).isEmpty ? 'Customer' : _s(j['customer']),
        abandonedAt: _ts(j['abandoned_at']),
        itemCount: _i(j['item_count']),
        quantity: _i(j['quantity']),
        value: _n(j['value']) ?? 0,
        topProduct: _s(j['top_product']),
        topThumbnail: j['top_thumbnail'] as String?,
        myReminders: _i(j['my_reminders']),
        lastReminderAt: _ts(j['last_reminder_at']),
      );
}

class CartPage {
  const CartPage({required this.items, required this.total});
  final List<CartRow> items;
  final int total;
}

class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.thumbnail,
    this.unit,
    this.listPrice = 0,
    this.stock,
  });
  final String productId;
  final String name;
  final String? thumbnail;
  final String? unit;
  final int quantity;
  final num unitPrice;
  final num listPrice;
  final num lineTotal;

  /// Live units left; null when unknown.
  final int? stock;

  bool get lowStock => stock != null && stock! > 0 && stock! <= 5;
  bool get outOfStock => stock != null && stock! <= 0;

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        productId: _s(j['product_id']),
        name: _s(j['name']),
        thumbnail: j['thumbnail'] as String?,
        unit: j['unit'] as String?,
        quantity: _i(j['quantity']),
        unitPrice: _n(j['unit_price']) ?? 0,
        listPrice: _n(j['list_price']) ?? 0,
        lineTotal: _n(j['line_total']) ?? 0,
        stock: j['stock'] == null ? null : _i(j['stock']),
      );
}

class TimelineEntry {
  const TimelineEntry(
      {required this.kind, required this.at, this.template = ''});
  final String kind; // DETECTED | RECOVERED | CONVERTED | EXPIRED | MY_REMINDER
  final DateTime? at;
  final String template;

  factory TimelineEntry.fromJson(Map<String, dynamic> j) => TimelineEntry(
      kind: _s(j['kind']), at: _ts(j['at']), template: _s(j['template']));
}

class ReminderTemplate {
  const ReminderTemplate({
    required this.key,
    required this.label,
    required this.hint,
    required this.available,
    this.unavailableReason,
    this.title = '',
    this.body = '',
  });
  final String key;
  final String label;
  final String hint;
  final bool available;
  final String? unavailableReason;
  final String title;
  final String body;

  factory ReminderTemplate.fromJson(Map<String, dynamic> j) => ReminderTemplate(
        key: _s(j['key']),
        label: _s(j['label']),
        hint: _s(j['hint']),
        available: j['available'] != false,
        unavailableReason: j['unavailableReason'] as String?,
        title: _s(j['title']),
        body: _s(j['body']),
      );
}

/// The server's verdict on whether a reminder may be sent right now.
class ReminderRules {
  const ReminderRules({
    required this.canRemind,
    this.reason,
    this.message,
    this.nextAllowedAt,
    this.sent = 0,
    this.max = 3,
    this.templates = const [],
  });
  final bool canRemind;
  final String? reason;
  final String? message;
  final DateTime? nextAllowedAt;
  final int sent;
  final int max;
  final List<ReminderTemplate> templates;

  factory ReminderRules.fromJson(Map<String, dynamic> j) => ReminderRules(
        canRemind: j['can_remind'] == true,
        reason: j['reason'] as String?,
        message: j['message'] as String?,
        nextAllowedAt: _ts(j['next_allowed_at']),
        sent: _i(j['sent']),
        max: _i(j['max']) == 0 ? 3 : _i(j['max']),
        templates: _l(j['templates']).map(ReminderTemplate.fromJson).toList(),
      );
}

/// A one-time coupon this vendor sent for a product in the cart.
class SentCoupon {
  const SentCoupon({
    required this.id,
    required this.productName,
    required this.type,
    required this.value,
    required this.code,
    required this.status,
    this.validUntil,
  });
  final String id;
  final String productName;
  final String type; // FLAT | PERCENTAGE
  final num value;
  final String code;
  final String status; // ACTIVE | USED | EXPIRED | CANCELLED
  final DateTime? validUntil;

  bool get active => status == 'ACTIVE';
  String get label => type == 'PERCENTAGE' ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% off' : '₹${value.round()} off';

  factory SentCoupon.fromJson(Map<String, dynamic> j) => SentCoupon(
        id: _s(j['id']),
        productName: _s(j['product_name']),
        type: _s(j['discount_type']),
        value: _n(j['discount_value']) ?? 0,
        code: _s(j['code']),
        status: _s(j['status']),
        validUntil: _ts(j['valid_until']),
      );
}

/// Whether a coupon may be sent now, and the rules the server enforces.
class CouponRules {
  const CouponRules({
    required this.canSend,
    this.message,
    this.maxPercent = 50,
    this.maxFlatShare = 0.5,
    this.validDays = const [1, 3, 7],
    this.maxPerCart = 3,
  });
  final bool canSend;
  final String? message;
  final int maxPercent;
  final double maxFlatShare;
  final List<int> validDays;
  final int maxPerCart;

  factory CouponRules.fromJson(Map<String, dynamic> j) {
    final r = _m(j['rules']);
    return CouponRules(
      canSend: j['can_send'] == true,
      message: j['message'] as String?,
      maxPercent: _i(r['max_percent']) == 0 ? 50 : _i(r['max_percent']),
      maxFlatShare: (_n(r['max_flat_share_of_line']) ?? 0.5).toDouble(),
      validDays: [for (final v in (r['valid_days'] as List? ?? const [1, 3, 7])) _i(v)],
      maxPerCart: _i(r['max_per_cart']) == 0 ? 3 : _i(r['max_per_cart']),
    );
  }
}

class CartDetail {
  const CartDetail({
    required this.id,
    required this.channel,
    required this.state,
    required this.customer,
    required this.abandonedAt,
    required this.total,
    required this.items,
    required this.timeline,
    required this.reminder,
    this.coupons = const [],
    this.couponRules = const CouponRules(canSend: false),
  });
  final String id;
  final CartChannel channel;
  final String state;
  final String customer;
  final DateTime? abandonedAt;
  final num total;
  final List<CartLine> items;
  final List<TimelineEntry> timeline;
  final ReminderRules reminder;
  final List<SentCoupon> coupons;
  final CouponRules couponRules;

  bool get open => state == CartState.abandoned;

  factory CartDetail.fromJson(Map<String, dynamic> j) => CartDetail(
        id: _s(j['id']),
        channel: CartChannel.of(_s(j['channel'])),
        state: _s(j['state']),
        customer: _s(j['customer']).isEmpty ? 'Customer' : _s(j['customer']),
        abandonedAt: _ts(j['abandoned_at']),
        total: _n(j['total']) ?? 0,
        items: _l(j['items']).map(CartLine.fromJson).toList(),
        timeline: _l(j['timeline']).map(TimelineEntry.fromJson).toList(),
        reminder: ReminderRules.fromJson(_m(j['reminder'])),
        coupons: _l(j['coupons']).map(SentCoupon.fromJson).toList(),
        couponRules: CouponRules.fromJson(_m(j['coupon'])),
      );
}

/// What the customer would receive, for the chosen template + products.
class ReminderPreview {
  const ReminderPreview(
      {required this.title, required this.body, this.productCount = 0});
  final String title;
  final String body;
  final int productCount;

  factory ReminderPreview.fromJson(Map<String, dynamic> j) => ReminderPreview(
      title: _s(j['title']),
      body: _s(j['body']),
      productCount: _i(j['product_count']));
}

/// Query for the list screen.
class CartQuery {
  const CartQuery({this.channel = CartChannel.all, this.openOnly = true});
  final CartChannel channel;

  /// true → carts still waiting; false → every state (including ordered).
  final bool openOnly;

  @override
  bool operator ==(Object other) =>
      other is CartQuery &&
      other.channel == channel &&
      other.openOnly == openOnly;
  @override
  int get hashCode => Object.hash(channel, openOnly);
}
