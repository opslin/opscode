import 'package:dealker_vendor/features/repairs/data/repair_models.dart';

/// One repair type on one device, as the vendor prices it ("Battery problem — ₹1,800").
class DraftRow {
  DraftRow({
    required this.itemId,
    required this.deviceName,
    required this.issue,
    this.selected = true,
    this.parts = 0,
    this.labour = 0,
    this.fromPriceList = false,
  });
  final String itemId;
  final String deviceName;
  final String issue;
  bool selected;
  num parts;
  num labour;
  final bool fromPriceList;

  num get price => parts + labour;

  /// The vendor types one price; keep the labour share and put the rest on the part.
  void setPrice(num total) {
    if (labour <= total) {
      parts = total - labour;
    } else {
      labour = total;
      parts = 0;
    }
  }
}

/// What the vendor has decided so far, carried from "Set Repair Price" to "Send Offer".
class OfferDraft {
  OfferDraft({
    required this.requestId,
    required this.rows,
    required this.devices,
    this.estMin = 1,
    this.estMax = 2,
    this.warrantyDays = 90,
    this.pickupDelivery = true,
    this.shopVisit = true,
    this.note = '',
    this.taxPct,
  });
  final String requestId;
  final List<DraftRow> rows;
  final List<RepairItem> devices;
  int estMin;
  int estMax;
  int warrantyDays;
  bool pickupDelivery;
  bool shopVisit;
  String note;
  final num? taxPct;

  Iterable<DraftRow> get chosen => rows.where((r) => r.selected && r.price > 0);
  num get subtotal => chosen.fold<num>(0, (a, r) => a + r.price);
  num get partsTotal => chosen.fold<num>(0, (a, r) => a + r.parts);
  num get labourTotal => chosen.fold<num>(0, (a, r) => a + r.labour);

  List<QuoteLine> toLines(String Function(String issue) labelOf) => [
        for (final r in chosen) ...[
          if (r.parts > 0)
            QuoteLine(
                kind: 'PART',
                description:
                    '${r.deviceName} — ${labelOf(r.issue)}${r.labour > 0 ? ' (parts)' : ''}',
                qty: 1,
                unitPrice: r.parts,
                itemId: r.itemId,
                issue: r.issue),
          if (r.labour > 0)
            QuoteLine(
                kind: 'LABOUR',
                description:
                    '${r.deviceName} — ${labelOf(r.issue)}${r.parts > 0 ? ' (labour)' : ''}',
                qty: 1,
                unitPrice: r.labour,
                itemId: r.itemId,
                issue: r.issue),
        ],
      ];

  /// Every device must keep at least one priced repair (the server refuses an unpriced device).
  bool get everyDevicePriced =>
      devices.every((d) => chosen.any((r) => r.itemId == d.id));
}

/// Identical devices on one request (same model and same problems) are priced together: "iPhone 15 Pro × 3".
class DeviceGroup {
  DeviceGroup(this.items);
  final List<RepairItem> items;
  RepairItem get first => items.first;
  int get qty => items.length;
}

List<DeviceGroup> groupDevices(List<RepairItem> items) {
  final map = <String, List<RepairItem>>{};
  for (final i in items) {
    final sig =
        '${i.brand.toLowerCase()}|${i.model.toLowerCase()}|${(List.of(i.issues)..sort()).join(',')}';
    map.putIfAbsent(sig, () => []).add(i);
  }
  return [for (final g in map.values) DeviceGroup(g)];
}
