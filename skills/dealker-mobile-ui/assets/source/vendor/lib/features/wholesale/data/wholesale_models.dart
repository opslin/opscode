num _n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
num? _nn(dynamic v) => v == null ? null : _n(v);
Map<String, dynamic> _m(dynamic v) =>
    (v as Map?)?.cast<String, dynamic>() ?? const {};

class WholesaleSeller {
  const WholesaleSeller(
      {required this.id,
      required this.name,
      this.city,
      this.rating,
      this.reviews = 0});
  factory WholesaleSeller.fromJson(Map<String, dynamic> j) => WholesaleSeller(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? 'Seller'}',
        city: (j['city'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['city'] as String,
        rating: _nn(j['rating']),
        reviews: _n(j['reviews']).toInt(),
      );
  final String id;
  final String name;
  final String? city;
  final num? rating;
  final int reviews;
}

/// One wholesale listing on the shelf (another vendor's B2B stock).
class WholesaleItem {
  const WholesaleItem({
    required this.id,
    required this.name,
    required this.price,
    required this.moq,
    required this.stock,
    required this.seller,
    this.brand,
    this.condition,
    this.thumbnail,
    this.storage,
    this.retailPrice,
    this.discountPct,
    this.batteryHealth,
    this.productId,
  });

  factory WholesaleItem.fromJson(Map<String, dynamic> j) => WholesaleItem(
        id: '${j['id'] ?? ''}',
        productId: j['product_id'] as String?,
        name: '${j['name'] ?? ''}',
        brand: j['brand'] as String?,
        condition: j['condition'] as String?,
        thumbnail: j['thumbnail_url'] as String?,
        storage: j['storage'] as String?,
        price: _n(j['wholesale_price']),
        retailPrice: _nn(j['retail_price']),
        moq: _n(j['moq']).toInt().clamp(1, 1 << 30),
        stock: _n(j['stock']).toInt(),
        discountPct: _nn(j['discount_pct']),
        batteryHealth: _nn(j['battery_health']),
        seller: WholesaleSeller.fromJson(_m(j['seller'])),
      );

  final String id;
  final String name;
  final String? brand;
  final String? condition;
  final String? thumbnail;
  final String? storage;
  final num price;
  final num? retailPrice;
  final int moq;
  final int stock;
  final num? discountPct;
  final num? batteryHealth;
  final String? productId;
  final WholesaleSeller seller;

  /// Open box / refurbished / used stock is bought device by device (each has its own QC).
  bool get deviceTracked => productId != null && condition != null && condition != 'NEW';
}

/// One selectable value in a filter (a brand or a condition) with how many listings carry it.
class FacetOption {
  const FacetOption(this.value, this.count);
  factory FacetOption.fromJson(Map<String, dynamic> j) =>
      FacetOption('${j['value'] ?? ''}', _n(j['count']).toInt());
  final String value;
  final int count;
}

class WholesalePage {
  const WholesalePage({
    required this.items,
    required this.total,
    this.brands = const [],
    this.conditions = const [],
  });
  final List<WholesaleItem> items;
  final int total;
  final List<FacetOption> brands;
  final List<FacetOption> conditions;
}

class WholesaleDetail {
  const WholesaleDetail({
    required this.item,
    required this.images,
    this.description,
    this.conditionNotes,
    this.warranty,
    this.notes,
    this.handlingDays,
    this.productId,
    this.highlights = const [],
    this.specs = const [],
  });

  factory WholesaleDetail.fromJson(Map<String, dynamic> j) {
    List<String> hl() {
      final h = j['highlights'];
      if (h is! Map) return const [];
      return [
        for (final e in h.entries)
          if ('${e.value}'.trim().isNotEmpty)
            int.tryParse('${e.key}') != null ? '${e.value}' : '${e.key}: ${e.value}'
      ];
    }

    List<({String label, String value})> sp() {
      final s = j['specifications'];
      if (s is! Map) return const [];
      return [
        for (final e in s.entries)
          if ('${e.value}'.trim().isNotEmpty && e.key != 'product_type')
            (label: '${e.key}'.isEmpty ? '' : '${e.key}'[0].toUpperCase() + '${e.key}'.substring(1), value: '${e.value}')
      ];
    }

    return WholesaleDetail._(j, hl(), sp());
  }

  factory WholesaleDetail._(Map<String, dynamic> j, List<String> highlights,
          List<({String label, String value})> specs) =>
      WholesaleDetail(
        productId: j['product_id'] as String?,
        highlights: highlights,
        specs: specs,
        item: WholesaleItem.fromJson(j),
        images:
            ((j['images'] as List?) ?? const []).whereType<String>().toList(),
        description: j['description'] as String?,
        conditionNotes: j['condition_notes'] as String?,
        warranty: j['warranty_info'] as String?,
        notes: j['notes'] as String?,
        handlingDays:
            j['handling_days'] == null ? null : _n(j['handling_days']).toInt(),
      );

  final WholesaleItem item;
  final List<String> images;
  final String? description;
  final String? conditionNotes;
  final String? warranty;
  final String? notes;
  final int? handlingDays;
  final String? productId;
  final List<String> highlights;
  final List<({String label, String value})> specs;
}

/// What the server returns after "Buy": an order waiting for payment.
class WholesaleOrder {
  const WholesaleOrder(
      {required this.requirementId,
      required this.orderId,
      required this.orderNumber,
      required this.total});
  factory WholesaleOrder.fromJson(Map<String, dynamic> j) => WholesaleOrder(
        requirementId: '${j['requirement_id']}',
        orderId: '${j['order_id']}',
        orderNumber: '${j['order_number'] ?? ''}',
        total: _n(j['total']),
      );
  final String requirementId;
  final String orderId;
  final String orderNumber;
  final num total;
}

/// One node of the wholesale category tree (`count` includes sub-categories).
class WholesaleCategory {
  const WholesaleCategory(
      {required this.id,
      required this.name,
      required this.count,
      this.imageUrl,
      this.children = const []});

  factory WholesaleCategory.fromJson(Map<String, dynamic> j) =>
      WholesaleCategory(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        count: _n(j['count']).toInt(),
        imageUrl: j['image_url'] as String?,
        children: ((j['children'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WholesaleCategory.fromJson)
            .toList(),
      );

  final String id;
  final String name;
  final int count;
  final String? imageUrl;
  final List<WholesaleCategory> children;
}

/// Condition tiers the marketplace is organised by: brand new, refurbished, used.
enum ConditionTier { brandNew, refurbished, used }

ConditionTier conditionTier(String? c) => switch (c) {
      'REFURBISHED' => ConditionTier.refurbished,
      'USED_LIKE_NEW' || 'USED_GOOD' || 'USED_FAIR' => ConditionTier.used,
      _ => ConditionTier.brandNew,
    };

/// Server `condition` filter value (comma list) for a tier.
String tierFilter(ConditionTier t) => switch (t) {
      ConditionTier.brandNew => 'NEW,OPEN_BOX',
      ConditionTier.refurbished => 'REFURBISHED',
      ConditionTier.used => 'USED_LIKE_NEW,USED_GOOD,USED_FAIR',
    };

String tierLabel(ConditionTier t) => switch (t) {
      ConditionTier.brandNew => 'Brand new',
      ConditionTier.refurbished => 'Refurbished',
      ConditionTier.used => 'Used',
    };

/// Badge text for a listing, e.g. "Brand new", "Open box", "Refurbished", "Used · Good".
String conditionBadge(String? c) => switch (c) {
      'OPEN_BOX' => 'Open box',
      'REFURBISHED' => 'Refurbished',
      'USED_LIKE_NEW' => 'Used · Like new',
      'USED_GOOD' => 'Used · Good',
      'USED_FAIR' => 'Used · Fair',
      _ => 'Brand new',
    };
