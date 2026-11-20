import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Typed views over the repair API payloads (`/api/v1/repairs`). Every field the
/// server may leave out is nullable; screens hide what is missing.

double? _num(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
int? _int(dynamic v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
String? _str(dynamic v) {
  final String s = '${v ?? ''}'.trim();
  return s.isEmpty || s == 'null' ? null : s;
}

DateTime? _date(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _maps(dynamic v) => <Map<String, dynamic>>[
      if (v is List)
        for (final dynamic e in v)
          if (e is Map) Map<String, dynamic>.from(e),
    ];

// ── issues ─────────────────────────────────────────────────────────────────

/// A problem the customer can pick; [label] is the server's service name.
class RepairIssue {
  const RepairIssue(this.key, this.label);

  final String key;
  final String label;

  /// Short tile name, as in the design ("Screen", "Battery", …).
  String get tile => issueTileName(key, label);
}

String issueTileName(String key, [String fallback = '']) => switch (key) {
      'SCREEN' => 'Screen',
      'BATTERY' => 'Battery',
      'CHARGING' => 'Charging',
      'WATER_DAMAGE' => 'Water damage',
      'CAMERA' => 'Camera',
      'AUDIO' => 'Speaker / mic',
      'SOFTWARE' => 'Software',
      'TOUCH' => 'Touch',
      'NETWORK' => 'Network / SIM',
      'BODY' => 'Back panel',
      'BOARD' => 'Motherboard',
      'BIOMETRIC' => 'Face ID / fingerprint',
      'DATA' => 'Data recovery',
      'OTHER' => 'Other',
      _ => fallback,
    };

/// Wording on the problems step ("Cracked screen", "Battery drains", …).
String issueProblemName(String key, [String fallback = '']) => switch (key) {
      'SCREEN' => 'Cracked screen',
      'BATTERY' => 'Battery drains',
      'TOUCH' => 'Touch not working',
      'CHARGING' => 'Won’t charge',
      'WATER_DAMAGE' => 'Water damage',
      'CAMERA' => 'Camera',
      'AUDIO' => 'Speaker / mic',
      'SOFTWARE' => 'Software',
      'NETWORK' => 'Network / SIM',
      'OTHER' => 'Other',
      _ => issueTileName(key, fallback),
    };

PhosphorIconData issueIcon(String key) => switch (key) {
      'SCREEN' => PhosphorIconsRegular.deviceMobile,
      'BATTERY' => PhosphorIconsRegular.batteryHigh,
      'CHARGING' => PhosphorIconsRegular.lightning,
      'WATER_DAMAGE' => PhosphorIconsRegular.drop,
      'CAMERA' => PhosphorIconsRegular.camera,
      'AUDIO' => PhosphorIconsRegular.speakerHigh,
      'SOFTWARE' => PhosphorIconsRegular.gear,
      'TOUCH' => PhosphorIconsRegular.handTap,
      'NETWORK' => PhosphorIconsRegular.cellSignalFull,
      'BODY' => PhosphorIconsRegular.deviceMobile,
      'BOARD' => PhosphorIconsRegular.cpu,
      'BIOMETRIC' => PhosphorIconsRegular.fingerprint,
      'DATA' => PhosphorIconsRegular.database,
      _ => PhosphorIconsRegular.dotsThreeOutline,
    };

// ── offers ─────────────────────────────────────────────────────────────────

class OfferLine {
  const OfferLine({
    required this.description,
    required this.qty,
    required this.unitPrice,
    this.kind,
  });

  factory OfferLine.fromJson(Map<String, dynamic> j) => OfferLine(
        description: _str(j['description']) ?? _str(j['label']) ?? 'Repair',
        qty: _num(j['qty']) ?? 1,
        unitPrice: _num(j['unitPrice']) ?? 0,
        kind: _str(j['kind']),
      );

  final String description;
  final double qty;
  final double unitPrice;
  final String? kind;

  double get amount => qty * unitPrice;
}

class RepairOffer {
  const RepairOffer({
    required this.id,
    required this.vendorName,
    required this.total,
    required this.status,
    required this.expired,
    required this.lines,
    required this.badges,
    required this.pickupDelivery,
    required this.shopVisit,
    this.address,
    this.rating,
    this.ratingCount = 0,
    this.completedRepairs = 0,
    this.subtotal,
    this.taxAmount,
    this.estDaysMin,
    this.estDaysMax,
    this.warrantyDays,
    this.distanceKm,
    this.note,
    this.validUntil,
    this.mrpTotal,
  });

  factory RepairOffer.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> v = _map(j['vendor']);
    return RepairOffer(
      id: '${j['id']}',
      vendorName: _str(v['shopName']) ?? _str(v['name']) ?? 'Repair shop',
      address: _str(v['address']),
      rating: _num(v['rating']),
      ratingCount: _int(v['ratingCount']) ?? 0,
      completedRepairs: _int(v['completedRepairs']) ?? 0,
      total: _num(j['total']) ?? 0,
      subtotal: _num(j['subtotal']),
      taxAmount: _num(j['taxAmount']),
      status: _str(j['status']) ?? 'OPEN',
      expired: j['expired'] == true,
      lines: _maps(j['lines']).map(OfferLine.fromJson).toList(growable: false),
      badges: <String>[
        if (j['badges'] is List)
          for (final dynamic b in j['badges'] as List) '$b',
      ],
      pickupDelivery: j['pickupDelivery'] == true,
      shopVisit: j['shopVisit'] == true,
      estDaysMin: _int(j['estDaysMin']),
      estDaysMax: _int(j['estDaysMax']),
      warrantyDays: _int(j['warrantyDays']),
      distanceKm: _num(j['distanceKm']),
      note: _str(j['note']),
      validUntil: _date(j['validUntil']),
      mrpTotal: _num(j['mrpTotal']),
    );
  }

  /// The shop's original price before its offer discount (shown struck through).
  final double? mrpTotal;
  final String id;
  final String vendorName;
  final String? address;
  final double? rating;
  final int ratingCount;
  final int completedRepairs;
  final double total;
  final double? subtotal;
  final double? taxAmount;
  final String status;
  final bool expired;
  final List<OfferLine> lines;
  final List<String> badges;
  final bool pickupDelivery;
  final bool shopVisit;
  final int? estDaysMin;
  final int? estDaysMax;
  final int? warrantyDays;
  final double? distanceKm;
  final String? note;
  final DateTime? validUntil;

  bool get hasDiscount => mrpTotal != null && mrpTotal! > total + 0.5;
  int get discountPct =>
      hasDiscount ? (((mrpTotal! - total) * 100) / mrpTotal!).round() : 0;

  bool get selected => status == 'SELECTED';
  bool get usable => !expired && (status == 'OPEN' || status == 'SELECTED');
  bool get isLowestPrice => badges.contains('LOWEST_PRICE');
  bool get isBestDeal => badges.contains('BEST_DEAL');
  bool get hasRating => rating != null && ratingCount > 0;

  /// "1–2 days", "1 day"; null when the shop gave no estimate.
  String? get timeLabel {
    final int? a = estDaysMin, b = estDaysMax;
    if (a == null && b == null) return null;
    final int lo = a ?? b!, hi = b ?? a!;
    if (lo == hi) return lo == 1 ? '1 day' : '$lo days';
    return '$lo–$hi days';
  }

  /// "3 months", "1 year"; null when there is no warranty.
  String? get warrantyLabel => warrantyText(warrantyDays);

  /// "1.2 km", "850 m".
  String? get distanceLabel {
    final double? d = distanceKm;
    if (d == null) return null;
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }
}

String? warrantyText(int? days) {
  if (days == null || days <= 0) return null;
  if (days >= 360) {
    final int y = (days / 365).round();
    return y <= 1 ? '1 year' : '$y years';
  }
  if (days >= 28) {
    final int m = (days / 30).round();
    return m <= 1 ? '1 month' : '$m months';
  }
  return days == 1 ? '1 day' : '$days days';
}

/// Offers of one request with the server's own ordering.
class RepairOffers {
  const RepairOffers({
    required this.requestId,
    required this.status,
    required this.offers,
    this.offersCloseAt,
    this.lowestTotal,
  });

  factory RepairOffers.fromJson(Map<String, dynamic> j) => RepairOffers(
        requestId: '${j['requestId']}',
        status: _str(j['status']) ?? '',
        offersCloseAt: _date(j['offersCloseAt']),
        lowestTotal: _num(j['lowestTotal']),
        offers: _maps(j['offers'])
            .map(RepairOffer.fromJson)
            .toList(growable: false),
      );

  final String requestId;
  final String status;
  final DateTime? offersCloseAt;
  final double? lowestTotal;
  final List<RepairOffer> offers;

  List<RepairOffer> get usable =>
      offers.where((RepairOffer o) => o.usable).toList(growable: false);
}

// ── requests ───────────────────────────────────────────────────────────────

class RepairDevice {
  const RepairDevice({
    this.id = '',
    required this.brand,
    required this.model,
    required this.issues,
    this.category,
    this.color,
    this.description,
    this.imei,
    this.diagnosis,
  });

  factory RepairDevice.fromJson(Map<String, dynamic> j) => RepairDevice(
        id: '${j['id'] ?? ''}',
        brand: _str(j['brand']) ?? '',
        model: _str(j['model']) ?? '',
        category: _str(j['category']),
        color: _str(j['color']),
        description: _str(j['problemDescription']),
        imei: _str(j['imeiSerial']),
        diagnosis: _str(j['diagnosis']),
        issues: <String>[
          if (j['problemCategories'] is List)
            for (final dynamic p in j['problemCategories'] as List) '$p',
        ],
      );

  final String id;
  final String brand;
  final String model;
  final String? category;
  final String? color;
  final String? description;
  final String? imei;
  final String? diagnosis;
  final List<String> issues;

  String get name => model.toLowerCase().startsWith(brand.toLowerCase())
      ? model.trim()
      : '$brand $model'.trim();

  /// "Screen + battery", as the design words it.
  String get issuesLabel => issuesText(issues);
}

String issuesText(List<String> keys) {
  final List<String> names =
      keys.map((String k) => issueTileName(k, k)).toList();
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  final String joined =
      names.map((String s) => s.toLowerCase()).toList().join(' + ');
  return '${joined[0].toUpperCase()}${joined.substring(1)}';
}

class RepairQuote {
  const RepairQuote({
    required this.version,
    required this.status,
    required this.total,
    required this.lines,
    this.note,
    this.validUntil,
    this.expired = false,
  });

  factory RepairQuote.fromJson(Map<String, dynamic> j) => RepairQuote(
        version: _int(j['version']) ?? 1,
        status: _str(j['status']) ?? '',
        total: _num(j['total']) ?? 0,
        lines:
            _maps(j['lines']).map(OfferLine.fromJson).toList(growable: false),
        note: _str(j['note']),
        validUntil: _date(j['validUntil']),
        expired: j['expired'] == true,
      );

  final int version;
  final String status;
  final double total;
  final List<OfferLine> lines;
  final String? note;
  final DateTime? validUntil;
  final bool expired;
}

class RepairMoney {
  const RepairMoney({
    this.approvedTotal = 0,
    this.advanceRequired = 0,
    this.amountPaid = 0,
    this.amountDue = 0,
  });

  factory RepairMoney.fromJson(Map<String, dynamic> j) => RepairMoney(
        approvedTotal: _num(j['approvedTotal']) ?? 0,
        advanceRequired: _num(j['advanceRequired']) ?? 0,
        amountPaid: _num(j['amountPaid']) ?? 0,
        amountDue: _num(j['amountDue']) ?? 0,
      );

  final double approvedTotal;
  final double advanceRequired;
  final double amountPaid;
  final double amountDue;
}

class RepairPayment {
  const RepairPayment({
    required this.kind,
    required this.amount,
    this.method,
    this.at,
  });

  factory RepairPayment.fromJson(Map<String, dynamic> j) => RepairPayment(
        kind: _str(j['kind']) ?? '',
        amount: _num(j['amount']) ?? 0,
        method: _str(j['method']),
        at: _date(j['at']),
      );

  final String kind;
  final double amount;
  final String? method;
  final DateTime? at;
}

/// One progress note from the shop: "Battery replacement completed — part: Battery (original), 3 months warranty".
class RepairUpdate {
  const RepairUpdate({
    required this.label,
    required this.at,
    this.issue,
    this.issueStatus,
    this.partName,
    this.partWarrantyDays,
    this.before = const <String>[],
    this.after = const <String>[],
    this.itemId,
    this.checks = const <RepairCheck>[],
  });

  factory RepairUpdate.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> p = _map(j['progress']);
    final Map<String, dynamic> part = _map(p['part']);
    final Map<String, dynamic> ph = _map(p['photos']);
    List<String> ids(dynamic v) => <String>[
          if (v is List)
            for (final dynamic e in v) '$e',
        ];
    return RepairUpdate(
      label: _str(j['label']) ?? '',
      at: _date(j['at']),
      issue: _str(p['issue']),
      issueStatus: _str(p['issueStatus']),
      partName: _str(part['name']),
      partWarrantyDays: _int(part['warrantyDays']),
      before: ids(ph['before']),
      after: ids(ph['after']),
      itemId: _str(p['itemId']),
      checks: <RepairCheck>[
        if (p['checks'] is List)
          for (final dynamic c in p['checks'] as List)
            if (c is Map)
              RepairCheck('${c['key']}', '${c['label']}', '${c['result']}'),
      ],
    );
  }

  final String label;
  final DateTime? at;
  final String? issue;
  final String? issueStatus; // STARTED | DONE | NOT_NEEDED
  final String? partName;
  final int? partWarrantyDays;
  final List<String> before; // media ids
  final List<String> after;
  final String? itemId;
  final List<RepairCheck> checks;

  bool get done => issueStatus == 'DONE';
}

/// One line of the shop's device check: "Battery health — LOW".
class RepairCheck {
  const RepairCheck(this.key, this.label, this.result);

  final String key;
  final String label;
  final String result; // PASS | LOW | ISSUE

  bool get pass => result == 'PASS';
}

/// A problem the shop found at QC, and what the customer decided.
class RepairMismatch {
  const RepairMismatch(
      {required this.id, required this.title, this.note, this.choice, this.at});

  final int id;
  final String title;
  final String? note;
  final String? choice; // APPROVE | REPLACE once answered
  final DateTime? at;

  bool get open => choice == null;
}

class RepairRequest {
  const RepairRequest({
    required this.id,
    required this.code,
    required this.status,
    required this.devices,
    required this.quotes,
    required this.payments,
    required this.money,
    required this.createdAt,
    this.flow,
    this.fulfilment,
    this.offerCount = 0,
    this.offersCloseAt,
    this.selectedOfferId,
    this.appointmentAt,
    this.pickupSlot,
    this.pickupAddress,
    this.pincode,
    this.serviceCenter,
    this.warrantyUntil,
    this.ratingStars,
    this.ratingReview,
    this.note,
    this.description,
    this.updates = const <RepairUpdate>[],
    this.progressPhotos = const <String>[],
    this.mediaUrls = const <String, String>{},
    this.mismatches = const <RepairMismatch>[],
    this.technician,
    this.technicianPhone,
    this.unreadMessages = 0,
    this.invoiceId,
    this.channel = 'B2C',
    this.businessName,
    this.deviceCount = 1,
  });

  factory RepairRequest.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> r = _map(j['rating']);
    return RepairRequest(
      id: '${j['id']}',
      code: _str(j['code']) ?? '',
      status: _str(j['status']) ?? '',
      flow: _str(j['flow']),
      fulfilment: _str(j['fulfilment']),
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
      offerCount: _int(j['offerCount']) ?? 0,
      offersCloseAt: _date(j['offersCloseAt']),
      selectedOfferId: _str(j['selectedOfferId']),
      appointmentAt: _date(j['appointmentAt']),
      pickupSlot: _date(j['pickupSlot']),
      pickupAddress: _str(j['pickupAddress']),
      pincode: _str(_map(j['location'])['pincode']),
      serviceCenter: _str(j['serviceCenter']),
      warrantyUntil: _str(j['warrantyUntil']),
      ratingStars: _int(r['stars']),
      ratingReview: _str(r['review']),
      note: _str(j['note']),
      description: _str(j['description']),
      updates: _maps(j['timeline'])
          .where((Map<String, dynamic> e) => e['kind'] == 'TECH_UPDATE')
          .map(RepairUpdate.fromJson)
          .toList(growable: false),
      mediaUrls: <String, String>{
        for (final Map<String, dynamic> m in _maps(j['media']))
          if (_str(m['url']) != null) '${m['id']}': _str(m['url'])!,
      },
      mismatches: _mismatches(_maps(j['timeline'])),
      technician: _str(j['technician']),
      technicianPhone: _str(j['technicianPhone']),
      unreadMessages: _int(j['unreadMessages']) ?? 0,
      invoiceId: _str(_map(j['invoice'])['id']),
      channel: _str(j['channel']) ?? 'B2C',
      businessName: _str(_map(j['business'])['name']),
      deviceCount: _int(j['deviceCount']) ?? 1,
      progressPhotos: <String>[
        for (final Map<String, dynamic> m in _maps(j['media']))
          if (m['stage'] == 'REPAIR_PROGRESS' &&
              m['mediaType'] != 'VIDEO' &&
              _str(m['url']) != null)
            _str(m['url'])!,
      ],
      money: RepairMoney.fromJson(_map(j['money'])),
      devices:
          _maps(j['items']).map(RepairDevice.fromJson).toList(growable: false),
      quotes:
          _maps(j['quotes']).map(RepairQuote.fromJson).toList(growable: false),
      payments: _maps(j['payments'])
          .map(RepairPayment.fromJson)
          .toList(growable: false),
    );
  }

  /// Row of `GET /repairs/mine`: the same shape, but `items` is empty and the
  /// first device comes as a single "Brand Model" string.
  factory RepairRequest.fromListJson(Map<String, dynamic> j) {
    final RepairRequest base = RepairRequest.fromJson(j);
    if (base.devices.isNotEmpty) return base;
    final String? first = _str(j['firstDevice']);
    if (first == null) return base;
    final List<String> parts = first.split(' ');
    return RepairRequest(
      id: base.id,
      code: base.code,
      status: base.status,
      flow: base.flow,
      fulfilment: base.fulfilment,
      createdAt: base.createdAt,
      offerCount: base.offerCount,
      offersCloseAt: base.offersCloseAt,
      selectedOfferId: base.selectedOfferId,
      appointmentAt: base.appointmentAt,
      pickupSlot: base.pickupSlot,
      pickupAddress: base.pickupAddress,
      pincode: base.pincode,
      serviceCenter: base.serviceCenter,
      warrantyUntil: base.warrantyUntil,
      ratingStars: base.ratingStars,
      note: base.note,
      description: base.description,
      money: base.money,
      devices: <RepairDevice>[
        RepairDevice(
          brand: parts.first,
          model: parts.skip(1).join(' '),
          issues: const <String>[],
        ),
      ],
      quotes: base.quotes,
      payments: base.payments,
      channel: base.channel,
      businessName: base.businessName,
      deviceCount: base.deviceCount,
      technician: base.technician,
    );
  }

  final String id;
  final String code;
  final String status;
  final String? flow;
  final String? fulfilment;
  final DateTime createdAt;
  final int offerCount;
  final DateTime? offersCloseAt;
  final String? selectedOfferId;
  final DateTime? appointmentAt;
  final DateTime? pickupSlot;
  final String? pickupAddress;
  final String? pincode;

  /// Name of the shop chosen for the repair.
  final String? serviceCenter;
  final String? warrantyUntil;
  final int? ratingStars;
  final String? ratingReview;
  final String? note;
  final String? description;

  /// What the shop reported while repairing (newest last), and the photos it attached.
  final List<RepairUpdate> updates;
  final List<String> progressPhotos;
  final Map<String, String> mediaUrls; // media id → signed relative url
  final List<RepairMismatch> mismatches;
  final String? technician;
  final String? technicianPhone;
  final int unreadMessages;
  final String? invoiceId;
  final String channel;
  final String? businessName;
  final int deviceCount;

  bool get isBulk => channel == 'B2B' || deviceCount > 3;

  /// Repairs finished out of all repairs asked for (every device × every problem).
  ({int done, int total}) get repairProgress {
    final int total =
        devices.fold<int>(0, (int a, RepairDevice d) => a + d.issues.length);
    final Set<String> done = <String>{
      for (final RepairUpdate u in updates)
        if (u.done && u.itemId != null && u.issue != null)
          '${u.itemId}|${u.issue}',
    };
    return (done: done.length, total: total);
  }

  /// The latest device check the shop recorded (for the first device that has one).
  List<RepairCheck> get latestChecks {
    for (final RepairUpdate u in updates.reversed) {
      if (u.checks.isNotEmpty) return u.checks;
    }
    return const <RepairCheck>[];
  }

  final RepairMoney money;
  final List<RepairDevice> devices;
  final List<RepairQuote> quotes;
  final List<RepairPayment> payments;

  RepairDevice? get device => devices.isEmpty ? null : devices.first;
  String get deviceName =>
      isBulk ? '$deviceCount devices' : (device?.name ?? 'Your device');

  /// Every problem named on the request (union over all devices), in first-seen order.
  List<String> get allIssues => <String>{
        for (final RepairDevice d in devices) ...d.issues
      }.toList(growable: false);
  bool get isMarketplace => flow == 'MARKETPLACE';
  bool get isPickup => fulfilment == 'PICKUP_DELIVERY';
  bool get isStore => fulfilment == 'SHOP_VISIT';
  bool get awaitingOffers => status == 'REQUESTED';
  bool get cancelled => status == 'CANCELLED' || status == 'REJECTED';
  bool get completed => status == 'COMPLETED';
  bool get revisedPricePending => status == 'ESTIMATE_SENT';
  bool get ready => status == 'READY_FOR_DELIVERY' || status == 'REPAIRED';

  /// Cancelling is only possible before the device reaches the shop.
  bool get canCancel =>
      const <String>{'REQUESTED', 'ACCEPTED'}.contains(status);

  /// The shop's latest estimate that waits for the customer.
  RepairQuote? get pendingQuote {
    for (final RepairQuote q in quotes) {
      if (q.status == 'SENT') return q;
    }
    return null;
  }

  /// The price the customer agreed to before the revision (the approved total or
  /// the previous accepted quote).
  double? get agreedTotal {
    for (final RepairQuote q in quotes) {
      if (q.status == 'APPROVED' || q.status == 'ACCEPTED') return q.total;
    }
    return money.approvedTotal > 0 ? money.approvedTotal : null;
  }

  RepairStep get journeyStep {
    if (completed) return RepairStep.done;
    if (awaitingOffers) {
      return offerCount > 0 || offersCloseAt != null
          ? RepairStep.quotes
          : RepairStep.request;
    }
    if (status == 'ACCEPTED') return RepairStep.book;
    return RepairStep.repair;
  }
}

enum RepairStep { request, quotes, book, repair, done }

// ── tracking ───────────────────────────────────────────────────────────────

class TrackStep {
  const TrackStep({
    required this.key,
    required this.label,
    required this.done,
    required this.current,
    this.at,
    this.meta,
  });

  factory TrackStep.fromJson(Map<String, dynamic> j) => TrackStep(
        key: _str(j['key']) ?? '',
        label: _str(j['label']) ?? '',
        done: j['done'] == true,
        current: j['current'] == true,
        at: _date(j['at']),
        meta: j['meta'] is Map
            ? Map<String, dynamic>.from(j['meta'] as Map)
            : null,
      );

  final String key;
  final String label;
  final bool done;
  final bool current;
  final DateTime? at;
  final Map<String, dynamic>? meta;
}

class RepairTracking {
  const RepairTracking({
    required this.code,
    required this.status,
    required this.closed,
    required this.steps,
    this.fulfilment,
    this.note,
    this.pickupSlot,
    this.appointmentAt,
    this.shopName,
    this.shopPhone,
    this.technician,
    this.warrantyUntil,
  });

  factory RepairTracking.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> sc = _map(j['serviceCenter']);
    return RepairTracking(
      code: _str(j['code']) ?? '',
      status: _str(j['status']) ?? '',
      closed: j['closed'] == true,
      fulfilment: _str(j['fulfilment']),
      note: _str(j['note']),
      pickupSlot: _date(j['pickupSlot']),
      appointmentAt: _date(j['appointmentAt']),
      shopName: _str(sc['name']),
      shopPhone: _str(sc['phone']),
      technician: _str(sc['technician']),
      warrantyUntil: _str(j['warrantyUntil']),
      steps: _maps(j['steps']).map(TrackStep.fromJson).toList(growable: false),
    );
  }

  final String code;
  final String status;
  final bool closed;
  final String? fulfilment;
  final String? note;
  final DateTime? pickupSlot;
  final DateTime? appointmentAt;
  final String? shopName;
  final String? shopPhone;
  final String? technician;
  final String? warrantyUntil;
  final List<TrackStep> steps;

  /// Courier details recorded at "Out for delivery", only when the shop sent them.
  Map<String, dynamic>? get courier {
    for (final TrackStep s in steps) {
      if (s.key == 'OUT_FOR_DELIVERY' && s.meta != null) {
        final Map<String, dynamic> m = s.meta!;
        if (_str(m['courier']) != null ||
            _str(m['trackingUrl']) != null ||
            _str(m['trackingId']) != null) {
          return m;
        }
      }
    }
    return null;
  }
}

List<RepairMismatch> _mismatches(List<Map<String, dynamic>> timeline) {
  final Map<int, String> answers = <int, String>{
    for (final Map<String, dynamic> e in timeline)
      if (e['kind'] == 'QC_MISMATCH_RESPONSE')
        if (_int(_map(e['response'])['mismatchId']) != null)
          _int(_map(e['response'])['mismatchId'])!:
              '${_map(e['response'])['choice']}',
  };
  return <RepairMismatch>[
    for (final Map<String, dynamic> e in timeline)
      if (e['kind'] == 'QC_MISMATCH')
        RepairMismatch(
          id: _int(e['id']) ?? 0,
          title: _str(_map(e['progress'])['title']) ??
              _str(e['label']) ??
              'Mismatch found',
          note: _str(_map(e['progress'])['note']),
          choice: answers[_int(e['id']) ?? 0],
          at: _date(e['at']),
        ),
  ];
}
