import 'dart:convert';

// Models for the vendor order inbox (/manage/orders) and the two detail views.
// Parsing is defensive so a missing field never crashes a screen.

num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
String _s(dynamic v) => v == null ? '' : '$v';
DateTime? _d(dynamic v) => DateTime.tryParse(_s(v))?.toLocal();

enum OrderKind {
  product('PRODUCT', 'Product'),
  auction('AUCTION', 'Auction'),
  repair('REPAIR', 'Repair');

  const OrderKind(this.api, this.label);
  final String api;
  final String label;
  static OrderKind parse(String? v) =>
      values.firstWhere((k) => k.api == v, orElse: () => OrderKind.product);
}

/// The one button a row offers (confirm, pack, ship, receive device, …).
class NextAction {
  const NextAction(this.key, this.label, {this.dashboard = false});
  final String key;
  final String label;

  /// Needs the web dashboard (estimates, payments) — the app only explains.
  final bool dashboard;

  static NextAction? from(dynamic j) => j is Map
      ? NextAction('${j['key']}', '${j['label']}',
          dashboard: j['dashboard'] == true)
      : null;
}

class OrderRow {
  const OrderRow({
    required this.kind,
    required this.id,
    required this.number,
    required this.status,
    required this.stage,
    required this.title,
    required this.quantity,
    required this.customer,
    required this.amount,
    required this.payable,
    required this.paymentStatus,
    required this.awaitingPayment,
    required this.createdAt,
    this.thumbnail,
    this.channel,
    this.refId,
    this.next,
  });
  final OrderKind kind;
  final String id;
  final String number;
  final String status;
  final String stage; // NEW | ACTIVE | SHIPPED | DONE | CANCELLED
  final String title;
  final int quantity;
  final String customer;
  final num amount;
  final num payable;
  final String paymentStatus;
  final bool awaitingPayment;
  final DateTime? createdAt;
  final String? thumbnail;
  final String? channel;
  final String? refId; // auction id for AUCTION rows
  final NextAction? next;

  factory OrderRow.fromJson(Map<String, dynamic> j) => OrderRow(
        kind: OrderKind.parse(_s(j['kind'])),
        id: _s(j['id']),
        number: _s(j['number']),
        status: _s(j['status']),
        stage: _s(j['stage']),
        title: _s(j['title']).isEmpty ? 'Order' : _s(j['title']),
        quantity: _n(j['quantity'])?.toInt() ?? 1,
        customer: _s(j['customer']),
        amount: _n(j['amount']) ?? 0,
        payable: _n(j['payable']) ?? 0,
        paymentStatus: _s(j['payment_status']),
        awaitingPayment: j['awaiting_payment'] == true,
        createdAt: _d(j['created_at']),
        thumbnail: _s(j['thumbnail']).isEmpty ? null : _s(j['thumbnail']),
        channel: _s(j['channel']).isEmpty ? null : _s(j['channel']),
        refId: _s(j['ref_id']).isEmpty ? null : _s(j['ref_id']),
        next: NextAction.from(j['next_action']),
      );
}

/// What the Orders screen asks for. Value-equal so it can key a provider.
class OrdersQuery {
  const OrdersQuery({this.type = 'all', this.tab = 'all', this.q = ''});
  final String type; // all | product | auction | repair
  final String tab; // all | new | active | shipped | done | cancelled
  final String q;

  OrdersQuery copyWith({String? type, String? tab, String? q}) => OrdersQuery(
      type: type ?? this.type, tab: tab ?? this.tab, q: q ?? this.q);

  @override
  bool operator ==(Object other) =>
      other is OrdersQuery &&
      other.type == type &&
      other.tab == tab &&
      other.q == q;

  @override
  int get hashCode => Object.hash(type, tab, q);
}

class OrdersPage {
  const OrdersPage(
      {required this.rows,
      required this.counts,
      required this.types,
      required this.total});
  final List<OrderRow> rows;

  /// all / new / active / shipped / done / cancelled — tab badges.
  final Map<String, int> counts;

  /// all / product / auction / repair — type badges.
  final Map<String, int> types;
  final int total;

  int get needsAction => counts['new'] ?? 0;
}

class OrderItemLine {
  const OrderItemLine(this.name, this.quantity, this.unitPrice, this.subtotal,
      {this.image});
  final String? image;
  final String name;
  final num quantity;
  final num unitPrice;
  final num subtotal;
}

/// Full seller order (product or auction): buyer, address, money, items, shipment.
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.number,
    required this.parentNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.buyer,
    required this.phone,
    required this.address,
    required this.items,
    required this.subtotal,
    required this.commission,
    required this.shipping,
    required this.payable,
    required this.createdAt,
    this.courier,
    this.awb,
    this.cancelReason,
    this.invoiceNumber,
    this.invoiceUploadedAt,
  });
  /// Set once the seller has uploaded their invoice — required before packing.
  final String? invoiceNumber;
  final DateTime? invoiceUploadedAt;
  bool get hasInvoice => invoiceUploadedAt != null;
  final String id;
  final String number;
  final String parentNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String buyer;
  final String phone;
  final String address;
  final List<OrderItemLine> items;
  final num subtotal;
  final num commission;
  final num shipping;
  final num payable;
  final DateTime? createdAt;
  final String? courier;
  final String? awb;
  final String? cancelReason;

  bool get paid => paymentStatus.toUpperCase() == 'PAID';
  bool get cod => paymentMethod.toUpperCase() == 'COD';
  bool get canAct => paid || cod;

  factory OrderDetail.fromJson(Map<String, dynamic> j) {
    var a = j['delivery_address'];
    if (a is String) {
      try {
        a = jsonDecode(a);
      } catch (_) {}
    }
    final m = a is Map ? a.cast<String, dynamic>() : const <String, dynamic>{};
    String pick(List<String> keys) => keys
        .map((k) => _s(m[k]).trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final sh = j['shipment'] is Map
        ? (j['shipment'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return OrderDetail(
      id: _s(j['id']),
      number: _s(j['seller_order_number']),
      parentNumber: _s(j['parent_order_number']),
      status: _s(j['status']),
      paymentMethod: _s(j['payment_method']),
      paymentStatus: _s(j['payment_status']),
      buyer: pick(['name', 'full_name', 'contact_name']),
      phone: pick(['phone', 'mobile', 'contact_phone']),
      address: [
        pick(['address_line1', 'addressLine1', 'line1']),
        pick(['address_line2', 'addressLine2', 'line2']),
        pick(['landmark']),
        pick(['city']),
        pick(['state']),
        pick(['pincode', 'postal_code']),
      ].where((e) => e.isNotEmpty).join(', '),
      items: [
        for (final i in (j['items'] as List? ?? const []))
          if (i is Map)
            OrderItemLine(_s(i['product_name']), _n(i['quantity']) ?? 1,
                _n(i['unit_price']) ?? 0, _n(i['subtotal']) ?? 0,
                image: _s(i['thumbnail']).isNotEmpty
                    ? _s(i['thumbnail'])
                    : (_s(i['thumbnail_url']).isNotEmpty
                        ? _s(i['thumbnail_url'])
                        : null))
      ],
      subtotal: _n(j['item_subtotal']) ?? 0,
      commission: _n(j['commission_amount']) ?? 0,
      shipping: _n(j['shipping_charge']) ?? 0,
      payable: _n(j['payable_to_seller']) ?? 0,
      createdAt: _d(j['created_at']),
      courier: _s(sh['courier_name']).isEmpty ? null : _s(sh['courier_name']),
      awb: _s(sh['awb']).isEmpty ? null : _s(sh['awb']),
      cancelReason: _s(j['cancellation_reason']).isEmpty
          ? null
          : _s(j['cancellation_reason']),
      invoiceNumber: j['invoice'] is Map && _s((j['invoice'] as Map)['number']).isNotEmpty
          ? _s((j['invoice'] as Map)['number'])
          : null,
      invoiceUploadedAt:
          j['invoice'] is Map ? _d((j['invoice'] as Map)['uploadedAt']) : null,
    );
  }
}

class RepairDevice {
  const RepairDevice(this.id, this.name, this.problem, this.status, this.imei);
  final String id;
  final String name;
  final String problem;
  final String status;
  final String imei;
}

/// A repair job assigned to this service centre.
class RepairDetail {
  const RepairDetail({
    required this.id,
    required this.code,
    required this.status,
    required this.customer,
    required this.phone,
    required this.description,
    required this.devices,
    required this.approvedTotal,
    required this.amountPaid,
    required this.vendorPayable,
    required this.address,
    required this.mode,
  });
  final String id;
  final String code;
  final String status;
  final String customer;
  final String phone;
  final String description;
  final List<RepairDevice> devices;
  final num approvedTotal;
  final num amountPaid;
  final num? vendorPayable;
  final String address;
  final String mode;

  num get due =>
      (approvedTotal - amountPaid) < 0 ? 0 : approvedTotal - amountPaid;

  factory RepairDetail.fromJson(Map<String, dynamic> j) {
    final cust = j['customer'] is Map
        ? (j['customer'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final settle = j['settlement'] is Map ? j['settlement'] as Map : null;
    final money = j['money'] is Map
        ? (j['money'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    String first(List<dynamic> v) =>
        v.map(_s).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    return RepairDetail(
      id: _s(j['id']),
      code: _s(j['code']),
      status: _s(j['status']),
      customer: first([j['customerName'], cust['name'], j['customer_name']]),
      phone: first([j['customerPhone'], cust['phone'], j['customer_phone']]),
      description: _s(j['description']),
      devices: [
        for (final i in (j['items'] as List? ?? const []))
          if (i is Map)
            RepairDevice(
                _s(i['id']),
                '${_s(i['brand'])} ${_s(i['model'])}'.trim(),
                first([i['problemDescription'], i['problemCategory']]),
                first([i['itemStatus'], i['status']]),
                _s(i['imeiSerial'])),
      ],
      approvedTotal: _n(money['approvedTotal']) ?? 0,
      amountPaid: _n(money['amountPaid']) ?? 0,
      vendorPayable: settle == null ? null : _n(settle['vendorPayable']),
      address: first([j['pickupAddress'], j['pickup_address']]),
      mode: _s(j['serviceMode']),
    );
  }
}
