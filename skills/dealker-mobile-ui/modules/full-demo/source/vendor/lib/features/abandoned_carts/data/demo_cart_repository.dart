import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_models.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_repository.dart';

const _img = 'https://api.dealker.agnixstudio.in/uploads/products';

/// DEMO ONLY — in-memory abandoned carts so the whole list / detail / reminder
/// flow can be reviewed without a vendor login. Active only when `.env` has
/// `DEMO_HOME=true`. Delete with the switch in `cart_providers.dart`.
class DemoCartRepository extends CartRepository {
  DemoCartRepository() : super(Dio());

  static DateTime _ago(Duration d) => DateTime.now().subtract(d);

  final List<_Cart> _carts = [
    _Cart(
      id: 'c1',
      channel: CartChannel.b2b,
      customer: 'Rohit S.',
      at: _ago(const Duration(minutes: 8)),
      lines: [
        _line('iPhone 15 Pro Max (256GB)', 89900, 1,
            'apple-iphone-15-pro-256gb-natural-titanium',
            stock: 4),
      ],
    ),
    _Cart(
      id: 'c2',
      channel: CartChannel.b2c,
      customer: 'Pooja K.',
      at: _ago(const Duration(minutes: 52)),
      lines: [
        _line('Apple iPhone 14 (128GB)', 32990, 1, 'apple-iphone-15-128gb-blue',
            stock: 18),
      ],
    ),
    _Cart(
      id: 'c3',
      channel: CartChannel.b2b,
      customer: 'Amit K.',
      at: _ago(const Duration(hours: 5)),
      lines: [
        _line('Apple iPhone 15 (128GB)', 64900, 1, 'apple-iphone-15-128gb-blue',
            stock: 40),
        _line(
            'Apple iPhone 16 (128GB)', 74900, 2, 'apple-iphone-16-128gb-black',
            stock: 18),
      ],
    ),
    _Cart(
      id: 'c4',
      channel: CartChannel.b2c,
      customer: 'Sneha P.',
      at: _ago(const Duration(days: 1, hours: 3)),
      reminders: [_ago(const Duration(hours: 20))],
      lines: [
        _line('Samsung Galaxy S24 Ultra (12GB, 256GB)', 109999, 1,
            'samsung-galaxy-s24-ultra-5g-12gb-256gb-titanium-gray',
            stock: 3),
      ],
    ),
    _Cart(
      id: 'c5',
      channel: CartChannel.b2c,
      customer: 'Neha S.',
      at: _ago(const Duration(days: 2)),
      state: CartState.ordered,
      lines: [
        _line('Apple iPhone 15 (128GB)', 64900, 1, 'apple-iphone-15-128gb-blue',
            stock: 40),
      ],
    ),
  ];

  static _Line _line(String name, num price, int qty, String slug,
          {int? stock}) =>
      _Line(name, price, qty, '$_img/$slug.jpg', stock);

  Future<void> _lag([int ms = 300]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  _Cart _find(String id) => _carts.firstWhere((c) => c.id == id);

  bool _match(_Cart c, CartQuery q) =>
      (q.channel == CartChannel.all || c.channel == q.channel) &&
      (!q.openOnly || c.state == CartState.abandoned);

  @override
  Future<CartSummary> summary({CartChannel channel = CartChannel.all}) async {
    await _lag();
    final all =
        _carts.where((c) => channel == CartChannel.all || c.channel == channel);
    final open = all.where((c) => c.state == CartState.abandoned);
    final ordered = all.where((c) => c.state == CartState.ordered);
    final n = all.length;
    return CartSummary(
      carts: n,
      openCarts: open.length,
      pendingValue: open.fold<num>(0, (a, c) => a + c.total),
      recoveredOrders: ordered.length,
      recoveredValue: ordered.fold<num>(0, (a, c) => a + c.total),
      recoveryRate: n == 0 ? 0 : ordered.length / n,
      cartsChange: 18,
      valueChange: 22,
      ordersChange: 35,
      rateChange: 12,
    );
  }

  @override
  Future<CartPage> list(CartQuery q, {int limit = 50}) async {
    await _lag();
    final rows = _carts.where((c) => _match(c, q)).map((c) => c.row()).toList();
    return CartPage(items: rows, total: rows.length);
  }

  @override
  Future<CartDetail> detail(String id) async {
    await _lag(200);
    return _find(id).detail();
  }

  @override
  Future<ReminderPreview> preview(
      String id, String templateKey, List<String> productIds) async {
    await _lag(120);
    final c = _find(id);
    final lines = c.pick(productIds);
    return c.render(templateKey, lines);
  }

  @override
  Future<CartDetail> remind(
      String id, String templateKey, List<String> productIds) async {
    await _lag(600);
    final c = _find(id);
    final rules = c.rules();
    if (!rules.canRemind) {
      throw ValidationFailure(message: rules.message ?? 'Not allowed');
    }
    c.reminders.add(DateTime.now());
    return c.detail();
  }
}

class _Line {
  _Line(this.name, this.price, this.qty, this.thumb, this.stock);
  final String name;
  final num price;
  final int qty;
  final String thumb;
  final int? stock;
  String get id => 'p-${name.hashCode}';
  num get total => price * qty;
}

class _Cart {
  _Cart({
    required this.id,
    required this.channel,
    required this.customer,
    required this.at,
    required this.lines,
    this.state = CartState.abandoned,
    List<DateTime>? reminders,
  }) : reminders = reminders ?? [];

  final String id;
  final CartChannel channel;
  final String customer;
  final DateTime at;
  final List<_Line> lines;
  final String state;
  final List<DateTime> reminders;

  num get total => lines.fold<num>(0, (a, l) => a + l.total);

  List<_Line> pick(List<String> ids) =>
      ids.isEmpty ? lines : lines.where((l) => ids.contains(l.id)).toList();

  CartRow row() => CartRow(
        id: id,
        channel: channel,
        state: state,
        customer: customer,
        abandonedAt: at,
        itemCount: lines.length,
        quantity: lines.fold(0, (a, l) => a + l.qty),
        value: total,
        topProduct: lines.first.name,
        topThumbnail: lines.first.thumb,
        myReminders: reminders.length,
        lastReminderAt: reminders.isEmpty ? null : reminders.last,
      );

  ReminderRules rules() {
    if (state != CartState.abandoned) {
      return const ReminderRules(
          canRemind: false,
          reason: 'NOT_OPEN',
          message: 'This cart is no longer open — no reminder needed.');
    }
    if (reminders.length >= 3) {
      return const ReminderRules(
          canRemind: false,
          reason: 'LIMIT_REACHED',
          message: 'You have already sent 3 reminders for this cart.');
    }
    if (reminders.isNotEmpty) {
      final wait =
          const Duration(hours: 24) - DateTime.now().difference(reminders.last);
      if (!wait.isNegative) {
        return ReminderRules(
            canRemind: false,
            reason: 'COOLDOWN',
            sent: reminders.length,
            nextAllowedAt: DateTime.now().add(wait),
            message:
                'You sent a reminder recently. You can send another in ${wait.inHours + 1} hours.');
      }
    }
    return ReminderRules(canRemind: true, sent: reminders.length);
  }

  ReminderPreview render(String key, List<_Line> use) {
    final first = customer.split(' ').first;
    final product = use.length > 1
        ? '${use.first.name} + ${use.length - 1} more'
        : use.first.name;
    final scarce = use
        .where((l) => l.stock != null && l.stock! > 0 && l.stock! <= 5)
        .toList()
      ..sort((a, b) => a.stock!.compareTo(b.stock!));
    return switch (key) {
      'HELP' => ReminderPreview(
          title: 'Your seller is here to help',
          body:
              'Hi $first, you left $product in your cart. Have a question about it? Open the product and ask, or complete your order now.',
          productCount: use.length),
      'LOW_STOCK' => ReminderPreview(
          title: 'Only ${scarce.first.stock} left: ${scarce.first.name}',
          body:
              'Hi $first, only ${scarce.first.stock} unit(s) of ${scarce.first.name} are left. Order now so you do not miss out.',
          productCount: use.length),
      _ => ReminderPreview(
          title: 'Still thinking about $product?',
          body:
              'Hi $first, your $product is waiting in your cart. Complete your order whenever you are ready.',
          productCount: use.length),
    };
  }

  CartDetail detail() {
    final hasLow =
        lines.any((l) => l.stock != null && l.stock! > 0 && l.stock! <= 5);
    final templates = [
      for (final (k, label, hint) in const [
        (
          'GENTLE',
          'Friendly reminder',
          'A simple nudge — best as the first message.'
        ),
        (
          'HELP',
          'Offer help',
          'Invites questions — good when the price is high.'
        ),
        ('LOW_STOCK', 'Low stock', 'Only when real stock is low.'),
      ])
        () {
          final avail = k != 'LOW_STOCK' || hasLow;
          final p = avail ? render(k, lines) : null;
          return ReminderTemplate(
              key: k,
              label: label,
              hint: hint,
              available: avail,
              unavailableReason:
                  avail ? null : 'No item of yours is low on stock.',
              title: p?.title ?? '',
              body: p?.body ?? '');
        }(),
    ];
    final r = rules();
    return CartDetail(
      id: id,
      channel: channel,
      state: state,
      customer: customer,
      abandonedAt: at,
      total: total,
      items: [
        for (final l in lines)
          CartLine(
              productId: l.id,
              name: l.name,
              thumbnail: l.thumb,
              quantity: l.qty,
              unitPrice: l.price,
              lineTotal: l.total,
              stock: l.stock),
      ],
      timeline: [
        TimelineEntry(kind: 'DETECTED', at: at),
        for (final t in reminders)
          TimelineEntry(kind: 'MY_REMINDER', at: t, template: 'GENTLE'),
        if (state == CartState.ordered)
          TimelineEntry(
              kind: 'CONVERTED', at: at.add(const Duration(hours: 3))),
      ],
      reminder: ReminderRules(
        canRemind: r.canRemind,
        reason: r.reason,
        message: r.message,
        nextAllowedAt: r.nextAllowedAt,
        sent: reminders.length,
        templates: templates,
      ),
    );
  }
}
