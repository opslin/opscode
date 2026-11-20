num? _n(Object? v) => v is num ? v : num.tryParse('$v');
String _s(Object? v) => v == null ? '' : '$v';

/// A deal (platform promo campaign) a vendor can put its own products into.
class OpenDeal {
  const OpenDeal({
    required this.id,
    required this.name,
    required this.status,
    required this.discountPercent,
    required this.startsAt,
    required this.endsAt,
    required this.entryDeadline,
    required this.minTier,
    required this.requiresApproval,
    required this.maxEntries,
    required this.myEntries,
    required this.myApproved,
    required this.canJoin,
  });

  factory OpenDeal.fromJson(Map<String, dynamic> j) {
    final d = (j['discount'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OpenDeal(
      id: _s(j['id']),
      name: _s(j['name']),
      status: _s(j['status']),
      discountPercent: d['operation'] == 'PERCENT' ? (_n(d['value'])?.abs()) : null,
      startsAt: DateTime.tryParse(_s(j['starts_at']))?.toLocal(),
      endsAt: DateTime.tryParse(_s(j['ends_at']))?.toLocal(),
      entryDeadline: DateTime.tryParse(_s(j['entry_deadline']))?.toLocal(),
      minTier: _s(j['min_vendor_tier']),
      requiresApproval: j['require_approval'] != false,
      maxEntries: _n(j['max_entries_per_vendor'])?.toInt(),
      myEntries: (_n(j['my_entries']) ?? 0).toInt(),
      myApproved: (_n(j['my_approved']) ?? 0).toInt(),
      canJoin: j['can_join'] == true,
    );
  }

  final String id;
  final String name;
  final String status;
  final num? discountPercent;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? entryDeadline;
  final String minTier;
  final bool requiresApproval;
  final int? maxEntries;
  final int myEntries;
  final int myApproved;
  final bool canJoin;
}

/// One of the vendor's products the vendor could put in a deal.
class DealListing {
  const DealListing({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.entryStatus,
  });

  factory DealListing.fromJson(Map<String, dynamic> j) => DealListing(
        id: _s(j['id']),
        name: _s(j['name']),
        price: _n(j['sale_price']) ?? _n(j['price']) ?? 0,
        stock: (_n(j['stock_quantity']) ?? 0).toInt(),
        entryStatus: j['entry_status'] == null ? null : _s(j['entry_status']),
      );

  final String id;
  final String name;
  final num price;
  final int stock;

  /// PENDING / APPROVED / REJECTED / WITHDRAWN, or null when not entered.
  final String? entryStatus;

  bool get inDeal => entryStatus == 'PENDING' || entryStatus == 'APPROVED';
}

/// A product the vendor entered into a deal, with its review status.
class DealEntry {
  const DealEntry({
    required this.id,
    required this.name,
    required this.status,
    required this.rejectReason,
    required this.price,
  });

  factory DealEntry.fromJson(Map<String, dynamic> j) => DealEntry(
        id: _s(j['id']),
        name: _s(j['name']),
        status: _s(j['status']),
        rejectReason: j['reject_reason'] == null ? null : _s(j['reject_reason']),
        price: _n(j['price_at_entry']) ?? 0,
      );

  final String id;
  final String name;
  final String status;
  final String? rejectReason;
  final num price;
}

class OpenDealDetail {
  const OpenDealDetail({required this.deal, required this.entries});
  final OpenDeal deal;
  final List<DealEntry> entries;
}
