import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';

enum MyOrderKind { wholesale, auction, repair }

enum MoTone { green, amber, blue, red, grey }

/// One line in "My orders": something the vendor BOUGHT or sent for repair
/// (wholesale stock, an auction lot they won, a repair request). Selling-side orders live in "Orders".
class MyOrderEntry {
  const MyOrderEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.tone,
    this.amount,
    this.date,
    this.imageUrl,
    this.needsPayment = false,
    this.code = '',
  });

  final MyOrderKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String status;
  final MoTone tone;
  final num? amount;
  final DateTime? date;
  final String? imageUrl;

  /// An auction win that still has to be paid (opens the Cart).
  final bool needsPayment;
  final String code;

  factory MyOrderEntry.wholesale(DemandOrder o) {
    final (label, tone) = switch (o.status) {
      'PENDING_PAYMENT' => ('Payment pending', MoTone.amber),
      'PAID' => ('Paid · seller packing', MoTone.blue),
      'PACKED' => ('Packed', MoTone.blue),
      'DISPATCHED' => ('On the way', MoTone.blue),
      'DELIVERED' || 'COMPLETED' => ('Delivered', MoTone.green),
      'DISPUTED' => ('Issue reported', MoTone.red),
      'CANCELLED' => ('Cancelled', MoTone.grey),
      'REFUNDED' => ('Refunded', MoTone.grey),
      _ => (o.status, MoTone.grey),
    };
    return MyOrderEntry(
      kind: MyOrderKind.wholesale,
      id: o.id,
      title: o.productName.isEmpty ? 'Order ${o.orderNumber}' : o.productName,
      subtitle: '${o.orderNumber} · ${o.sellerName}',
      status: label,
      tone: tone,
      amount: o.subtotal,
      date: o.createdAt,
      imageUrl: o.thumbnail,
      code: o.orderNumber,
    );
  }

  factory MyOrderEntry.auction(LotView l) {
    final awaiting = l.status == 'AWAITING_PAYMENT' && l.my.orderId == null;
    final (label, tone) = awaiting
        ? ('Pay now', MoTone.amber)
        : switch (l.my.orderStatus) {
            'ORDER_PLACED' => ('Paid · seller confirming', MoTone.blue),
            'CONFIRMED' => ('Confirmed', MoTone.blue),
            'PACKED' || 'READY_TO_SHIP' => ('Packed', MoTone.blue),
            'SHIPPED' || 'OUT_FOR_DELIVERY' => ('On the way', MoTone.blue),
            'DELIVERED' => ('Delivered', MoTone.green),
            'CANCELLED' => ('Cancelled', MoTone.grey),
            _ => l.my.orderId != null
                ? ('Processing', MoTone.blue)
                : ('Won', MoTone.green),
          };
    return MyOrderEntry(
      kind: MyOrderKind.auction,
      id: l.id,
      title: l.title,
      subtitle:
          '${l.my.orderNumber ?? l.number} · ${l.sellerName}',
      status: label,
      tone: tone,
      amount: l.my.amountDue ?? l.finalPrice ?? l.currentPrice,
      date: l.endsAt,
      imageUrl: l.imageUrl,
      needsPayment: awaiting,
      code: l.my.orderNumber ?? l.number,
    );
  }

  factory MyOrderEntry.repair(Map<String, dynamic> j) {
    String s(dynamic v) => v == null ? '' : '$v';
    final status = s(j['status']);
    final (label, tone) = switch (status) {
      'REQUESTED' => ('Waiting for offers', MoTone.amber),
      'ACCEPTED' => ('Accepted', MoTone.blue),
      'INSPECTION' => ('Being inspected', MoTone.blue),
      'ESTIMATE_SENT' => ('Estimate to approve', MoTone.amber),
      'ESTIMATE_APPROVED' => ('Estimate approved', MoTone.blue),
      'IN_REPAIR' => ('Repair in progress', MoTone.blue),
      'QC_PENDING' => ('Quality check', MoTone.blue),
      'REPAIRED' => ('Repaired', MoTone.green),
      'READY_FOR_DELIVERY' => ('Ready for delivery', MoTone.green),
      'COMPLETED' => ('Completed', MoTone.green),
      'CANCELLED' || 'ESTIMATE_REJECTED' => ('Cancelled', MoTone.grey),
      'FAILED' => ('Repair failed', MoTone.red),
      _ => (status.isEmpty ? 'Repair' : status.replaceAll('_', ' ').toLowerCase(), MoTone.grey),
    };
    final total = j['approvedTotal'] ?? j['approved_total'];
    final device = s(j['firstDevice']);
    return MyOrderEntry(
      kind: MyOrderKind.repair,
      id: s(j['id']),
      title: device.isEmpty ? 'Repair request' : device,
      subtitle: s(j['code']),
      status: label,
      tone: tone,
      amount: total is num ? total : num.tryParse(s(total)),
      date: DateTime.tryParse(s(j['createdAt'] ?? j['created_at']))?.toLocal(),
      code: s(j['code']),
    );
  }
}

class MyOrdersData {
  const MyOrdersData({required this.entries, this.failed = const []});
  final List<MyOrderEntry> entries;

  /// Sections that could not be loaded (shown as a small note; the rest still shows).
  final List<String> failed;

  int count(MyOrderKind? k) =>
      k == null ? entries.length : entries.where((e) => e.kind == k).length;
}
