import 'dart:convert';

// Models for the auction module. Field names follow the real API:
//  - /manage/auctions*  → raw auction row (snake_case) + private seller fields
//  - /auctions*         → public bidder view (serializePublic)
// Parsing is defensive so a missing field never crashes a screen.

num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
int _i(dynamic v) => _n(v)?.toInt() ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';
DateTime? _d(dynamic v) => DateTime.tryParse(_s(v))?.toLocal();

String? _vid(dynamic v) => _s(v).isEmpty ? null : _s(v);

List<String> _urls(dynamic v) => ((v as List?) ?? const [])
    .map((e) => e is String ? e : _s((e as Map?)?['url']))
    .where((e) => e.isNotEmpty)
    .toList();

/// Seller's own pre-check for an auction lot: condition checklist, ticked video checks,
/// evidence photos and a note. Informational — the platform QC decision is separate.
class QcReport {
  const QcReport({
    this.checklist = const {},
    this.checks = const {},
    this.photos = const [],
    this.notes = '',
  });
  final Map<String, String> checklist;
  final Map<String, bool> checks;
  final List<String> photos;
  final String notes;

  bool get isEmpty =>
      checklist.isEmpty && checks.isEmpty && photos.isEmpty && notes.isEmpty;
  int get passed => checks.values.where((v) => v).length;

  static QcReport? fromJson(dynamic v) {
    if (v is! Map) return null;
    final r = QcReport(
      checklist: {
        for (final e in ((v['checklist'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}'
      },
      checks: {
        for (final e in ((v['checks'] as Map?) ?? const {}).entries)
          '${e.key}': e.value == true
      },
      photos: _urls(v['photos']),
      notes: _s(v['notes']).trim(),
    );
    return r.isEmpty ? null : r;
  }

  Map<String, dynamic> toJson() => {
        if (checklist.isNotEmpty) 'checklist': checklist,
        if (checks.isNotEmpty) 'checks': checks,
        if (photos.isNotEmpty) 'photos': photos,
        if (notes.isNotEmpty) 'notes': notes,
      };
}

enum AuctionAudience {
  b2b('B2B', 'B2B', 'Business to Business', 'Wholesale / Partners'),
  b2c('B2C', 'B2C', 'Business to Customer', 'General Customers');

  const AuctionAudience(this.api, this.short, this.title, this.subtitle);
  final String api;
  final String short;
  final String title;
  final String subtitle;

  static AuctionAudience parse(String? v) =>
      v == 'B2B' ? AuctionAudience.b2b : AuctionAudience.b2c;
}

/// Backend statuses grouped into the tabs the vendor sees.
class AuctionStatuses {
  AuctionStatuses._();
  static const live = ['LIVE', 'PAUSED'];
  static const upcoming = [
    'DRAFT',
    'PENDING_APPROVAL',
    'SCHEDULED',
    'REJECTED'
  ];
  static const completed = [
    'AWAITING_PAYMENT',
    'SOLD',
    'UNSOLD',
    'DEFAULTED',
    'CANCELLED'
  ];
}

class AuctionItem {
  const AuctionItem({
    required this.id,
    required this.number,
    required this.title,
    required this.imageUrl,
    required this.images,
    required this.status,
    required this.audience,
    required this.quantity,
    required this.startPrice,
    required this.currentPrice,
    required this.reservePrice,
    required this.bidIncrement,
    required this.buyNowPrice,
    required this.registrationFee,
    required this.bidCount,
    required this.bidderCount,
    required this.registrationCount,
    required this.startsAt,
    required this.endsAt,
    required this.winningBid,
    required this.rejectedReason,
    required this.serverOffset,
    this.videoUrl,
    this.qc,
    this.orderId,
    this.paymentDeadline,
    this.amountDue,
    this.feeCredit,
  });

  final String? orderId;
  final DateTime? paymentDeadline;
  final num? amountDue;
  final num? feeCredit;
  final String id;
  final String number;
  final String title;
  final String? imageUrl;
  final String? videoUrl;
  final QcReport? qc;
  final List<String> images;
  final String status;
  final AuctionAudience audience;
  final int quantity;
  final num startPrice;
  final num currentPrice;
  final num? reservePrice;
  final num? bidIncrement;
  final num? buyNowPrice;
  final num registrationFee;
  final int bidCount;
  final int bidderCount;
  final int registrationCount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final num? winningBid;
  final String? rejectedReason;

  /// server_time − device clock, so countdowns stay right on a wrong clock.
  final Duration serverOffset;

  bool get isLive => status == 'LIVE';
  bool get hasBids => bidCount > 0;

  /// Highest bid so far, or the start price when nobody has bid.
  num get highest => hasBids ? currentPrice : startPrice;

  String? get cover => imageUrl ?? (images.isEmpty ? null : images.first);

  /// Seller may withdraw before it starts, or while live with zero bids.
  bool get canCancel =>
      const ['DRAFT', 'PENDING_APPROVAL', 'REJECTED', 'SCHEDULED']
          .contains(status) ||
      (status == 'LIVE' && !hasBids);

  /// Seller may close a live auction early once somebody has bid, to take the top bid.
  bool get canEndNow => status == 'LIVE' && hasBids;
  bool get canSubmit => status == 'DRAFT' || status == 'REJECTED';
  bool get canRelist =>
      const ['UNSOLD', 'DEFAULTED', 'CANCELLED', 'REJECTED'].contains(status);

  factory AuctionItem.fromJson(Map<String, dynamic> j) {
    final server = _d(j['server_time']);
    return AuctionItem(
      id: _s(j['id']),
      number: _s(j['auction_number']),
      title: _s(j['title']),
      imageUrl: j['image_url'] as String?,
      images: _urls(j['images']),
      status: _s(j['status']),
      audience: AuctionAudience.parse(_s(j['audience'])),
      quantity: _i(j['quantity']) == 0 ? 1 : _i(j['quantity']),
      startPrice: _n(j['start_price']) ?? 0,
      currentPrice: _n(j['current_price']) ?? _n(j['start_price']) ?? 0,
      reservePrice: _n(j['reserve_price']),
      bidIncrement: _n(j['bid_increment']),
      buyNowPrice: _n(j['buy_now_price']),
      registrationFee: _n(j['registration_fee']) ?? 0,
      bidCount: _i(j['bid_count']),
      bidderCount: _i(j['bidder_count']),
      registrationCount: _i(j['registration_count']),
      startsAt: _d(j['starts_at']),
      endsAt: _d(j['ends_at']),
      winningBid: _n(j['winning_bid']),
      rejectedReason: j['rejected_reason'] as String?,
      videoUrl: _vid(j['video_url']),
      qc: QcReport.fromJson(j['qc_report']),
      orderId: _vid(j['order_id']),
      paymentDeadline: _d(j['payment_deadline']),
      amountDue: _n(j['amount_due']),
      feeCredit: _n(j['fee_credit']),
      serverOffset:
          server == null ? Duration.zero : server.difference(DateTime.now()),
    );
  }
}

/// The vendor's slice of the order created when the winner paid (seller order).
class SaleOrder {
  const SaleOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentStatus,
    required this.buyerName,
    required this.address,
    required this.phone,
    required this.courier,
    required this.awb,
    required this.payable,
    required this.subtotal,
    required this.commission,
  });
  final String id;
  final String number;
  final String
      status; // ORDER_PLACED | CONFIRMED | PACKED | READY_TO_SHIP | SHIPPED | OUT_FOR_DELIVERY | DELIVERED | CANCELLED
  final String paymentStatus;
  final String buyerName;
  final String address;
  final String phone;
  final String? courier;
  final String? awb;
  final num payable;
  final num subtotal;
  final num commission;

  bool get paid => paymentStatus.toUpperCase() == 'PAID';

  factory SaleOrder.fromJson(Map<String, dynamic> j) {
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
    final line = [
      pick(['address_line1', 'addressLine1', 'line1']),
      pick(['address_line2', 'addressLine2', 'line2']),
      pick(['landmark']),
      pick(['city']),
      pick(['state']),
      pick(['pincode', 'postal_code']),
    ].where((e) => e.isNotEmpty).join(', ');
    final sh = j['shipment'] is Map
        ? (j['shipment'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return SaleOrder(
      id: _s(j['id']),
      number: _s(j['parent_order_number']).isNotEmpty
          ? _s(j['parent_order_number'])
          : _s(j['seller_order_number']),
      status: _s(j['status']),
      paymentStatus: _s(j['payment_status']),
      buyerName: pick(['name', 'full_name', 'contact_name']),
      address: line,
      phone: pick(['phone', 'mobile', 'contact_phone']),
      courier: _vid(sh['courier_name']),
      awb: _vid(sh['awb']),
      payable: _n(j['payable_to_seller']) ?? 0,
      subtotal: _n(j['item_subtotal']) ?? 0,
      commission: _n(j['commission_amount']) ?? 0,
    );
  }
}

class BidEntry {
  const BidEntry({
    required this.seq,
    required this.alias,
    this.username,
    required this.amount,
    required this.at,
    required this.isLeading,
    required this.isYou,
  });
  final int seq;
  final String alias;
  final String? username;
  final num amount;
  final DateTime? at;
  final bool isLeading;
  final bool isYou;

  /// Bidder's username; falls back to the anonymous alias when unset.
  String get displayName =>
      (username != null && username!.isNotEmpty) ? username! : alias;

  factory BidEntry.fromJson(Map<String, dynamic> j) => BidEntry(
        seq: _i(j['seq']),
        alias: _s(j['alias']),
        username: (j['username'] as String?)?.trim(),
        amount: _n(j['amount']) ?? 0,
        at: _d(j['at']),
        isLeading: j['is_leading'] == true,
        isYou: j['is_you'] == true,
      );
}

/// Seller-side detail: the auction plus the (masked) bid feed.
class AuctionDetail {
  const AuctionDetail({required this.auction, required this.bids});
  final AuctionItem auction;
  final List<BidEntry> bids;

  factory AuctionDetail.fromJson(Map<String, dynamic> j) => AuctionDetail(
        auction: AuctionItem.fromJson(
            (j['auction'] as Map?)?.cast<String, dynamic>() ?? const {}),
        bids: ((j['bids'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(BidEntry.fromJson)
            .toList(),
      );
}

class AuctionList {
  const AuctionList({required this.items, required this.total, this.counts});
  final List<AuctionItem> items;
  final int total;
  final Map<String, int>? counts;

  int countOf(List<String> statuses) =>
      statuses.fold(0, (a, s) => a + (counts?[s] ?? 0));
  int get all => counts?.values.fold<int>(0, (a, b) => a + b) ?? total;
}

class ProductOption {
  const ProductOption({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.thumbnail,
    required this.images,
    required this.stock,
    this.videoUrl,
    this.qc,
  });
  final String? videoUrl;
  final QcReport? qc;
  final String id;
  final String name;
  final String brand;
  final num price;
  final String? thumbnail;
  final List<String> images;
  final int stock;

  factory ProductOption.fromJson(Map<String, dynamic> j) => ProductOption(
        id: _s(j['id']),
        name: _s(j['name']),
        brand: _s(j['brand']),
        price: _n(j['sale_price']) ?? _n(j['price']) ?? 0,
        thumbnail: j['thumbnail_url'] as String?,
        images: _urls(j['images']),
        stock: _i(j['stock_quantity']),
        videoUrl: _vid(j['video_url']),
        qc: QcReport.fromJson(j['qc_report']),
      );
}

class AuctionRules {
  const AuctionRules({
    required this.enabled,
    required this.minFee,
    required this.maxFee,
    required this.feeMaxPct,
    required this.minDurationMinutes,
    required this.maxDurationDays,
    required this.requiresApproval,
    required this.antiSnipeWindowSec,
    required this.antiSnipeExtendSec,
    required this.paymentWindowHours,
    required this.loserRefundPct,
    required this.vendorSharePct,
  });
  final bool enabled;
  final num minFee;
  final num maxFee;
  final num feeMaxPct;
  final int minDurationMinutes;
  final int maxDurationDays;
  final bool requiresApproval;
  final int antiSnipeWindowSec;
  final int antiSnipeExtendSec;
  final int paymentWindowHours;
  final num loserRefundPct;
  final num vendorSharePct;

  /// Highest fee allowed for [startPrice] (platform cap % and absolute max).
  num maxFeeFor(num startPrice) {
    final cap = (startPrice * feeMaxPct / 100).floorToDouble();
    return cap < maxFee ? cap : maxFee;
  }

  factory AuctionRules.fromJson(Map<String, dynamic> j) => AuctionRules(
        enabled: j['enabled'] != false,
        minFee: _n(j['min_registration_fee']) ?? 0,
        maxFee: _n(j['max_registration_fee']) ?? 0,
        feeMaxPct: _n(j['fee_max_pct_of_start_price']) ?? 100,
        minDurationMinutes: _i(j['min_duration_minutes']),
        maxDurationDays: _i(j['max_duration_days']),
        requiresApproval: j['vendor_auctions_require_approval'] != false,
        antiSnipeWindowSec: _i(j['anti_snipe_window_sec']),
        antiSnipeExtendSec: _i(j['anti_snipe_extend_sec']),
        paymentWindowHours: _i(j['payment_window_hours']),
        loserRefundPct: _n(j['loser_fee_refund_pct']) ?? 0,
        vendorSharePct: _n(j['vendor_fee_share_pct']) ?? 0,
      );
}

/// The bidder's own standing in a lot.
class MyBidStanding {
  const MyBidStanding({
    required this.registered,
    required this.isLeading,
    required this.myMax,
    required this.isWinner,
    required this.feePaid,
    required this.amountDue,
    this.orderId,
    this.orderStatus,
    this.orderNumber,
    this.paymentDeadline,
  });
  final DateTime? paymentDeadline;
  final String? orderId;
  final String? orderStatus;
  final String? orderNumber;
  final bool registered;
  final bool isLeading;
  final num? myMax;
  final bool isWinner;
  final num feePaid;
  final num? amountDue;

  static const none = MyBidStanding(
      registered: false,
      isLeading: false,
      myMax: null,
      isWinner: false,
      feePaid: 0,
      amountDue: null);

  factory MyBidStanding.fromJson(Map<String, dynamic>? j) => j == null
      ? none
      : MyBidStanding(
          registered: j['registered'] == true,
          isLeading: j['is_leading'] == true,
          myMax: _n(j['my_max']),
          isWinner: j['is_winner'] == true,
          feePaid: _n(j['fee_paid']) ?? 0,
          amountDue: _n(j['amount_due']),
          orderId: _vid(j['order_id']),
          orderStatus: _vid(j['order_status']),
          orderNumber: _vid(j['order_number']),
          paymentDeadline: _d(j['payment_deadline']),
        );
}

/// Bidder-side view of a B2B lot (GET /auctions/:id).
class LotView {
  const LotView({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.images,
    required this.status,
    required this.quantity,
    required this.unitPrice,
    required this.sellerName,
    required this.startPrice,
    required this.currentPrice,
    required this.minNextBid,
    required this.increment,
    required this.reserveStatus,
    required this.registrationFee,
    required this.feePolicy,
    required this.bidCount,
    required this.bidderCount,
    required this.startsAt,
    required this.endsAt,
    required this.finalPrice,
    required this.leaderAlias,
    required this.my,
    required this.serverOffset,
    this.videoUrl,
    this.qc,
    this.viewCount = 0,
    this.badge,
    this.categoryName,
    this.watching = false,
  });

  final String? videoUrl;
  final QcReport? qc;
  final int viewCount;
  final String? badge; // TOP_BID | HOT | TRENDING, earned from real activity
  final String? categoryName;
  final bool watching;
  final String id;
  final String number;
  final String title;
  final String description;
  final String? imageUrl;
  final List<String> images;
  final String status;
  final int quantity;
  final num? unitPrice;
  final String sellerName;
  final num startPrice;
  final num currentPrice;
  final num? minNextBid;
  final num increment;
  final String reserveStatus; // NONE | MET | NOT_MET
  final num registrationFee;
  final String feePolicy;
  final int bidCount;
  final int bidderCount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final num? finalPrice;
  final String? leaderAlias;
  final MyBidStanding my;
  final Duration serverOffset;

  bool get isLive => status == 'LIVE';
  bool get isUpcoming => status == 'SCHEDULED';
  String? get cover => imageUrl ?? (images.isEmpty ? null : images.first);

  factory LotView.fromJson(Map<String, dynamic> j, {Duration? offset}) {
    final server = _d(j['server_time']);
    return LotView(
      id: _s(j['id']),
      number: _s(j['auction_number']),
      title: _s(j['title']),
      description: _s(j['description']),
      imageUrl: j['image_url'] as String?,
      images: _urls(j['images']),
      status: _s(j['status']),
      quantity: _i(j['quantity']) == 0 ? 1 : _i(j['quantity']),
      unitPrice: _n(j['unit_price']),
      sellerName: _s((j['seller'] as Map?)?['name']),
      startPrice: _n(j['start_price']) ?? 0,
      currentPrice: _n(j['current_price']) ?? 0,
      minNextBid: _n(j['min_next_bid']),
      increment: _n(j['increment']) ?? 0,
      reserveStatus: _s(j['reserve_status']),
      registrationFee: _n(j['registration_fee']) ?? 0,
      feePolicy: _s(j['fee_policy']),
      bidCount: _i(j['bid_count']),
      bidderCount: _i(j['bidder_count']),
      startsAt: _d(j['starts_at']),
      endsAt: _d(j['ends_at']),
      finalPrice: _n(j['final_price']),
      leaderAlias: j['leader_alias'] as String?,
      viewCount: _i(j['view_count']),
      badge: _vid(j['badge']),
      categoryName: _vid(j['category_name']),
      watching: j['watching'] == true,
      videoUrl: _vid(j['video_url']),
      qc: QcReport.fromJson(j['qc_report']),
      my: MyBidStanding.fromJson((j['my'] as Map?)?.cast<String, dynamic>()),
      serverOffset: offset ??
          (server == null ? Duration.zero : server.difference(DateTime.now())),
    );
  }
}

class LotList {
  const LotList({
    required this.items,
    required this.total,
    this.counts = const {},
    this.brands = const [],
    this.categories = const [],
  });
  final List<LotView> items;
  final int total;

  /// live / upcoming / ended — the tab badges.
  final Map<String, int> counts;
  final List<({String name, int count})> brands;
  final List<({String id, String name, int count})> categories;
}

/// What the B2B lots browse page asks the server for. Value-equal so it can key a provider.
class LotQuery {
  const LotQuery({
    this.tab = 'live',
    this.categoryId,
    this.brand,
    this.min,
    this.max,
    this.sort = 'ending',
    this.q = '',
  });
  final String tab;
  final String? categoryId;
  final String? brand;
  final num? min;
  final num? max;
  final String sort; // ending | new | price_asc | price_desc | bids
  final String q;

  bool get hasFilters =>
      categoryId != null ||
      brand != null ||
      min != null ||
      max != null ||
      q.isNotEmpty;

  LotQuery copyWith({
    String? tab,
    Object? categoryId = _kKeep,
    Object? brand = _kKeep,
    Object? min = _kKeep,
    Object? max = _kKeep,
    String? sort,
    String? q,
  }) =>
      LotQuery(
        tab: tab ?? this.tab,
        categoryId: identical(categoryId, _kKeep)
            ? this.categoryId
            : categoryId as String?,
        brand: identical(brand, _kKeep) ? this.brand : brand as String?,
        min: identical(min, _kKeep) ? this.min : min as num?,
        max: identical(max, _kKeep) ? this.max : max as num?,
        sort: sort ?? this.sort,
        q: q ?? this.q,
      );

  @override
  bool operator ==(Object other) =>
      other is LotQuery &&
      other.tab == tab &&
      other.categoryId == categoryId &&
      other.brand == brand &&
      other.min == min &&
      other.max == max &&
      other.sort == sort &&
      other.q == q;

  @override
  int get hashCode => Object.hash(tab, categoryId, brand, min, max, sort, q);
}

const _kKeep = Object();

/// Everything the create flow sends to POST /manage/auctions.
class CreateAuctionRequest {
  const CreateAuctionRequest({
    required this.audience,
    required this.productId,
    required this.title,
    required this.startPrice,
    required this.registrationFee,
    required this.durationHours,
    required this.images,
    this.reservePrice,
    this.buyNowPrice,
    this.bidIncrement,
    this.quantity,
    this.startsAt,
    this.saveAsDraft = false,
    this.videoUrl,
    this.qc,
  });
  final String? videoUrl;
  final QcReport? qc;

  final AuctionAudience audience;
  final String productId;
  final String title;
  final num startPrice;
  final num registrationFee;
  final int durationHours;
  final List<String> images;
  final num? reservePrice;
  final num? buyNowPrice;
  final num? bidIncrement;
  final int? quantity;
  final DateTime? startsAt;
  final bool saveAsDraft;

  Map<String, dynamic> toJson() => {
        'audience': audience.api,
        'productId': productId,
        'title': title,
        'startPrice': startPrice,
        'registrationFee': registrationFee,
        'durationHours': durationHours,
        if (images.isNotEmpty) 'images': images,
        if (images.isNotEmpty) 'imageUrl': images.first,
        if (reservePrice != null) 'reservePrice': reservePrice,
        if (buyNowPrice != null) 'buyNowPrice': buyNowPrice,
        if (bidIncrement != null) 'bidIncrement': bidIncrement,
        if (audience == AuctionAudience.b2b && quantity != null)
          'quantity': quantity,
        if (startsAt != null) 'startsAt': startsAt!.toUtc().toIso8601String(),
        if (saveAsDraft) 'saveAsDraft': true,
        // always sent so removing the video / report really clears it
        'videoUrl': videoUrl,
        'qcReport': qc?.toJson(),
      };
}
