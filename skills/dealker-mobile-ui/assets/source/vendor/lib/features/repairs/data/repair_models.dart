// Models for the vendor Repair flow: incoming requests, my quote, the accepted job and my price list.
// Parsing is defensive so a missing field never crashes a screen. Money comes from the server.

num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);
num? _nn(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
String _s(dynamic v) => v == null ? '' : '$v';
DateTime? _d(dynamic v) => DateTime.tryParse(_s(v))?.toLocal();
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => [
      for (final e in (v as List? ?? const []))
        if (e is Map) e.cast<String, dynamic>()
    ];

/// "Apple" + "iPhone 14" → "Apple iPhone 14"; models that already carry the brand ("Samsung S22") stay as they are.
String deviceName(String brand, String model) {
  final b = brand.trim();
  final m = model.trim();
  if (b.isEmpty) return m;
  if (m.toLowerCase().startsWith(b.toLowerCase())) return m;
  return '$b $m'.trim();
}

/// One device on a request (what the customer wants fixed).
class RepairItem {
  const RepairItem({
    required this.id,
    required this.category,
    required this.brand,
    required this.model,
    required this.imei,
    required this.color,
    required this.issues,
    required this.problemText,
    required this.warrantyStatus,
    this.status = '',
    this.diagnosis = '',
  });
  final String id;
  final String category;
  final String brand;
  final String model;
  final String imei;
  final String color;
  final List<String> issues; // backend problem keys: SCREEN, BATTERY …
  final String problemText;
  final String warrantyStatus;
  final String status;
  final String diagnosis;

  String get name => deviceName(brand, model);

  factory RepairItem.fromJson(Map<String, dynamic> j) {
    final issues = [
      for (final e in (j['problemCategories'] as List? ?? const [])) '$e'
    ];
    if (issues.isEmpty && _s(j['problemCategory']).isNotEmpty) {
      issues.add(_s(j['problemCategory']));
    }
    return RepairItem(
      id: _s(j['id']),
      category: _s(j['category']),
      brand: _s(j['brand']),
      model: _s(j['model']),
      imei: _s(j['imeiSerial']),
      color: _s(j['color']),
      issues: issues,
      problemText: _s(j['problemDescription']),
      warrantyStatus: _s(j['warrantyStatus']),
      status: _s(j['status']),
      diagnosis: _s(j['diagnosis']),
    );
  }
}

class QuoteLine {
  const QuoteLine({
    required this.kind,
    required this.description,
    required this.qty,
    required this.unitPrice,
    this.itemId,
    this.issue,
  });
  final String? issue; // backend problem key this line belongs to
  final String kind; // PART | LABOUR | OTHER
  final String description;
  final int qty;
  final num unitPrice;
  final String? itemId;

  num get amount => qty * unitPrice;

  factory QuoteLine.fromJson(Map<String, dynamic> j) => QuoteLine(
        kind: _s(j['kind']),
        description: _s(j['description']),
        qty: _n(j['qty'] ?? 1).toInt(),
        unitPrice: _n(j['unitPrice']),
        itemId: j['itemId'] == null ? null : _s(j['itemId']),
        issue: j['problemCategory'] == null ? null : _s(j['problemCategory']),
      );

  Map<String, dynamic> toJson() => {
        if (itemId != null) 'itemId': itemId,
        if (issue != null) 'problemCategory': issue,
        'kind': kind,
        'description': description,
        'qty': qty,
        'unitPrice': unitPrice,
      };
}

/// This vendor's quote on a request (or the one the customer picked).
class MyOffer {
  const MyOffer({
    required this.status,
    required this.total,
    required this.subtotal,
    required this.taxPct,
    required this.taxAmount,
    required this.lines,
    required this.estDaysMin,
    required this.estDaysMax,
    required this.warrantyDays,
    required this.pickupDelivery,
    required this.shopVisit,
    required this.note,
    this.validUntil,
  });
  final String status; // OPEN | SELECTED | NOT_SELECTED | WITHDRAWN | EXPIRED
  final num total;
  final num subtotal;
  final num taxPct;
  final num taxAmount;
  final List<QuoteLine> lines;
  final int estDaysMin;
  final int estDaysMax;
  final int warrantyDays;
  final bool pickupDelivery;
  final bool shopVisit;
  final String note;
  final DateTime? validUntil;

  factory MyOffer.fromJson(Map<String, dynamic> j) => MyOffer(
        status: _s(j['status']),
        total: _n(j['total']),
        subtotal: _n(j['subtotal']),
        taxPct: _n(j['taxPct']),
        taxAmount: _n(j['taxAmount']),
        lines: [for (final l in _l(j['lines'])) QuoteLine.fromJson(l)],
        estDaysMin: _n(j['estDaysMin']).toInt(),
        estDaysMax: _n(j['estDaysMax']).toInt(),
        warrantyDays: _n(j['warrantyDays']).toInt(),
        pickupDelivery: j['pickupDelivery'] != false,
        shopVisit: j['shopVisit'] != false,
        note: _s(j['note']),
        validUntil: _d(j['validUntil']),
      );
}

class RequestMedia {
  const RequestMedia(this.id, this.type);
  final String id;
  final String type; // IMAGE | VIDEO
}

/// A nearby request waiting for a quote (anonymised until the customer picks a shop).
class IncomingRequest {
  const IncomingRequest({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.offersCloseAt,
    required this.firstName,
    required this.pincode,
    required this.completedRepairs,
    required this.distanceKm,
    required this.description,
    required this.items,
    required this.offer,
    required this.media,
    this.channel = 'B2C',
    this.businessName,
    this.estimateTotal,
    this.estimateComplete = true,
  });
  final String channel;
  final String? businessName;
  final num?
      estimateTotal; // what the shop's own price list says it would cost (with GST)
  final bool estimateComplete;
  final String id;
  final String code;
  final DateTime? createdAt;
  final DateTime? offersCloseAt;
  final String firstName;
  final String pincode;
  final int completedRepairs;
  final num? distanceKm;
  final String description;
  final List<RepairItem> items;
  final MyOffer? offer;
  final List<RequestMedia> media;

  bool get quoted => offer != null && offer!.status != 'WITHDRAWN';
  bool get isBulk => channel == 'B2B' || items.length > 3;
  List<String> get allIssues => {for (final i in items) ...i.issues}.toList();

  factory IncomingRequest.fromJson(Map<String, dynamic> j) {
    final c = _m(j['customer']);
    return IncomingRequest(
      id: _s(j['id']),
      code: _s(j['code']),
      createdAt: _d(j['createdAt']),
      offersCloseAt: _d(j['offersCloseAt']),
      firstName: _s(c['firstName']).isEmpty ? 'Customer' : _s(c['firstName']),
      pincode: _s(c['pincode']),
      completedRepairs: _n(c['completedRepairs']).toInt(),
      distanceKm: _nn(j['distanceKm']),
      description: _s(j['description']),
      items: [for (final i in _l(j['items'])) RepairItem.fromJson(i)],
      offer: j['offer'] is Map ? MyOffer.fromJson(_m(j['offer'])) : null,
      media: [
        for (final m in _l(j['media'])) RequestMedia(_s(m['id']), _s(m['type']))
      ],
      channel: _s(j['channel']).isEmpty ? 'B2C' : _s(j['channel']),
      businessName: j['businessName'] == null ? null : _s(j['businessName']),
      estimateTotal: _nn(_m(j['estimate'])['total']),
      estimateComplete: _m(j['estimate'])['complete'] != false,
    );
  }
}

class IncomingCounts {
  const IncomingCounts(
      {this.fresh = 0,
      this.quoted = 0,
      this.rejected = 0,
      this.accepted = 0,
      this.completed = 0});
  final int fresh;
  final int quoted;
  final int rejected;
  final int accepted;
  final int completed;

  int get pending => fresh + quoted;

  factory IncomingCounts.fromJson(Map<String, dynamic> j) => IncomingCounts(
        fresh: _n(j['new']).toInt(),
        quoted: _n(j['quoted']).toInt(),
        rejected: _n(j['rejected']).toInt(),
        accepted: _n(j['accepted']).toInt(),
        completed: _n(j['completed']).toInt(),
      );
}

class IncomingPage {
  const IncomingPage(this.items, this.counts);
  final List<IncomingRequest> items;
  final IncomingCounts counts;
}

/// Pre-filled quote from the vendor's own price list.
class SuggestedQuote {
  const SuggestedQuote({
    required this.lines,
    required this.missing,
    required this.estDaysMin,
    required this.estDaysMax,
    required this.warrantyDays,
    this.taxPct,
  });
  final num? taxPct;
  final List<QuoteLine> lines;
  final List<({String itemId, String issue})> missing;
  final int estDaysMin;
  final int estDaysMax;
  final int? warrantyDays;

  factory SuggestedQuote.fromJson(Map<String, dynamic> j) => SuggestedQuote(
        lines: [for (final l in _l(j['lines'])) QuoteLine.fromJson(l)],
        missing: [
          for (final m in _l(j['missing']))
            (itemId: _s(m['itemId']), issue: _s(m['problemCategory']))
        ],
        estDaysMin: _n(j['estDaysMin']).toInt(),
        estDaysMax: _n(j['estDaysMax']).toInt(),
        warrantyDays: _nn(j['warrantyDays'])?.toInt(),
        taxPct: _nn(_m(j['totals'])['taxPct']),
      );
}

/// One entry of the job timeline (status steps and technician updates).
class JobEvent {
  const JobEvent({
    required this.kind,
    required this.label,
    required this.at,
    this.issue,
    this.issueStatus,
    this.itemId,
    this.partName,
    this.partPrice,
    this.partWarrantyDays,
    this.checks = const [],
    this.id = 0,
    this.before = const [],
    this.after = const [],
    this.title,
    this.note,
    this.choice,
    this.mismatchId,
  });
  final int id;
  final List<String> before; // media ids
  final List<String> after;
  final String? title; // QC mismatch title
  final String? note;
  final String? choice; // QC_MISMATCH_RESPONSE: APPROVE | REPLACE
  final int? mismatchId;
  final String kind;
  final String label;
  final DateTime? at;
  final String? issue;
  final String? issueStatus; // STARTED | DONE | NOT_NEEDED
  final String? itemId;
  final String? partName;
  final num? partPrice;
  final int? partWarrantyDays;
  final List<({String key, String label, String result})> checks;

  factory JobEvent.fromJson(Map<String, dynamic> j) {
    final p = _m(j['progress']);
    final part = _m(p['part']);
    final ph = _m(p['photos']);
    final resp = _m(j['response']);
    return JobEvent(
      id: _n(j['id']).toInt(),
      before: [for (final e in (ph['before'] as List? ?? const [])) '$e'],
      after: [for (final e in (ph['after'] as List? ?? const [])) '$e'],
      title: p['title'] == null ? null : _s(p['title']),
      note: p['note'] == null ? null : _s(p['note']),
      choice: resp['choice'] == null ? null : _s(resp['choice']),
      mismatchId:
          resp['mismatchId'] == null ? null : _n(resp['mismatchId']).toInt(),
      kind: _s(j['kind']),
      label: _s(j['label']),
      at: _d(j['at']),
      issue: p['issue'] == null ? null : _s(p['issue']),
      issueStatus: p['issueStatus'] == null ? null : _s(p['issueStatus']),
      itemId: p['itemId'] == null ? null : _s(p['itemId']),
      partName: part['name'] == null ? null : _s(part['name']),
      partPrice: _nn(part['price']),
      partWarrantyDays: _nn(part['warrantyDays'])?.toInt(),
      checks: [
        for (final c in _l(p['checks']))
          (key: _s(c['key']), label: _s(c['label']), result: _s(c['result']))
      ],
    );
  }
}

class JobMedia {
  const JobMedia(this.id, this.type, this.stage, this.url);
  final String id;
  final String type;
  final String stage;
  final String url; // signed, relative to the API host
}

/// A repair the customer gave to this shop (status ACCEPTED … COMPLETED).
class RepairJob {
  const RepairJob({
    required this.id,
    required this.code,
    required this.status,
    required this.fulfilment,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.lat,
    required this.lng,
    required this.pincode,
    required this.pickupSlot,
    required this.appointmentAt,
    required this.items,
    required this.quoteLines,
    required this.approvedTotal,
    required this.amountPaid,
    required this.amountDue,
    required this.advanceRequired,
    required this.warrantyUntil,
    required this.timeline,
    required this.media,
    required this.createdAt,
    required this.description,
    this.selectedOffer,
    this.technician,
    this.technicianPhone,
    this.ratingStars,
    this.ratingReview,
    this.unreadMessages = 0,
    this.invoiceId,
    this.channel = 'B2C',
    this.businessName,
    this.quoteSubtotal = 0,
    this.quoteTax = 0,
  });
  final String? technician;
  final String? technicianPhone;
  final int? ratingStars;
  final String? ratingReview;
  final int unreadMessages;
  final String? invoiceId;
  final String channel;
  final String? businessName;
  final num quoteSubtotal;
  final num quoteTax;
  final MyOffer? selectedOffer; // the price the customer agreed to
  final String id;
  final String code;
  final String status;
  final String fulfilment; // PICKUP_DELIVERY | SHOP_VISIT | ''
  final String customerName;
  final String customerPhone;
  final String address;
  final num? lat;
  final num? lng;
  final String pincode;
  final DateTime? pickupSlot;
  final DateTime? appointmentAt;
  final List<RepairItem> items;
  final List<QuoteLine> quoteLines;
  final num approvedTotal;
  final num amountPaid;
  final num amountDue;
  final num advanceRequired;
  final String? warrantyUntil;
  final List<JobEvent> timeline;
  final List<JobMedia> media;
  final DateTime? createdAt;
  final String description;

  bool get isPickup => fulfilment == 'PICKUP_DELIVERY';
  bool get isBulk => channel == 'B2B' || items.length > 3;
  List<JobMedia> get progressMedia => [
        for (final m in media)
          if (m.stage == 'REPAIR_PROGRESS' && m.type != 'VIDEO') m
      ];
  JobMedia? mediaById(String id) {
    for (final m in media) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool has(String kind) => timeline.any((e) => e.kind == kind);
  num get advanceDue =>
      (advanceRequired - amountPaid) > 0 ? advanceRequired - amountPaid : 0;

  /// Latest status the technician set for one repair type on one device.
  String? issueState(String itemId, String issue) {
    for (final e in timeline.reversed) {
      if (e.issue == issue &&
          e.issueStatus != null &&
          (e.itemId == null || e.itemId == itemId)) {
        return e.issueStatus;
      }
    }
    return null;
  }

  JobEvent? issueEvent(String itemId, String issue) {
    for (final e in timeline.reversed) {
      if (e.issue == issue &&
          e.issueStatus == 'DONE' &&
          (e.itemId == null || e.itemId == itemId)) {
        return e;
      }
    }
    return null;
  }

  factory RepairJob.fromJson(Map<String, dynamic> j) {
    final c = _m(j['customer']);
    final money = _m(j['money']);
    final loc = _m(j['location']);
    final quotes = _l(j['quotes']);
    final approved = quotes.firstWhere((q) => _s(q['status']) == 'APPROVED',
        orElse: () => const <String, dynamic>{});
    return RepairJob(
      id: _s(j['id']),
      code: _s(j['code']),
      status: _s(j['status']),
      fulfilment: _s(j['fulfilment']),
      customerName: _s(c['name']),
      customerPhone: _s(c['phone']),
      address: _s(j['pickupAddress']),
      lat: _nn(loc['lat']),
      lng: _nn(loc['lng']),
      pincode: _s(loc['pincode']),
      pickupSlot: _d(j['pickupSlot']),
      appointmentAt: _d(j['appointmentAt']),
      items: [for (final i in _l(j['items'])) RepairItem.fromJson(i)],
      quoteLines: [
        for (final l in _l(approved['lines'])) QuoteLine.fromJson(l)
      ],
      approvedTotal: _n(money['approvedTotal']),
      amountPaid: _n(money['amountPaid']),
      amountDue: _n(money['amountDue']),
      advanceRequired: _n(money['advanceRequired']),
      warrantyUntil: j['warrantyUntil'] == null ? null : _s(j['warrantyUntil']),
      timeline: [for (final e in _l(j['timeline'])) JobEvent.fromJson(e)],
      media: [
        for (final m in _l(j['media']))
          JobMedia(
              _s(m['id']), _s(m['mediaType']), _s(m['stage']), _s(m['url']))
      ],
      createdAt: _d(j['createdAt']),
      description: _s(j['description']),
      technician: j['technician'] == null ? null : _s(j['technician']),
      technicianPhone:
          j['technicianPhone'] == null ? null : _s(j['technicianPhone']),
      ratingStars: _nn(_m(j['rating'])['stars'])?.toInt(),
      ratingReview: _m(j['rating'])['review'] == null
          ? null
          : _s(_m(j['rating'])['review']),
      unreadMessages: _n(j['unreadMessages']).toInt(),
      invoiceId:
          _m(j['invoice'])['id'] == null ? null : _s(_m(j['invoice'])['id']),
      channel: _s(j['channel']).isEmpty ? 'B2C' : _s(j['channel']),
      businessName: _m(j['business'])['name'] == null
          ? null
          : _s(_m(j['business'])['name']),
      quoteSubtotal: _n(approved['subtotal']),
      quoteTax: _n(approved['taxAmount']),
      selectedOffer: j['selectedOffer'] is Map
          ? MyOffer.fromJson({..._m(j['selectedOffer']), 'status': 'SELECTED'})
          : null,
    );
  }

  /// Quote lines the customer agreed to: the confirmed estimate once it exists, else the chosen offer.
  List<QuoteLine> get agreedLines =>
      quoteLines.isNotEmpty ? quoteLines : (selectedOffer?.lines ?? const []);

  num get agreedSubtotal =>
      quoteSubtotal > 0 ? quoteSubtotal : (selectedOffer?.subtotal ?? 0);
  num get agreedTax =>
      quoteSubtotal > 0 ? quoteTax : (selectedOffer?.taxAmount ?? 0);

  /// What the customer pays (server total incl. GST).
  num get agreedTotal =>
      approvedTotal > 0 ? approvedTotal : (selectedOffer?.total ?? 0);

  /// Was this repair part of the price the customer agreed to? (Older quotes carry no repair tags: then everything counts.)
  bool inQuote(String itemId, String issue) =>
      !agreedLines.any((l) => l.issue != null) || priceOf(itemId, issue) > 0;

  /// Price of one repair type on one device (parts + labour lines added up).
  num priceOf(String itemId, String issue) => agreedLines
      .where(
          (l) => l.issue == issue && (l.itemId == null || l.itemId == itemId))
      .fold<num>(0, (a, l) => a + l.amount);
}

String _dedupeFirstWord(String s) {
  final p = s.split(' ');
  return p.length > 1 && p[0].toLowerCase() == p[1].toLowerCase()
      ? p.skip(1).join(' ')
      : s;
}

/// A row in the Accepted list (compact view of a job).
class JobRow {
  const JobRow({
    required this.id,
    required this.code,
    required this.status,
    required this.customerName,
    required this.device,
    required this.deviceCount,
    required this.total,
    required this.createdAt,
    required this.fulfilment,
  });
  final String id;
  final String code;
  final String status;
  final String customerName;
  final String device;
  final int deviceCount;
  final num total;
  final DateTime? createdAt;
  final String fulfilment;

  factory JobRow.fromJson(Map<String, dynamic> j) => JobRow(
        id: _s(j['id']),
        code: _s(j['code']),
        status: _s(j['status']),
        customerName: _s(_m(j['customer'])['name']),
        device: _dedupeFirstWord(_s(j['firstDevice'])),
        deviceCount: _n(j['deviceCount']).toInt(),
        total: _n(
            _m(j['money'])['agreedTotal'] ?? _m(j['money'])['approvedTotal']),
        createdAt: _d(j['createdAt']),
        fulfilment: _s(j['fulfilment']),
      );
}

/// One priced repair in the vendor's own list (device + repair type).
class ServiceRow {
  const ServiceRow({
    required this.id,
    required this.deviceCategory,
    required this.brand,
    required this.model,
    required this.problem,
    required this.title,
    required this.partsPrice,
    required this.labourPrice,
    required this.estDaysMin,
    required this.estDaysMax,
    required this.warrantyDays,
    required this.pickupDelivery,
    required this.isActive,
  });
  final String id;
  final String deviceCategory;
  final String brand;
  final String model;
  final String problem;
  final String title;
  final num partsPrice;
  final num labourPrice;
  final int estDaysMin;
  final int estDaysMax;
  final int warrantyDays;
  final bool pickupDelivery;
  final bool isActive;

  num get total => partsPrice + labourPrice;

  factory ServiceRow.fromJson(Map<String, dynamic> j) => ServiceRow(
        id: _s(j['id']),
        deviceCategory: _s(j['deviceCategory']),
        brand: _s(j['brand']),
        model: _s(j['model']),
        problem: _s(j['problemCategory']),
        title: _s(j['title']),
        partsPrice: _n(j['partsPrice']),
        labourPrice: _n(j['labourPrice']),
        estDaysMin: _n(j['estDaysMin']).toInt(),
        estDaysMax: _n(j['estDaysMax']).toInt(),
        warrantyDays: _n(j['warrantyDays']).toInt(),
        pickupDelivery: j['pickupDelivery'] != false,
        isActive: j['isActive'] != false,
      );
}

class CatalogModel {
  const CatalogModel(this.name, this.category, this.imageUrl);
  final String name;
  final String category;
  final String? imageUrl;
}

class CatalogBrand {
  const CatalogBrand(this.name, this.logoUrl);
  final String name;
  final String? logoUrl;
}

class RepairIssueOption {
  const RepairIssueOption(this.key, this.label);
  final String key;
  final String label;
}

class ChatMessage {
  const ChatMessage(this.id, this.mine, this.body, this.at);
  final int id;
  final bool mine;
  final String body;
  final DateTime? at;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
      _n(j['id']).toInt(), j['mine'] == true, _s(j['body']), _d(j['at']));
}
