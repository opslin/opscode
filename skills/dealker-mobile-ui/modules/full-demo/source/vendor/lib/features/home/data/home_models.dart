// Plain models for the Partner Hub home. Field names follow the real API
// responses (snake_case from seller-orders / b2b / auctions / ads, camelCase
// from sell-requests); parsing is defensive so a missing field never crashes.

num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
int _i(dynamic v) => _n(v)?.toInt() ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';

class PagedTotal<T> {
  const PagedTotal({required this.items, required this.total});
  final List<T> items;
  final int total;
}

class SellerOrderRow {
  const SellerOrderRow(
      {required this.id,
      required this.number,
      required this.itemCount,
      required this.status,
      this.createdAt});
  final String id;
  final String number;
  final int itemCount;
  final String status;
  final DateTime? createdAt;

  factory SellerOrderRow.fromJson(Map<String, dynamic> j) => SellerOrderRow(
        id: _s(j['id']),
        number: _s(j['seller_order_number']),
        itemCount: _i(j['item_count']),
        status: _s(j['status']),
        createdAt: DateTime.tryParse(_s(j['created_at']))?.toLocal(),
      );
}

class B2bRequirementRow {
  const B2bRequirementRow({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.city,
    this.createdAt,
  });
  final String id;
  final String productName;
  final int quantity;
  final String city;
  final DateTime? createdAt;

  factory B2bRequirementRow.fromJson(Map<String, dynamic> j) =>
      B2bRequirementRow(
        id: _s(j['id']),
        productName: _s(j['product_name']).isEmpty
            ? _s(j['title'])
            : _s(j['product_name']),
        quantity: _i(j['quantity_needed']),
        city: _s(j['delivery_city']),
        createdAt: DateTime.tryParse(_s(j['created_at']))?.toLocal(),
      );
}

class SellRequestRow {
  const SellRequestRow({
    required this.id,
    required this.model,
    required this.condition,
    required this.expectedPrice,
    this.createdAt,
    this.imageUrl,
  });
  final String id;
  final String model;
  final String condition;
  final num? expectedPrice;
  final DateTime? createdAt;
  /// First photo the customer uploaded, if any (the row falls back to a phone icon).
  final String? imageUrl;

  factory SellRequestRow.fromJson(Map<String, dynamic> j) => SellRequestRow(
        id: _s(j['id']),
        model: _s((j['device'] as Map?)?['model']),
        condition: _s(j['condition']),
        expectedPrice: _n(j['expectedPrice']),
        createdAt: DateTime.tryParse(_s(j['createdAt']))?.toLocal(),
        imageUrl: _firstImage(j['images']),
      );

  static String? _firstImage(dynamic v) {
    if (v is! List) return null;
    for (final e in v) {
      final u = e is String ? e : (e is Map ? '${e['url'] ?? ''}' : '');
      if (u.startsWith('http')) return u;
    }
    return null;
  }
}

class AuctionRow {
  const AuctionRow({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.bidCount,
    required this.endsAt,
    required this.audience,
  });
  final String id;
  final String title;
  final String? imageUrl;
  final int bidCount;
  final DateTime? endsAt;
  final String audience;

  factory AuctionRow.fromJson(Map<String, dynamic> j) => AuctionRow(
        id: _s(j['id']),
        title: _s(j['title']),
        imageUrl: j['imageUrl'] as String? ?? j['image_url'] as String?,
        bidCount: _i(j['bidCount'] ?? j['bid_count']),
        endsAt: DateTime.tryParse(_s(j['endsAt'] ?? j['ends_at']))?.toLocal(),
        audience: _s(j['audience']),
      );
}

class CampaignRow {
  const CampaignRow(
      {required this.id,
      required this.name,
      required this.status,
      required this.spentToday,
      required this.dailyBudget});
  final String id;
  final String name;
  final String status;
  final num spentToday;
  final num dailyBudget;

  factory CampaignRow.fromJson(Map<String, dynamic> j) => CampaignRow(
        id: _s(j['id']),
        name: _s(j['name']),
        status: _s(j['status']),
        spentToday: _n(j['spent_today']) ?? 0,
        dailyBudget: _n(j['daily_budget']) ?? 0,
      );
}

class WalletSummary {
  const WalletSummary(
      {required this.available, required this.nextPayout, this.paid = 0});
  final num available;
  final num nextPayout;

  /// Lifetime amount already paid out to the vendor.
  final num paid;

  factory WalletSummary.fromJson(Map<String, dynamic> j) => WalletSummary(
      available: _n(j['available']) ?? 0,
      nextPayout: _n(j['nextPayout']) ?? 0,
      paid: _n(j['paid']) ?? 0);
}

class AuctionStats {
  const AuctionStats({required this.live, required this.endingSoon});
  final int live;
  final int endingSoon;

  factory AuctionStats.fromJson(Map<String, dynamic> j) =>
      AuctionStats(live: _i(j['live']), endingSoon: _i(j['ending_soon']));
}
