import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/data/demand_repository.dart';

const _img = 'https://api.dealker.agnixstudio.in/uploads/products';
const _me = 'me';

/// DEMO ONLY (`.env` DEMO_HOME=true) — an in-memory marketplace that behaves like the server
/// (matching, sealed offers, award, wallet-funded escrow, pickup/courier, receipt, refunds) so the
/// whole Demand flow can be reviewed without a vendor login. Delete with the switch in
/// `demand_providers.dart`.
class DemoDemandRepository extends DemandRepository {
  DemoDemandRepository({double wallet = 900000})
      : _wallet = wallet,
        super(Dio()) {
    _seed();
  }

  final _reqs = <Map<String, dynamic>>[];
  final _quotes = <Map<String, dynamic>>[];
  final _orders = <Map<String, dynamic>>[];
  final _events = <Map<String, dynamic>>[];
  final _seen = <String>{};
  final _dismissed = <String>{};
  double _wallet;
  int _seq = 1300;
  int _qSeq = 0;

  /// What "I" (DMobileMart) have on the shelf.
  final _stock = <Map<String, dynamic>>[
    {
      'id': 'l-ip15',
      'name': 'Apple iPhone 15 (128GB, Blue)',
      'brand': 'Apple',
      'condition': 'NEW',
      'battery_health': null,
      'storage': '128GB',
      'stock': 6,
      'price': 64999.0,
      'wholesale_price': 58900.0,
      'sell_b2b': true,
      'min_order_qty': 2,
      'thumbnail_url': '$_img/apple-iphone-15-128gb-blue.jpg',
      'model': 'iphone 15',
    },
    {
      'id': 'l-s24',
      'name': 'Samsung Galaxy S24 Ultra 5G (12GB/256GB, Titanium Gray)',
      'brand': 'Samsung',
      'condition': 'REFURBISHED',
      'battery_health': 94,
      'storage': '256GB',
      'stock': 3,
      'price': 99999.0,
      'wholesale_price': 93500.0,
      'sell_b2b': true,
      'min_order_qty': 1,
      'thumbnail_url':
          '$_img/samsung-galaxy-s24-ultra-5g-12gb-256gb-titanium-gray.jpg',
      'model': 'galaxy s24 ultra',
    },
    {
      'id': 'l-ip15p',
      'name': 'Apple iPhone 15 Pro (512GB, Natural Titanium)',
      'brand': 'Apple',
      'condition': 'NEW',
      'battery_health': null,
      'storage': '512GB',
      'stock': 2,
      'price': 149999.0,
      'wholesale_price': 139000.0,
      'sell_b2b': true,
      'min_order_qty': 1,
      'thumbnail_url': '$_img/apple-iphone-15-pro-256gb-natural-titanium.jpg',
      'model': 'iphone 15 pro',
    },
  ];

  String _at(int minutesAgo) => DateTime.now()
      .toUtc()
      .subtract(Duration(minutes: minutesAgo))
      .toIso8601String();
  String _in(int hours) =>
      DateTime.now().toUtc().add(Duration(hours: hours)).toIso8601String();

  Map<String, dynamic> _req({
    required String id,
    required String product,
    required String model,
    required int qty,
    required double lo,
    required double hi,
    required String buyer,
    required String thumb,
    String? storage,
    String brand = '',
    String cond = 'ANY',
    int? battery,
    String display = 'ANY',
    String fulfil = 'ANY',
    bool urgent = false,
    String city = 'Delhi NCR',
    int ago = 30,
    String status = 'OPEN',
    String? note,
    String buyerId = 'x',
    int awarded = 0,
  }) =>
      {
        'id': id,
        'requirement_number': 'B2B-${1000 + _reqs.length}',
        'title': '$qty × $product',
        'product_name': product,
        'brand': brand,
        'storage': storage,
        'quantity_needed': qty,
        'quantity_awarded': awarded,
        'target_price': lo,
        'target_price_max': hi,
        'condition_pref': cond,
        'min_battery_health': battery,
        'display_pref': display,
        'fulfilment_pref': fulfil,
        'is_urgent': urgent,
        'description': note,
        'delivery_city': city,
        'delivery_pincode': '110001',
        'response_deadline': _in(46),
        'required_by': null,
        'status': status,
        'created_at': _at(ago),
        'buyer_name': buyer,
        'buyer_vendor_id': buyerId,
        'thumbnail_url': thumb,
        'model': model,
      };

  Map<String, dynamic> _quote(
          String req, String seller, String sellerId, int qty, double price,
          {String status = 'SUBMITTED',
          bool viewed = false,
          double? rating,
          String city = 'Delhi',
          int days = 2,
          int awarded = 0,
          String cond = 'NEW',
          int ago = 60,
          String? note,
          int completed = 0}) =>
      {
        'id': 'q-${++_qSeq}',
        'requirement_id': req,
        'seller_vendor_id': sellerId,
        'seller_name': seller,
        'seller_rating': rating,
        'seller_city': city,
        'seller_completed_orders': completed,
        'quantity_offered': qty,
        'quantity_awarded': awarded,
        'unit_price': price,
        'condition': cond,
        'delivery_days': days,
        'note': note,
        'status': status,
        'buyer_viewed_at': viewed ? _at(ago - 5) : null,
        'created_at': _at(ago),
        'updated_at': _at(ago),
      };

  void _seed() {
    const ip15 = '$_img/apple-iphone-15-128gb-blue.jpg';
    _reqs.addAll([
      _req(
          id: 'r1',
          product: 'iPhone 15 128GB',
          model: 'iphone 15',
          storage: '128GB',
          brand: 'Apple',
          qty: 50,
          lo: 58000,
          hi: 60000,
          buyer: 'Sharma Mobile',
          thumb: ip15,
          urgent: true,
          ago: 18,
          note:
              'Sealed boxes only, GST invoice required. Can take delivery in two lots.'),
      _req(
          id: 'r2',
          product: 'iPhone 16 128GB',
          model: 'iphone 16',
          storage: '128GB',
          brand: 'Apple',
          qty: 20,
          lo: 66000,
          hi: 68000,
          buyer: 'RK Mobiles',
          thumb: '$_img/apple-iphone-16-128gb-black.jpg',
          cond: 'NEW',
          city: 'Noida',
          ago: 25),
      _req(
          id: 'r3',
          product: 'Galaxy S24 Ultra 256GB',
          model: 'galaxy s24 ultra',
          storage: '256GB',
          brand: 'Samsung',
          qty: 10,
          lo: 92000,
          hi: 95000,
          buyer: 'Galaxy Store',
          thumb:
              '$_img/samsung-galaxy-s24-ultra-5g-12gb-256gb-titanium-gray.jpg',
          cond: 'USED_OR_REFURBISHED',
          battery: 90,
          city: 'Gurgaon',
          ago: 32,
          fulfil: 'PICKUP',
          note: 'Good working condition. Box preferred but not mandatory.'),
      _req(
          id: 'r4',
          product: 'OnePlus 12 256GB',
          model: 'oneplus 12',
          storage: '256GB',
          brand: 'OnePlus',
          qty: 30,
          lo: 52000,
          hi: 54000,
          buyer: 'Mobile World',
          thumb: '$_img/oneplus-12-5g-12gb-256gb-silky-black.jpg',
          city: 'Delhi NCR',
          ago: 45),
      _req(
          id: 'r5',
          product: 'iPhone 15 Pro 256GB',
          model: 'iphone 15 pro',
          storage: '256GB',
          brand: 'Apple',
          qty: 40,
          lo: 102000,
          hi: 105000,
          buyer: 'S1 Phones',
          thumb: '$_img/apple-iphone-15-pro-256gb-natural-titanium.jpg',
          battery: 90,
          display: 'ORIGINAL',
          urgent: true,
          city: 'Gurgaon',
          ago: 62),
      // ── demand I already answered ──
      _req(
          id: 'r6',
          product: 'Pixel 8a 128GB',
          model: 'pixel 8a',
          storage: '128GB',
          brand: 'Google',
          qty: 12,
          lo: 36000,
          hi: 38000,
          buyer: 'Mobile World',
          thumb: '$_img/google-pixel-8a-8gb-128gb-obsidian.jpg',
          ago: 190),
      _req(
          id: 'r7',
          product: 'Redmi Note 13 Pro+ 256GB',
          model: 'redmi note 13 pro plus',
          storage: '256GB',
          brand: 'Xiaomi',
          qty: 25,
          lo: 24000,
          hi: 25500,
          buyer: 'RK Mobiles',
          thumb: '$_img/redmi-note-13-pro-5g-8gb-256gb-fusion-purple.jpg',
          ago: 140),
      _req(
          id: 'r8',
          product: 'Galaxy A55 128GB',
          model: 'galaxy a55',
          storage: '128GB',
          brand: 'Samsung',
          qty: 15,
          lo: 26500,
          hi: 27500,
          buyer: 'Sharma Mobile',
          thumb: '$_img/samsung-galaxy-a55-5g-8gb-128gb-awesome-navy.jpg',
          ago: 600,
          status: 'IN_FULFILMENT',
          awarded: 15),
      _req(
          id: 'r9',
          product: 'Xiaomi 14 Civi 256GB',
          model: 'xiaomi 14 civi',
          storage: '256GB',
          brand: 'Xiaomi',
          qty: 10,
          lo: 38000,
          hi: 40000,
          buyer: 'Galaxy Store',
          thumb: '$_img/xiaomi-14-civi-5g-8gb-256gb-shadow-black.jpg',
          ago: 2400,
          status: 'AWARDED',
          awarded: 10),
      // ── my own requests (I am the buyer) ──
      _req(
          id: 'm1',
          product: 'iPhone 16 128GB',
          model: 'iphone 16',
          storage: '128GB',
          brand: 'Apple',
          qty: 20,
          lo: 66000,
          hi: 68000,
          buyer: 'DMobileMart',
          buyerId: _me,
          thumb: '$_img/apple-iphone-16-128gb-black.jpg',
          cond: 'NEW',
          ago: 240,
          urgent: true,
          awarded: 6,
          note: 'Need sealed pieces for a festive offer.'),
      _req(
          id: 'm2',
          product: 'OnePlus 12 256GB',
          model: 'oneplus 12',
          storage: '256GB',
          brand: 'OnePlus',
          qty: 10,
          lo: 52000,
          hi: 54000,
          buyer: 'DMobileMart',
          buyerId: _me,
          thumb: '$_img/oneplus-12-5g-12gb-256gb-silky-black.jpg',
          ago: 800,
          status: 'AWARDED',
          awarded: 10),
    ]);
    _seen.add('r5');
    _quotes.addAll([
      _quote('r6', 'DMobileMart', _me, 6, 37500, viewed: true, ago: 120),
      _quote('r7', 'DMobileMart', _me, 8, 24800, ago: 90),
      _quote('r8', 'DMobileMart', _me, 15, 27200,
          status: 'SELECTED', awarded: 15, viewed: true, ago: 500),
      _quote('r9', 'DMobileMart', _me, 10, 39800,
          status: 'NOT_SELECTED', viewed: true, ago: 2200),
      _quote('m1', 'Sharma Mobile', 's1', 6, 67000,
          status: 'SELECTED',
          awarded: 6,
          rating: 4.8,
          city: 'Delhi',
          days: 2,
          ago: 200,
          completed: 41,
          note: 'Sealed, GST bill.'),
      _quote('m1', 'RK Mobiles', 's2', 5, 66800,
          rating: 4.6, city: 'Noida', days: 3, ago: 180, completed: 23),
      _quote('m1', 'Galaxy Store', 's3', 4, 67500,
          rating: 4.5, city: 'Gurgaon', days: 2, ago: 150, completed: 17),
      _quote('m1', 'Mobile World', 's4', 8, 67200,
          rating: 4.2, city: 'Delhi', days: 1, ago: 120, completed: 9),
      _quote('m1', 'S1 Phones', 's5', 6, 66500,
          rating: 4.0, city: 'Faridabad', days: 4, ago: 90, completed: 5),
      _quote('m2', 'RK Mobiles', 's2', 10, 53200,
          status: 'SELECTED',
          awarded: 10,
          rating: 4.6,
          city: 'Noida',
          ago: 700,
          completed: 23),
    ]);
    _orders.addAll([
      _order('o-sell', 'r8', _quotes[2]['id'] as String,
          buyerId: 's1',
          sellerId: _me,
          buyerName: 'Sharma Mobile',
          sellerName: 'DMobileMart',
          qty: 15,
          price: 27200,
          status: 'PAID',
          paidAgo: 300),
      _order('o-pay', 'm2', _quotes[9]['id'] as String,
          buyerId: _me,
          sellerId: 's2',
          buyerName: 'DMobileMart',
          sellerName: 'RK Mobiles',
          qty: 10,
          price: 53200,
          status: 'PENDING_PAYMENT'),
      _order('o-buy', 'm1', _quotes[4]['id'] as String,
          buyerId: _me,
          sellerId: 's1',
          buyerName: 'DMobileMart',
          sellerName: 'Sharma Mobile',
          qty: 6,
          price: 67000,
          status: 'DISPATCHED',
          paidAgo: 1500,
          courier: 'Blue Dart',
          awb: 'BD48210937',
          packedAgo: 1300,
          dispatchedAgo: 900),
    ]);
    _events.addAll([
      _ev('m1', null, 'POSTED', 'DMobileMart', 240),
      _ev('m1', 'o-buy', 'AWARDED', 'DMobileMart', 1600),
      _ev('m1', null, 'PAID', 'DMobileMart', 1500),
      _ev('m1', 'o-buy', 'PACKED', 'Sharma Mobile', 1300),
      _ev('m1', 'o-buy', 'DISPATCHED', 'Sharma Mobile', 900,
          'Blue Dart · AWB BD48210937'),
      _ev('r8', 'o-sell', 'AWARDED', 'Sharma Mobile', 520,
          '15 × from DMobileMart @ ₹27200'),
      _ev('r8', null, 'PAID', 'Sharma Mobile', 300,
          '₹4,08,000 held in escrow for 1 order(s)'),
    ]);
  }

  Map<String, dynamic> _ev(
          String req, String? order, String type, String actor, int ago,
          [String? note]) =>
      {
        'requirement_id': req,
        'order_id': order,
        'type': type,
        'actor_label': actor,
        'note': note,
        'created_at': _at(ago)
      };

  Map<String, dynamic> _order(String id, String req, String quote,
      {required String buyerId,
      required String sellerId,
      required String buyerName,
      required String sellerName,
      required int qty,
      required double price,
      required String status,
      int? paidAgo,
      String? courier,
      String? awb,
      int? packedAgo,
      int? dispatchedAgo}) {
    final sub = qty * price;
    final comm = sub * 0.10;
    return {
      'id': id,
      'order_number': 'B2BO-${++_seq}',
      'requirement_id': req,
      'quote_id': quote,
      'buyer_vendor_id': buyerId,
      'seller_vendor_id': sellerId,
      'buyer_name': buyerName,
      'seller_name': sellerName,
      'quantity': qty,
      'unit_price': price,
      'subtotal': sub,
      'commission_percent': 10,
      'commission_amount': comm,
      'seller_payable': sub - comm,
      'status': status,
      'payment_status': status == 'PENDING_PAYMENT' ? 'UNPAID' : 'ESCROW_HELD',
      'courier_name': courier,
      'awb': awb,
      'tracking_url': awb == null ? null : 'https://track.example/$awb',
      'fulfilment_type': 'DELIVERY',
      'payment_method': paidAgo == null ? null : 'WALLET',
      'created_at': _at((paidAgo ?? 30) + 60),
      'paid_at': paidAgo == null ? null : _at(paidAgo),
      'packed_at': packedAgo == null ? null : _at(packedAgo),
      // demo sellers have already attached their invoice, so packing is not blocked
      'invoice_uploaded_at': paidAgo == null ? null : _at(paidAgo),
      'dispatched_at': dispatchedAgo == null ? null : _at(dispatchedAgo),
    };
  }

  // ── helpers ──────────────────────────────────────────────────────────

  Map<String, dynamic> _requirementRow(String id) =>
      _reqs.firstWhere((r) => r['id'] == id);

  Map<String, dynamic>? _myQuote(String reqId) {
    for (final q in _quotes) {
      if (q['requirement_id'] == reqId && q['seller_vendor_id'] == _me) {
        return q;
      }
    }
    return null;
  }

  String? _offerState(Map<String, dynamic>? q) {
    if (q == null) return null;
    return switch (q['status']) {
      'SELECTED' => OfferState.accepted,
      'PARTIALLY_SELECTED' => OfferState.partial,
      'SUBMITTED' =>
        q['buyer_viewed_at'] != null ? OfferState.viewed : OfferState.pending,
      final s => '$s',
    };
  }

  /// Same idea as the server matcher: same model → EXACT (or CLOSE when storage differs).
  ({String? level, int stock, List<Map<String, dynamic>> hits}) _match(
      Map<String, dynamic> r) {
    final hits = <Map<String, dynamic>>[];
    for (final l in _stock) {
      if ((l['stock'] as int) <= 0 || l['model'] != r['model']) continue;
      final sameStorage = l['storage'] == r['storage'];
      final cond = r['condition_pref'];
      final isNew = l['condition'] == 'NEW' || l['condition'] == 'OPEN_BOX';
      if ((cond == 'NEW' && !isNew) ||
          (cond == 'USED_OR_REFURBISHED' && isNew)) {
        continue;
      }
      final bat = r['min_battery_health'] as int?;
      final weak = bat != null &&
          l['battery_health'] != null &&
          (l['battery_health'] as int) < bat;
      hits.add({...l, 'level': sameStorage && !weak ? 'EXACT' : 'CLOSE'});
    }
    final exact = hits.where((h) => h['level'] == 'EXACT');
    return (
      level: exact.isNotEmpty ? 'EXACT' : (hits.isNotEmpty ? 'CLOSE' : null),
      stock: exact.fold<int>(0, (s, h) => s + (h['stock'] as int)),
      hits: hits
    );
  }

  List<String> _tags(Map<String, dynamic> r) => [
        if (r['is_urgent'] == true) 'URGENT',
        if ((r['quantity_needed'] as int) >= 20) 'BULK',
      ];

  Map<String, dynamic> _card(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final mine = r['buyer_vendor_id'] == _me;
    final quote = _myQuote(id);
    final m = _match(r);
    final active = _quotes
        .where((q) => q['requirement_id'] == id && q['status'] != 'WITHDRAWN')
        .toList();
    return {
      ...r,
      'tags': _tags(r),
      'viewed': _seen.contains(id),
      'my_quote':
          quote == null ? null : {...quote, 'offer_state': _offerState(quote)},
      'offer_state': _offerState(quote),
      'my_match': mine
          ? null
          : {
              'level': m.level,
              'stock': m.stock,
              'listing_id': m.hits.isEmpty ? null : m.hits.first['id']
            },
      'my_orders': _orders
          .where((o) =>
              o['requirement_id'] == id &&
              o['seller_vendor_id'] == _me &&
              o['status'] != 'CANCELLED')
          .toList(),
      if (mine) ...{
        'quote_count': active.length,
        'best_price': active.isEmpty
            ? null
            : active
                .map((q) => q['unit_price'] as double)
                .reduce((a, b) => a < b ? a : b),
        'quantity_offered_total':
            active.fold<int>(0, (s, q) => s + (q['quantity_offered'] as int)),
      },
    };
  }

  bool _openForMe(Map<String, dynamic> r) =>
      r['status'] == 'OPEN' &&
      r['buyer_vendor_id'] != _me &&
      (r['quantity_awarded'] as int) < (r['quantity_needed'] as int);

  void _event(String req, String? order, String type, String actor,
          [String? note]) =>
      _events.add(_ev(req, order, type, actor, 0, note));

  Failure _err(String m) => ServerFailure(message: m);

  // ── API ──────────────────────────────────────────────────────────────

  @override
  Future<DemandSummary> summary() async {
    final open = _reqs
        .where((r) => _openForMe(r) && !_dismissed.contains(r['id']))
        .toList();
    final offers = _quotes.where((q) => q['seller_vendor_id'] == _me).toList();
    bool live(Map<String, dynamic> q) {
      final r = _requirementRow(q['requirement_id'] as String);
      return (q['status'] == 'SUBMITTED' && r['status'] == 'OPEN') ||
          (['SELECTED', 'PARTIALLY_SELECTED'].contains(q['status']) &&
              !['COMPLETED', 'CANCELLED'].contains(r['status']));
    }

    bool pending(Map<String, dynamic> q) =>
        q['status'] == 'SUBMITTED' &&
        _requirementRow(q['requirement_id'] as String)['status'] == 'OPEN';
    final mine = _reqs.where((r) => r['buyer_vendor_id'] == _me).toList();
    bool buying(Map<String, dynamic> o) => o['buyer_vendor_id'] == _me;
    bool selling(Map<String, dynamic> o) => o['seller_vendor_id'] == _me;
    bool act(Map<String, dynamic> o) =>
        OrderStatus.active.contains(o['status']);
    return DemandSummary(
      open: open.length,
      newCount: open
          .where((r) =>
              !_seen.contains(r['id']) && _myQuote(r['id'] as String) == null)
          .length,
      matched: open
          .where((r) =>
              _myQuote(r['id'] as String) == null && _match(r).level == 'EXACT')
          .length,
      urgent: open.where((r) => r['is_urgent'] == true).length,
      offers: OfferCounts(
        active: offers.where(live).length,
        pending: offers.where(pending).length,
        closed: offers.where((q) => !live(q)).length,
        accepted: offers
            .where((q) =>
                ['SELECTED', 'PARTIALLY_SELECTED'].contains(q['status']) &&
                live(q))
            .length,
      ),
      myOpen: mine.where((r) => r['status'] == 'OPEN').length,
      myTotal: mine.length,
      offersWaiting: mine.where((r) => r['status'] == 'OPEN').fold<int>(
          0,
          (s, r) =>
              s +
              _quotes
                  .where((q) =>
                      q['requirement_id'] == r['id'] &&
                      q['status'] == 'SUBMITTED')
                  .length),
      toPay: _orders
          .where((o) => buying(o) && o['status'] == 'PENDING_PAYMENT')
          .length,
      toReceive: _orders
          .where((o) =>
              buying(o) && ['DISPATCHED', 'DELIVERED'].contains(o['status']))
          .length,
      buyingActive: _orders.where((o) => buying(o) && act(o)).length,
      toDispatch: _orders
          .where((o) => selling(o) && ['PAID', 'PACKED'].contains(o['status']))
          .length,
      sellingActive: _orders.where((o) => selling(o) && act(o)).length,
    );
  }

  @override
  Future<RequirementPage> requirements({
    String scope = 'open',
    String? tab,
    String search = '',
    int page = 1,
    int limit = 30,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    Iterable<Map<String, dynamic>> rows;
    switch (scope) {
      case 'mine':
        rows = _reqs.where((r) => r['buyer_vendor_id'] == _me);
      case 'quoted':
        rows = _reqs.where((r) {
          final q = _myQuote(r['id'] as String);
          if (q == null) return false;
          final open = r['status'] == 'OPEN';
          final liveOffer = (q['status'] == 'SUBMITTED' && open) ||
              (['SELECTED', 'PARTIALLY_SELECTED'].contains(q['status']) &&
                  !['COMPLETED', 'CANCELLED'].contains(r['status']));
          final pending = q['status'] == 'SUBMITTED' && open;
          return switch (tab) {
            'pending' => pending,
            'active' => liveOffer,
            'closed' => !liveOffer,
            _ => true
          };
        });
      default:
        rows =
            _reqs.where((r) => _openForMe(r) && !_dismissed.contains(r['id']));
        if (scope == 'new') {
          rows = rows.where((r) =>
              !_seen.contains(r['id']) && _myQuote(r['id'] as String) == null);
        }
        if (scope == 'matched') {
          rows = rows.where((r) =>
              _myQuote(r['id'] as String) == null &&
              _match(r).level == 'EXACT');
        }
    }
    final q = search.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows =
          rows.where((r) => '${r['product_name']}'.toLowerCase().contains(q));
    }
    final list = rows.toList()
      ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return RequirementPage(
        items: list.map((r) => Requirement.fromJson(_card(r))).toList(),
        total: list.length);
  }

  @override
  Future<RequirementDetail> detail(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final r = _requirementRow(id);
    final mine = r['buyer_vendor_id'] == _me;
    if (mine) {
      for (final q in _quotes) {
        if (q['requirement_id'] == id &&
            q['buyer_viewed_at'] == null &&
            q['status'] != 'WITHDRAWN') {
          q['buyer_viewed_at'] = _at(0);
        }
      }
    } else {
      _seen.add(id);
    }
    final quotes = _quotes
        .where((q) =>
            q['requirement_id'] == id && (mine || q['seller_vendor_id'] == _me))
        .map((q) => {...q, 'offer_state': _offerState(q)})
        .toList()
      ..sort((a, b) =>
          (a['unit_price'] as double).compareTo(b['unit_price'] as double));
    final orders = _orders
        .where((o) =>
            o['requirement_id'] == id && (mine || o['seller_vendor_id'] == _me))
        .toList();
    final mq = _myQuote(id);
    final paid = orders.where((o) => o['payment_status'] != 'UNPAID').toList();
    return RequirementDetail.fromJson({
      'requirement': _card(r),
      'quotes': quotes,
      'orders': orders,
      'events': mine
          ? _events.where((e) => e['requirement_id'] == id).toList()
          : const [],
      'payment': mine && paid.isNotEmpty
          ? {
              'amount':
                  paid.fold<double>(0, (s, o) => s + (o['subtotal'] as double)),
              'method': 'WALLET',
              'status': 'HELD',
              'paid_at': paid.first['paid_at']
            }
          : null,
      'viewer': {
        'isBuyer': mine,
        'isAdmin': false,
        'myQuoteId': mine ? null : mq?['id']
      },
    });
  }

  @override
  Future<MatchResult> match(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final r = _requirementRow(id);
    final m = _match(r);
    final remaining =
        (r['quantity_needed'] as int) - (r['quantity_awarded'] as int);
    final exact = m.hits.where((h) => h['level'] == 'EXACT').toList();
    final lead =
        exact.isNotEmpty ? exact.first : (m.hits.isEmpty ? null : m.hits.first);
    final mq = _myQuote(id);
    return MatchResult.fromJson({
      'level': m.level,
      'totalStock': m.stock,
      'canSupply': m.stock < remaining ? m.stock : remaining,
      'remaining': remaining,
      'listings': [
        for (final h in m.hits)
          {
            ...h,
            'suggested_price': h['wholesale_price'] ?? h['price'],
            'reasons': h['level'] == 'EXACT'
                ? ['Model matches', '${h['storage']} storage']
                : ['Storage is ${h['storage']} (buyer wants ${r['storage']})']
          },
      ],
      'suggested': lead == null
          ? null
          : {
              'listingId': lead['id'],
              'unitPrice': lead['wholesale_price'] ?? lead['price'],
              'quantity': (lead['stock'] as int) < remaining
                  ? lead['stock']
                  : remaining,
              'condition': lead['condition'],
            },
      'commissionPercent': 10,
      'myQuote': mq == null ? null : {...mq, 'offer_state': _offerState(mq)},
    });
  }

  @override
  Future<void> dismiss(String id) async => _dismissed.add(id);

  @override
  Future<Requirement> create(Map<String, dynamic> body) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final name = '${body['productName']}';
    final id = 'm${_reqs.length + 10}';
    final key = name
        .toLowerCase()
        .replaceAll(RegExp(r'\d+\s?(gb|tb)'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final hours = DateTime.tryParse('${body['responseDeadline']}')
            ?.difference(DateTime.now())
            .inHours ??
        48;
    final row = _req(
      id: id,
      product: name,
      model: key,
      qty: body['quantity'] as int,
      lo: (body['targetPrice'] as num?)?.toDouble() ?? 0,
      hi: (body['targetPriceMax'] as num?)?.toDouble() ?? 0,
      buyer: 'DMobileMart',
      buyerId: _me,
      thumb: '',
      brand: '${body['brand'] ?? ''}',
      storage: body['storage'] as String?,
      cond: '${body['conditionPref'] ?? 'ANY'}',
      battery: body['minBatteryHealth'] as int?,
      display: '${body['displayPref'] ?? 'ANY'}',
      fulfil: '${body['fulfilmentPref'] ?? 'ANY'}',
      urgent: body['isUrgent'] == true,
      city: '${body['deliveryCity'] ?? ''}',
      ago: 0,
      note: body['description'] as String?,
    );
    row['response_deadline'] = _in(hours);
    row['target_price'] = body['targetPrice'];
    row['target_price_max'] = body['targetPriceMax'];
    _reqs.add(row);
    _event(id, null, 'POSTED', 'DMobileMart', '${body['quantity']} × $name');
    return Requirement.fromJson(_card(row));
  }

  @override
  Future<void> cancelRequirement(String id, {String? reason}) async {
    final r = _requirementRow(id);
    if (_orders.any((o) =>
        o['requirement_id'] == id &&
        !['PENDING_PAYMENT', 'CANCELLED'].contains(o['status']))) {
      throw _err(
          'Some orders are already paid — resolve them before cancelling');
    }
    for (final o in _orders.where(
        (o) => o['requirement_id'] == id && o['status'] == 'PENDING_PAYMENT')) {
      o['status'] = 'CANCELLED';
    }
    r['status'] = 'CANCELLED';
    _event(id, null, 'CANCELLED', 'DMobileMart', reason);
  }

  @override
  Future<List<DemandOrder>> award(String id, List<Selection> picks) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final r = _requirementRow(id);
    final total = picks.fold<int>(0, (s, p) => s + p.quantity);
    if ((r['quantity_awarded'] as int) + total >
        (r['quantity_needed'] as int)) {
      throw _err(
          'Only ${(r['quantity_needed'] as int) - (r['quantity_awarded'] as int)} units are still needed');
    }
    final made = <Map<String, dynamic>>[];
    for (final p in picks) {
      final q = _quotes.firstWhere((q) => q['id'] == p.quoteId);
      if (p.quantity >
          (q['quantity_offered'] as int) - (q['quantity_awarded'] as int)) {
        throw _err(
            '${q['seller_name']} only has ${(q['quantity_offered'] as int) - (q['quantity_awarded'] as int)} units left on this quote');
      }
      q['quantity_awarded'] = (q['quantity_awarded'] as int) + p.quantity;
      q['status'] = q['quantity_awarded'] >= q['quantity_offered']
          ? 'SELECTED'
          : 'PARTIALLY_SELECTED';
      final o = _order('o-${_orders.length + 1}', id, q['id'] as String,
          buyerId: _me,
          sellerId: q['seller_vendor_id'] as String,
          buyerName: 'DMobileMart',
          sellerName: q['seller_name'] as String,
          qty: p.quantity,
          price: q['unit_price'] as double,
          status: 'PENDING_PAYMENT');
      _orders.add(o);
      made.add(o);
      _event(id, o['id'] as String, 'AWARDED', 'DMobileMart',
          '${p.quantity} × from ${q['seller_name']} @ ₹${q['unit_price']}');
    }
    r['quantity_awarded'] = (r['quantity_awarded'] as int) + total;
    if ((r['quantity_awarded'] as int) >= (r['quantity_needed'] as int)) {
      r['status'] = 'AWARDED';
      for (final q in _quotes.where((q) =>
          q['requirement_id'] == id &&
          q['quantity_awarded'] == 0 &&
          q['status'] == 'SUBMITTED')) {
        q['status'] = 'NOT_SELECTED';
      }
    }
    return made.map(DemandOrder.fromJson).toList();
  }

  @override
  Future<WalletInfo> wallet() async => WalletInfo(balance: _wallet);

  @override
  Future<void> pay(String requirementId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final unpaid = _orders
        .where((o) =>
            o['requirement_id'] == requirementId &&
            o['status'] == 'PENDING_PAYMENT')
        .toList();
    if (unpaid.isEmpty) throw _err('Nothing to pay for this requirement');
    final amount =
        unpaid.fold<double>(0, (s, o) => s + (o['subtotal'] as double));
    if (_wallet < amount) {
      throw _err(
          'Not enough wallet balance — you need ₹${amount.round()} and have ₹${_wallet.round()}.');
    }
    _wallet -= amount;
    for (final o in unpaid) {
      o['status'] = 'PAID';
      o['payment_status'] = 'ESCROW_HELD';
      o['payment_method'] = 'WALLET';
      o['paid_at'] = _at(0);
    }
    final r = _requirementRow(requirementId);
    if (r['status'] == 'AWARDED') r['status'] = 'IN_FULFILMENT';
    _event(requirementId, null, 'PAID', 'DMobileMart',
        '₹${amount.round()} held in escrow for ${unpaid.length} order(s)');
  }

  @override
  Future<void> sendOffer(
      String requirementId, Map<String, dynamic> body) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final r = _requirementRow(requirementId);
    final qty = body['quantity'] as int;
    if (qty > (r['quantity_needed'] as int) - (r['quantity_awarded'] as int)) {
      throw _err(
          'You can offer at most ${(r['quantity_needed'] as int) - (r['quantity_awarded'] as int)} units');
    }
    final cur = _myQuote(requirementId);
    if (cur != null) {
      if ((cur['quantity_awarded'] as int) > 0) {
        throw _err(
            'This quote has already been selected and cannot be changed');
      }
      if (cur['unit_price'] != body['unitPrice'] ||
          cur['quantity_offered'] != qty) {
        cur['buyer_viewed_at'] = null;
      }
      cur
        ..['quantity_offered'] = qty
        ..['unit_price'] = (body['unitPrice'] as num).toDouble()
        ..['condition'] = body['condition']
        ..['delivery_days'] = body['deliveryDays']
        ..['note'] = body['note']
        ..['status'] = 'SUBMITTED';
    } else {
      _quotes.add(_quote(requirementId, 'DMobileMart', _me, qty,
          (body['unitPrice'] as num).toDouble(),
          cond: '${body['condition'] ?? 'NEW'}',
          days: (body['deliveryDays'] as int?) ?? 3,
          note: body['note'] as String?,
          ago: 0));
    }
    _dismissed.remove(requirementId);
    _event(
        requirementId,
        null,
        cur == null ? 'QUOTE_SUBMITTED' : 'QUOTE_UPDATED',
        'DMobileMart',
        '$qty @ ₹${body['unitPrice']}');
  }

  @override
  Future<void> withdrawOffer(String quoteId) async {
    final q = _quotes.firstWhere((q) => q['id'] == quoteId);
    if ((q['quantity_awarded'] as int) > 0) {
      throw _err('This quote is already selected');
    }
    q['status'] = 'WITHDRAWN';
  }

  @override
  Future<OrderPage> orders(
      {String role = 'buying', String? bucket, int limit = 40}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final key = role == 'selling' ? 'seller_vendor_id' : 'buyer_vendor_id';
    var rows = _orders.where((o) => o[key] == _me);
    if (bucket == 'active') {
      rows = rows.where((o) => OrderStatus.active.contains(o['status']));
    }
    if (bucket == 'done') {
      rows = rows.where((o) => !OrderStatus.active.contains(o['status']));
    }
    final list = rows.toList().reversed.toList();
    return OrderPage(
        items:
            list.map((o) => DemandOrder.fromJson(_withRequirement(o))).toList(),
        total: list.length);
  }

  Map<String, dynamic> _withRequirement(Map<String, dynamic> o) {
    final r = _requirementRow(o['requirement_id'] as String);
    return {
      ...o,
      'product_name': r['product_name'],
      'storage': r['storage'],
      'thumbnail_url': r['thumbnail_url']
    };
  }

  @override
  Future<OrderDetail> orderDetail(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final o = _orders.firstWhere((o) => o['id'] == id);
    final isBuyer = o['buyer_vendor_id'] == _me;
    final paid = !['PENDING_PAYMENT', 'CANCELLED'].contains(o['status']);
    final r = _requirementRow(o['requirement_id'] as String);
    return OrderDetail.fromJson({
      'order': o,
      'requirement': _card(r),
      'seller': {
        'name': o['seller_name'],
        'city': 'Noida',
        if (paid && isBuyer) ...{
          'phone': '9810012345',
          'pincode': '201301',
          'address': 'Shop 14, Sector 18'
        }
      },
      'buyer': {
        'name': o['buyer_name'],
        if (paid && !isBuyer) 'phone': '9899955500'
      },
      'payment': o['paid_at'] == null
          ? null
          : {
              'amount': o['subtotal'],
              'method': 'WALLET',
              'status': o['payment_status'] == 'RELEASED' ? 'RELEASED' : 'HELD',
              'paid_at': o['paid_at']
            },
      'events': _events
          .where((e) =>
              e['requirement_id'] == o['requirement_id'] &&
              (e['order_id'] == id ||
                  (e['order_id'] == null &&
                      ['POSTED', 'PAID'].contains(e['type']))))
          .toList(),
      'viewer': {'isBuyer': isBuyer, 'isSeller': !isBuyer, 'isAdmin': false},
    });
  }

  Map<String, dynamic> _o(String id) =>
      _orders.firstWhere((o) => o['id'] == id);

  @override
  Future<void> setOrderStatus(String id, Map<String, dynamic> body) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final o = _o(id);
    final status = '${body['status']}';
    const flow = {
      'PACKED': ['PAID'],
      'DISPATCHED': ['PAID', 'PACKED'],
      'DELIVERED': ['DISPATCHED']
    };
    if (!(flow[status] ?? const []).contains(o['status'])) {
      throw _err(o['status'] == 'PENDING_PAYMENT'
          ? 'The buyer has not paid yet — escrow must be funded before dispatch'
          : 'Cannot move from ${o['status']} to $status');
    }
    final pickup = status == 'DISPATCHED' && body['fulfilmentType'] == 'PICKUP';
    if (status == 'DISPATCHED' &&
        !pickup &&
        (body['courierName'] == null || body['awb'] == null)) {
      throw const ValidationFailure(
          message: 'Courier name and tracking number (AWB) are required');
    }
    if (pickup && body['pickupAt'] == null) {
      throw const ValidationFailure(
          message: 'Choose a pickup date and time in the future');
    }
    o['status'] = status;
    switch (status) {
      case 'PACKED':
        o['packed_at'] = _at(0);
      case 'DISPATCHED':
        o['dispatched_at'] = _at(0);
        if (pickup) {
          o
            ..['fulfilment_type'] = 'PICKUP'
            ..['pickup_at'] = body['pickupAt']
            ..['pickup_note'] = body['pickupNote'];
        } else {
          o
            ..['fulfilment_type'] = 'DELIVERY'
            ..['courier_name'] = body['courierName']
            ..['awb'] = body['awb']
            ..['tracking_url'] = body['trackingUrl'];
        }
      case 'DELIVERED':
        o['delivered_at'] = _at(0);
    }
    _event(
        o['requirement_id'] as String,
        id,
        status,
        '${o['seller_name']}',
        status == 'DISPATCHED'
            ? (pickup
                ? 'Pickup scheduled'
                : '${body['courierName']} · AWB ${body['awb']}')
            : null);
  }

  @override
  Future<void> cancelOrder(String id, String reason) async {
    final o = _o(id);
    if (!['PAID', 'PACKED'].contains(o['status'])) {
      throw _err('It is too late to cancel — the order has been dispatched');
    }
    if (o['buyer_vendor_id'] == _me) _wallet += o['subtotal'] as double;
    o
      ..['status'] = 'CANCELLED'
      ..['payment_status'] = 'REFUNDED'
      ..['cancel_reason'] = reason;
    final r = _requirementRow(o['requirement_id'] as String);
    r['quantity_awarded'] =
        (r['quantity_awarded'] as int) - (o['quantity'] as int);
    r['status'] = 'OPEN';
    _event(o['requirement_id'] as String, id, 'ORDER_CANCELLED',
        '${o['seller_name']}', reason);
  }

  @override
  Future<void> receive(String id,
      {required int quantity, required bool ok, String? note}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final o = _o(id);
    if (!['DISPATCHED', 'DELIVERED'].contains(o['status'])) {
      throw _err('This order has not been dispatched yet');
    }
    o
      ..['received_at'] = _at(0)
      ..['received_quantity'] = quantity
      ..['receipt_note'] = note;
    if (quantity == o['quantity'] && ok) {
      o
        ..['status'] = 'COMPLETED'
        ..['payment_status'] = 'RELEASED'
        ..['released_at'] = _at(0)
        ..['released_amount'] = o['seller_payable'];
      _event(
          o['requirement_id'] as String,
          id,
          'RECEIVED',
          '${o['buyer_name']}',
          'Buyer confirmed receipt — payment released to seller');
    } else {
      o
        ..['status'] = 'DISPUTED'
        ..['dispute_status'] = 'OPEN'
        ..['dispute_reason'] = note ?? 'Received $quantity of ${o['quantity']}';
      _event(
          o['requirement_id'] as String,
          id,
          'DISPUTED',
          '${o['buyer_name']}',
          note ?? 'Received $quantity of ${o['quantity']}');
    }
  }
}
