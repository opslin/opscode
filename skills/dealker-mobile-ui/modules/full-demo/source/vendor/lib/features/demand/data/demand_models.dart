/// Demand = what buyers (other verified vendors) need, and how a seller answers it:
/// requirement → offer → accepted → paid (escrow) → dispatched / pickup → received → settled.
/// Backed by `/vendor/b2b/*` (modules/b2b). Money amounts come from the server.
library;

num? _num(Object? v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
int _int(Object? v, [int d = 0]) => _num(v)?.toInt() ?? d;
double _dbl(Object? v, [double d = 0]) => _num(v)?.toDouble() ?? d;
DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();
String? _str(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
Map<String, dynamic> _map(Object? v) =>
    (v as Map?)?.cast<String, dynamic>() ?? const {};
List<Map<String, dynamic>> _rows(Object? v) =>
    ((v as List?) ?? const []).whereType<Map<String, dynamic>>().toList();

/// Server enums, kept as plain strings so an unknown future value never crashes the app.
class ReqStatus {
  ReqStatus._();
  static const open = 'OPEN';
  static const awarded = 'AWARDED';
  static const inFulfilment = 'IN_FULFILMENT';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';
  static const expired = 'EXPIRED';
}

class OrderStatus {
  OrderStatus._();
  static const pendingPayment = 'PENDING_PAYMENT';
  static const paid = 'PAID';
  static const packed = 'PACKED';
  static const dispatched = 'DISPATCHED';
  static const delivered = 'DELIVERED';
  static const completed = 'COMPLETED';
  static const disputed = 'DISPUTED';
  static const cancelled = 'CANCELLED';
  static const refunded = 'REFUNDED';

  /// Needs attention or is still moving.
  static const active = [
    pendingPayment, paid, packed, dispatched, delivered, disputed //
  ];
}

class OfferState {
  OfferState._();
  static const pending = 'PENDING';
  static const viewed = 'VIEWED';
  static const accepted = 'ACCEPTED';
  static const partial = 'PARTIAL';
  static const notSelected = 'NOT_SELECTED';
  static const withdrawn = 'WITHDRAWN';
  static const expired = 'EXPIRED';
}

/// How much of the requirement a vendor's own stock covers.
enum MatchLevel {
  exact,
  close,
  none;

  static MatchLevel parse(Object? v) => switch ('$v') {
        'EXACT' => exact,
        'CLOSE' => close,
        _ => none,
      };
}

class MatchBrief {
  const MatchBrief(
      {this.level = MatchLevel.none, this.stock = 0, this.listingId});
  final MatchLevel level;
  final int stock;
  final String? listingId;

  factory MatchBrief.fromJson(Map<String, dynamic> j) => MatchBrief(
      level: MatchLevel.parse(j['level']),
      stock: _int(j['stock']),
      listingId: _str(j['listing_id']));
}

/// The seller's own offer on a requirement (one per seller).
class MyQuote {
  const MyQuote({
    required this.id,
    required this.quantityOffered,
    required this.unitPrice,
    required this.status,
    this.quantityAwarded = 0,
    this.buyerViewedAt,
    this.condition,
    this.deliveryDays,
    this.note,
    this.offerState,
  });
  final String id;
  final int quantityOffered;
  final double unitPrice;
  final String status;
  final int quantityAwarded;
  final DateTime? buyerViewedAt;
  final String? condition;
  final int? deliveryDays;
  final String? note;
  final String? offerState;

  double get total => unitPrice * quantityOffered;

  factory MyQuote.fromJson(Map<String, dynamic> j) => MyQuote(
        id: '${j['id']}',
        quantityOffered: _int(j['quantity_offered']),
        unitPrice: _dbl(j['unit_price']),
        status: '${j['status']}',
        quantityAwarded: _int(j['quantity_awarded']),
        buyerViewedAt: _date(j['buyer_viewed_at']),
        condition: _str(j['condition']),
        deliveryDays: _num(j['delivery_days'])?.toInt(),
        note: _str(j['note']),
        offerState: _str(j['offer_state']),
      );
}

class OrderBrief {
  const OrderBrief(
      {required this.id,
      required this.orderNumber,
      required this.status,
      required this.quantity,
      required this.paymentStatus});
  final String id;
  final String orderNumber;
  final String status;
  final int quantity;
  final String paymentStatus;

  factory OrderBrief.fromJson(Map<String, dynamic> j) => OrderBrief(
      id: '${j['id']}',
      orderNumber: '${j['order_number']}',
      status: '${j['status']}',
      quantity: _int(j['quantity']),
      paymentStatus: '${j['payment_status']}');
}

class Requirement {
  const Requirement({
    required this.id,
    required this.number,
    required this.title,
    required this.productName,
    required this.quantityNeeded,
    required this.status,
    required this.createdAt,
    this.quantityAwarded = 0,
    this.brand,
    this.storage,
    this.targetPrice,
    this.targetPriceMax,
    this.conditionPref = 'ANY',
    this.minBattery,
    this.displayPref = 'ANY',
    this.fulfilmentPref = 'ANY',
    this.isUrgent = false,
    this.description,
    this.deliveryCity,
    this.deliveryPincode,
    this.responseDeadline,
    this.requiredBy,
    this.buyerName = '',
    this.thumbnail,
    this.tags = const [],
    this.quoteCount,
    this.bestPrice,
    this.offeredTotal,
    this.viewed = false,
    this.myMatch,
    this.myQuote,
    this.offerState,
    this.myOrders = const [],
    this.viewCount,
  });

  final String id;
  final String number;
  final String title;
  final String productName;
  final String? brand;
  final String? storage;
  final int quantityNeeded;
  final int quantityAwarded;
  final double? targetPrice;
  final double? targetPriceMax;
  final String conditionPref;
  final int? minBattery;
  final String displayPref;
  final String fulfilmentPref;
  final bool isUrgent;
  final String? description;
  final String? deliveryCity;
  final String? deliveryPincode;
  final DateTime? responseDeadline;
  final DateTime? requiredBy;
  final String status;
  final DateTime createdAt;
  final String buyerName;
  final String? thumbnail;
  final List<String> tags;

  // Buyer-side figures — the server hides these from other vendors (offers are sealed).
  final int? quoteCount;
  final double? bestPrice;
  final int? offeredTotal;

  // Seller-side list extras.
  final bool viewed;
  final MatchBrief? myMatch;
  final MyQuote? myQuote;
  final String? offerState;
  final List<OrderBrief> myOrders;
  final int? viewCount;

  int get remaining =>
      (quantityNeeded - quantityAwarded).clamp(0, quantityNeeded);
  bool get urgent => tags.contains('URGENT');
  bool get bulk => tags.contains('BULK');
  bool get isOpen => status == ReqStatus.open;
  bool get hasMatch => myMatch?.level == MatchLevel.exact;
  bool get isNew => !viewed && myQuote == null;

  /// "₹29,000 – ₹30,000" is built by the UI (needs the money formatter).
  bool get hasPrice => targetPrice != null || targetPriceMax != null;

  factory Requirement.fromJson(Map<String, dynamic> j) {
    final quote =
        j['my_quote'] == null ? null : MyQuote.fromJson(_map(j['my_quote']));
    final state = _str(j['offer_state']);
    return Requirement(
      id: '${j['id']}',
      number: '${j['requirement_number'] ?? ''}',
      title: '${j['title'] ?? j['product_name']}',
      productName: '${j['product_name']}',
      brand: _str(j['brand']),
      storage: _str(j['storage']),
      quantityNeeded: _int(j['quantity_needed']),
      quantityAwarded: _int(j['quantity_awarded']),
      targetPrice: _num(j['target_price'])?.toDouble(),
      targetPriceMax: _num(j['target_price_max'])?.toDouble(),
      conditionPref: _str(j['condition_pref']) ?? 'ANY',
      minBattery: _num(j['min_battery_health'])?.toInt(),
      displayPref: _str(j['display_pref']) ?? 'ANY',
      fulfilmentPref: _str(j['fulfilment_pref']) ?? 'ANY',
      isUrgent: j['is_urgent'] == true,
      description: _str(j['description']),
      deliveryCity: _str(j['delivery_city']),
      deliveryPincode: _str(j['delivery_pincode']),
      responseDeadline: _date(j['response_deadline']),
      requiredBy: _date(j['required_by']),
      status: '${j['status']}',
      createdAt: _date(j['created_at']) ?? DateTime.now(),
      buyerName: '${j['buyer_name'] ?? ''}',
      thumbnail: _str(j['thumbnail_url']),
      tags: ((j['tags'] as List?) ?? const []).map((e) => '$e').toList(),
      quoteCount: _num(j['quote_count'])?.toInt(),
      bestPrice: _num(j['best_price'])?.toDouble(),
      offeredTotal: _num(j['quantity_offered_total'])?.toInt(),
      viewed: j['viewed'] == true,
      myMatch: j['my_match'] == null
          ? null
          : MatchBrief.fromJson(_map(j['my_match'])),
      myQuote: quote,
      offerState: state,
      myOrders: _rows(j['my_orders']).map(OrderBrief.fromJson).toList(),
      viewCount: _num(_map(j['views'])['v'])?.toInt(),
    );
  }
}

class RequirementPage {
  const RequirementPage({required this.items, required this.total});
  final List<Requirement> items;
  final int total;
}

class OfferCounts {
  const OfferCounts(
      {this.active = 0, this.pending = 0, this.closed = 0, this.accepted = 0});
  final int active;
  final int pending;
  final int closed;
  final int accepted;
}

/// Numbers behind the hub tabs, the home banner and the bell badge.
class DemandSummary {
  const DemandSummary({
    this.open = 0,
    this.newCount = 0,
    this.matched = 0,
    this.urgent = 0,
    this.offers = const OfferCounts(),
    this.myOpen = 0,
    this.myTotal = 0,
    this.offersWaiting = 0,
    this.toPay = 0,
    this.toReceive = 0,
    this.buyingActive = 0,
    this.toDispatch = 0,
    this.sellingActive = 0,
  });
  final int open;
  final int newCount;
  final int matched;
  final int urgent;
  final OfferCounts offers;
  final int myOpen;
  final int myTotal;
  final int offersWaiting;
  final int toPay;
  final int toReceive;
  final int buyingActive;
  final int toDispatch;
  final int sellingActive;

  int get ordersActive => buyingActive + sellingActive;

  /// Things the vendor has to do now: pack/dispatch, pay, confirm receipt.
  int get actionsDue => toDispatch + toPay + toReceive;

  factory DemandSummary.fromJson(Map<String, dynamic> j) {
    final o = _map(j['offers']);
    final m = _map(j['mine']);
    final r = _map(j['orders']);
    return DemandSummary(
      open: _int(j['open']),
      newCount: _int(j['new']),
      matched: _int(j['matched']),
      urgent: _int(j['urgent']),
      offers: OfferCounts(
          active: _int(o['active']),
          pending: _int(o['pending']),
          closed: _int(o['closed']),
          accepted: _int(o['accepted'])),
      myOpen: _int(m['open']),
      myTotal: _int(m['total']),
      offersWaiting: _int(m['offers_waiting']),
      toPay: _int(r['to_pay']),
      toReceive: _int(r['to_receive']),
      buyingActive: _int(r['buying_active']),
      toDispatch: _int(r['to_dispatch']),
      sellingActive: _int(r['selling_active']),
    );
  }
}

class MatchListing {
  const MatchListing({
    required this.id,
    required this.name,
    required this.stock,
    required this.level,
    required this.suggestedPrice,
    this.brand,
    this.condition,
    this.battery,
    this.storage,
    this.price = 0,
    this.wholesale,
    this.moq = 1,
    this.thumbnail,
    this.reasons = const [],
  });
  final String id;
  final String name;
  final String? brand;
  final String? condition;
  final int? battery;
  final String? storage;
  final int stock;
  final double price;
  final double? wholesale;
  final int moq;
  final String? thumbnail;
  final MatchLevel level;
  final List<String> reasons;
  final double suggestedPrice;

  factory MatchListing.fromJson(Map<String, dynamic> j) => MatchListing(
        id: '${j['id']}',
        name: '${j['name']}',
        brand: _str(j['brand']),
        condition: _str(j['condition']),
        battery: _num(j['battery_health'])?.toInt(),
        storage: _str(j['storage']),
        stock: _int(j['stock']),
        price: _dbl(j['price']),
        wholesale: _num(j['wholesale_price'])?.toDouble(),
        moq: _int(j['min_order_qty'], 1),
        thumbnail: _str(j['thumbnail_url']),
        level: MatchLevel.parse(j['level']),
        reasons:
            ((j['reasons'] as List?) ?? const []).map((e) => '$e').toList(),
        suggestedPrice: _dbl(j['suggested_price'], _dbl(j['price'])),
      );
}

class OfferSuggestion {
  const OfferSuggestion(
      {required this.listingId,
      required this.unitPrice,
      required this.quantity,
      this.condition});
  final String listingId;
  final double unitPrice;
  final int quantity;
  final String? condition;

  factory OfferSuggestion.fromJson(Map<String, dynamic> j) => OfferSuggestion(
      listingId: '${j['listingId']}',
      unitPrice: _dbl(j['unitPrice']),
      quantity: _int(j['quantity'], 1),
      condition: _str(j['condition']));
}

/// "Match Found!" — my stock against one requirement.
class MatchResult {
  const MatchResult({
    required this.level,
    required this.totalStock,
    required this.canSupply,
    required this.remaining,
    required this.listings,
    required this.commissionPercent,
    this.suggested,
    this.myQuote,
  });
  final MatchLevel level;
  final int totalStock;
  final int canSupply;
  final int remaining;
  final List<MatchListing> listings;
  final OfferSuggestion? suggested;
  final double commissionPercent;
  final MyQuote? myQuote;

  List<MatchListing> get exact =>
      listings.where((l) => l.level == MatchLevel.exact).toList();

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        level: MatchLevel.parse(j['level']),
        totalStock: _int(j['totalStock']),
        canSupply: _int(j['canSupply']),
        remaining: _int(j['remaining']),
        listings: _rows(j['listings']).map(MatchListing.fromJson).toList(),
        suggested: j['suggested'] == null
            ? null
            : OfferSuggestion.fromJson(_map(j['suggested'])),
        commissionPercent: _dbl(j['commissionPercent']),
        myQuote:
            j['myQuote'] == null ? null : MyQuote.fromJson(_map(j['myQuote'])),
      );
}

/// An offer as the buyer sees it ("Select Sellers").
class Quote {
  const Quote({
    required this.id,
    required this.sellerVendorId,
    required this.sellerName,
    required this.quantityOffered,
    required this.quantityAwarded,
    required this.unitPrice,
    required this.status,
    required this.createdAt,
    this.sellerRating,
    this.sellerCity,
    this.sellerCompleted = 0,
    this.condition,
    this.deliveryDays,
    this.note,
    this.offerState,
  });
  final String id;
  final String sellerVendorId;
  final String sellerName;
  final double? sellerRating;
  final String? sellerCity;
  final int sellerCompleted;
  final int quantityOffered;
  final int quantityAwarded;
  final double unitPrice;
  final String? condition;
  final int? deliveryDays;
  final String? note;
  final String status;
  final String? offerState;
  final DateTime createdAt;

  int get available => quantityOffered - quantityAwarded;
  bool get selectable =>
      available > 0 &&
      !const ['WITHDRAWN', 'EXPIRED', 'NOT_SELECTED'].contains(status);

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        id: '${j['id']}',
        sellerVendorId: '${j['seller_vendor_id']}',
        sellerName: '${j['seller_name'] ?? 'Seller'}',
        sellerRating: _num(j['seller_rating'])?.toDouble(),
        sellerCity: _str(j['seller_city']),
        sellerCompleted: _int(j['seller_completed_orders']),
        quantityOffered: _int(j['quantity_offered']),
        quantityAwarded: _int(j['quantity_awarded']),
        unitPrice: _dbl(j['unit_price']),
        condition: _str(j['condition']),
        deliveryDays: _num(j['delivery_days'])?.toInt(),
        note: _str(j['note']),
        status: '${j['status']}',
        offerState: _str(j['offer_state']),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
      );
}

class DemandOrder {
  const DemandOrder({
    required this.id,
    required this.orderNumber,
    required this.requirementId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.productName = '',
    this.storage,
    this.thumbnail,
    this.sellerName = '',
    this.buyerName = '',
    this.commissionPercent = 0,
    this.commissionAmount = 0,
    this.sellerPayable = 0,
    this.courierName,
    this.awb,
    this.trackingUrl,
    this.fulfilmentType = 'DELIVERY',
    this.pickupAt,
    this.pickupNote,
    this.paymentMethod,
    this.paidAt,
    this.packedAt,
    this.invoiceUploadedAt,
    this.dispatchedAt,
    this.deliveredAt,
    this.receivedAt,
    this.receivedQuantity,
    this.receiptNote,
    this.releasedAmount,
    this.disputeStatus,
    this.disputeReason,
    this.disputeResolution,
    this.cancelReason,
  });

  final String id;
  final String orderNumber;
  final String requirementId;
  final String productName;
  final String? storage;
  final String? thumbnail;
  final String sellerName;
  final String buyerName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final double commissionPercent;
  final double commissionAmount;
  final double sellerPayable;
  final String status;
  final String paymentStatus;
  final String? courierName;
  final String? awb;
  final String? trackingUrl;
  final String fulfilmentType;
  final DateTime? pickupAt;
  final String? pickupNote;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? packedAt;
  /// When the seller uploaded their invoice — required before packing / dispatching.
  final DateTime? invoiceUploadedAt;
  bool get hasInvoice => invoiceUploadedAt != null;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final DateTime? receivedAt;
  final int? receivedQuantity;
  final String? receiptNote;
  final double? releasedAmount;
  final String? disputeStatus;
  final String? disputeReason;
  final String? disputeResolution;
  final String? cancelReason;

  bool get isPickup => fulfilmentType == 'PICKUP';
  bool get isActive => OrderStatus.active.contains(status);

  factory DemandOrder.fromJson(Map<String, dynamic> j) => DemandOrder(
        id: '${j['id']}',
        orderNumber: '${j['order_number']}',
        requirementId: '${j['requirement_id']}',
        productName: '${j['product_name'] ?? ''}',
        storage: _str(j['storage']),
        thumbnail: _str(j['thumbnail_url']),
        sellerName: '${j['seller_name'] ?? ''}',
        buyerName: '${j['buyer_name'] ?? ''}',
        quantity: _int(j['quantity']),
        unitPrice: _dbl(j['unit_price']),
        subtotal: _dbl(j['subtotal']),
        commissionPercent: _dbl(j['commission_percent']),
        commissionAmount: _dbl(j['commission_amount']),
        sellerPayable: _dbl(j['seller_payable']),
        status: '${j['status']}',
        paymentStatus: '${j['payment_status']}',
        courierName: _str(j['courier_name']),
        awb: _str(j['awb']),
        trackingUrl: _str(j['tracking_url']),
        fulfilmentType: _str(j['fulfilment_type']) ?? 'DELIVERY',
        pickupAt: _date(j['pickup_at']),
        pickupNote: _str(j['pickup_note']),
        paymentMethod: _str(j['payment_method']),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        paidAt: _date(j['paid_at']),
        packedAt: _date(j['packed_at']),
        invoiceUploadedAt: _date(j['invoice_uploaded_at']),
        dispatchedAt: _date(j['dispatched_at']),
        deliveredAt: _date(j['delivered_at']),
        receivedAt: _date(j['received_at']),
        receivedQuantity: _num(j['received_quantity'])?.toInt(),
        receiptNote: _str(j['receipt_note']),
        releasedAmount: _num(j['released_amount'])?.toDouble(),
        disputeStatus: _str(j['dispute_status']),
        disputeReason: _str(j['dispute_reason']),
        disputeResolution: _str(j['dispute_resolution']),
        cancelReason: _str(j['cancel_reason']),
      );
}

class OrderPage {
  const OrderPage({required this.items, required this.total});
  final List<DemandOrder> items;
  final int total;
}

class DemandEvent {
  const DemandEvent(
      {required this.type, required this.at, this.note, this.actor});
  final String type;
  final DateTime at;
  final String? note;
  final String? actor;

  factory DemandEvent.fromJson(Map<String, dynamic> j) => DemandEvent(
      type: '${j['type']}',
      at: _date(j['created_at']) ?? DateTime.now(),
      note: _str(j['note']),
      actor: _str(j['actor_label']));
}

class DemandPayment {
  const DemandPayment(
      {required this.amount,
      required this.method,
      required this.status,
      this.paidAt,
      this.reference});
  final double amount;
  final String method;
  final String status;
  final DateTime? paidAt;
  final String? reference;

  factory DemandPayment.fromJson(Map<String, dynamic> j) => DemandPayment(
      amount: _dbl(j['amount']),
      method: '${j['method']}',
      status: '${j['status']}',
      paidAt: _date(j['paid_at']),
      reference: _str(j['reference']));
}

/// A requirement with every offer, order and event the viewer is allowed to see.
class RequirementDetail {
  const RequirementDetail({
    required this.requirement,
    required this.quotes,
    required this.orders,
    required this.events,
    required this.isBuyer,
    this.payment,
    this.myQuoteId,
  });
  final Requirement requirement;
  final List<Quote> quotes;
  final List<DemandOrder> orders;
  final List<DemandEvent> events;
  final DemandPayment? payment;
  final bool isBuyer;
  final String? myQuoteId;

  Quote? get myQuote {
    for (final q in quotes) {
      if (q.id == myQuoteId) return q;
    }
    return null;
  }

  List<DemandOrder> get unpaidOrders =>
      orders.where((o) => o.status == OrderStatus.pendingPayment).toList();

  factory RequirementDetail.fromJson(Map<String, dynamic> j) {
    final viewer = _map(j['viewer']);
    return RequirementDetail(
      requirement: Requirement.fromJson(_map(j['requirement'])),
      quotes: _rows(j['quotes']).map(Quote.fromJson).toList(),
      orders: _rows(j['orders']).map(DemandOrder.fromJson).toList(),
      events: _rows(j['events']).map(DemandEvent.fromJson).toList(),
      payment: j['payment'] == null
          ? null
          : DemandPayment.fromJson(_map(j['payment'])),
      isBuyer: viewer['isBuyer'] == true,
      myQuoteId: _str(viewer['myQuoteId']),
    );
  }
}

/// Who is on the other side of an order (contact details only appear once it is paid).
class Party {
  const Party(
      {required this.name, this.phone, this.city, this.pincode, this.address});
  final String name;
  final String? phone;
  final String? city;
  final String? pincode;
  final String? address;

  String? get place {
    final parts =
        [address, city, pincode].whereType<String>().where((e) => e.isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory Party.fromJson(Map<String, dynamic> j) => Party(
      name: '${j['name'] ?? ''}',
      phone: _str(j['phone']),
      city: _str(j['city']),
      pincode: _str(j['pincode']),
      address: _str(j['address']));
}

class OrderDetail {
  const OrderDetail({
    required this.order,
    required this.requirement,
    required this.seller,
    required this.buyer,
    required this.events,
    required this.isBuyer,
    required this.isSeller,
    this.payment,
    this.devices = const [],
  });
  final List<OrderDevice> devices;
  final DemandOrder order;
  final Requirement requirement;
  final Party seller;
  final Party buyer;
  final DemandPayment? payment;
  final List<DemandEvent> events;
  final bool isBuyer;
  final bool isSeller;

  /// The other side of the deal from the viewer's point of view.
  Party get counterparty => isBuyer ? seller : buyer;

  factory OrderDetail.fromJson(Map<String, dynamic> j) {
    final viewer = _map(j['viewer']);
    return OrderDetail(
      order: DemandOrder.fromJson({
        ..._map(j['order']),
        'product_name': _map(j['requirement'])['product_name'],
        'storage': _map(j['requirement'])['storage'],
        'thumbnail_url': _map(j['requirement'])['thumbnail_url'],
        'seller_name': _map(j['seller'])['name'],
        'buyer_name': _map(j['buyer'])['name']
      }),
      requirement: Requirement.fromJson(_map(j['requirement'])),
      seller: Party.fromJson(_map(j['seller'])),
      buyer: Party.fromJson(_map(j['buyer'])),
      payment: j['payment'] == null
          ? null
          : DemandPayment.fromJson(_map(j['payment'])),
      events: _rows(j['events']).map(DemandEvent.fromJson).toList(),
      isBuyer: viewer['isBuyer'] == true,
      isSeller: viewer['isSeller'] == true,
      devices: _rows(j['devices']).map(OrderDevice.fromJson).toList(),
    );
  }
}

/// One device (Device 4) of a used / refurbished / open-box wholesale order.
class OrderDevice {
  const OrderDevice({required this.unitNo, required this.status, required this.score, required this.defects, required this.productName});
  final int unitNo;
  final String status; // RESERVED | PACKED | SOLD
  final int score;
  final int defects;
  final String productName;

  bool get packed => status == 'PACKED' || status == 'SOLD';

  factory OrderDevice.fromJson(Map<String, dynamic> j) => OrderDevice(
        unitNo: (j['unit_no'] as num?)?.toInt() ?? 0,
        status: _str(j['status']) ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        defects: (j['defects'] as num?)?.toInt() ?? 0,
        productName: _str(j['product_name']) ?? '',
      );
}

class WalletInfo {
  const WalletInfo({required this.balance, this.onHold = false});
  final double balance;
  final bool onHold;

  factory WalletInfo.fromJson(Map<String, dynamic> j) =>
      WalletInfo(balance: _dbl(j['balance']), onHold: j['onHold'] == true);
}

/// What a buyer picks on "Select Sellers": a quote and how many units from it.
class Selection {
  const Selection(this.quoteId, this.quantity);
  final String quoteId;
  final int quantity;

  Map<String, dynamic> toJson() => {'quoteId': quoteId, 'quantity': quantity};
}

/// What Razorpay Checkout needs to open for wholesale orders.
class GatewayOrder {
  const GatewayOrder(
      {required this.keyId,
      required this.orderId,
      required this.amount,
      required this.amountRupees,
      required this.description,
      this.requirementIds = const []});
  factory GatewayOrder.fromJson(Map<String, dynamic> j) => GatewayOrder(
        keyId: '${j['keyId'] ?? ''}',
        orderId: '${j['orderId'] ?? ''}',
        amount: ((j['amount'] as num?) ?? 0).toInt(),
        amountRupees: ((j['amountRupees'] as num?) ?? 0).toDouble(),
        description: '${j['description'] ?? 'Wholesale order'}',
        requirementIds: ((j['requirementIds'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
      );
  final String keyId;
  final String orderId;

  /// In paise.
  final int amount;
  final double amountRupees;
  final String description;
  final List<String> requirementIds;
}
