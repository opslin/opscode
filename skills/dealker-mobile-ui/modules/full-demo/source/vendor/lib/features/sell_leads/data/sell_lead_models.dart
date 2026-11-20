/// Customers selling a phone, as a buyer (vendor) sees them. The server hides the customer's identity
/// until an offer is accepted and shows a vendor only its own offer.
num? _n(Object? v) => v is num ? v : num.tryParse('$v');
String _s(Object? v) => v == null ? '' : '$v';

class SellLead {
  const SellLead({
    required this.id,
    required this.code,
    required this.status,
    required this.stage,
    required this.model,
    required this.variant,
    required this.color,
    required this.condition,
    required this.askingPrice,
    required this.systemValue,
    required this.description,
    required this.imageCount,
    required this.createdAt,
    this.myOffer,
    this.myOfferStatus,
    this.note,
    this.deal,
  });

  factory SellLead.fromJson(Map<String, dynamic> j) {
    final dev = (j['device'] as Map?)?.cast<String, dynamic>() ?? const {};
    final offers = (j['offers'] as List? ?? const []).whereType<Map>().toList();
    final mine = offers.isEmpty ? null : offers.first.cast<String, dynamic>();
    return SellLead(
      id: _s(j['id']),
      code: _s(j['code']),
      status: _s(j['status']),
      stage: _s(j['stage']),
      model: _s(dev['model']),
      variant: _s(dev['variant']),
      color: _s(dev['color']),
      condition: _s(j['condition']),
      askingPrice: _n(j['expectedPrice']),
      systemValue: _n(j['quote']),
      description: _s(j['description']),
      imageCount: (_n(j['imageCount']) ?? 0).toInt(),
      createdAt: DateTime.tryParse(_s(j['createdAt']))?.toLocal(),
      myOffer: _n(mine?['amount']),
      myOfferStatus: mine == null ? null : _s(mine['status']),
      note: mine == null ? null : _s(mine['note']),
      deal: j['journey'] is Map && j['customer'] is Map
          ? SellDeal.fromJson(
              (j['journey'] as Map).cast<String, dynamic>(),
              (j['customer'] as Map).cast<String, dynamic>(),
              j['device'] is Map
                  ? (j['device'] as Map)['imei'] as String?
                  : null)
          : null,
    );
  }

  final String id;
  final String code;
  final String status;
  final String stage;
  final String model;
  final String variant;
  final String color;
  final String condition;

  /// What the customer wants (their own price).
  final num? askingPrice;

  /// Dealkr's suggested value — a guide only.
  final num? systemValue;
  final String description;
  final int imageCount;
  final DateTime? createdAt;
  final num? myOffer;
  final String? myOfferStatus;
  final String? note;

  /// Everything after an offer is accepted (payment, pickup, inspection, payout). Null before that.
  final SellDeal? deal;

  String get title => variant.isEmpty ? model : '$model · $variant';
  bool get open => status == 'PENDING' || status == 'IN_PROGRESS';
}

class SellLeadPage {
  const SellLeadPage({required this.items, required this.total});
  final List<SellLead> items;
  final int total;
}

class LeadMessage {
  const LeadMessage(
      {required this.id,
      required this.mine,
      required this.body,
      required this.at});
  factory LeadMessage.fromJson(Map<String, dynamic> j) => LeadMessage(
        id: (_n(j['id']) ?? 0).toInt(),
        mine: j['from'] == 'ME',
        body: _s(j['body']),
        at: DateTime.tryParse(_s(j['at']))?.toLocal(),
      );
  final int id;
  final bool mine;
  final String body;
  final DateTime? at;
}

class LeadThread {
  const LeadThread(
      {required this.canReply, required this.messages, this.lockedReason});
  factory LeadThread.fromJson(Map<String, dynamic> j) => LeadThread(
        canReply: j['canReply'] != false,
        lockedReason: j['lockedReason'] as String?,
        messages: (j['messages'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => LeadMessage.fromJson(m.cast<String, dynamic>()))
            .toList(),
      );
  final bool canReply;
  final String? lockedReason;
  final List<LeadMessage> messages;
}

/// A sale the seller accepted from this buyer: what to pay, where to collect the phone, what happens next.
class SellDeal {
  const SellDeal({
    required this.stage,
    required this.nextAction,
    required this.agreedPrice,
    required this.paymentStatus,
    required this.heldAmount,
    required this.steps,
    required this.sellerName,
    required this.sellerPhone,
    this.imei,
    this.fulfilment,
    this.pickup,
    this.inspectionStatus,
    this.finalValuation,
    this.customerDecision,
    this.payoutStatus,
    this.payoutAmount,
    this.ended = false,
  });

  factory SellDeal.fromJson(
      Map<String, dynamic> j, Map<String, dynamic> cust, String? imei) {
    final vp =
        (j['vendorPayment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ins = (j['inspection'] as Map?)?.cast<String, dynamic>();
    final pay = (j['payout'] as Map?)?.cast<String, dynamic>();
    final ful = (j['fulfilment'] as Map?)?.cast<String, dynamic>();
    final pk = (j['pickup'] as Map?)?.cast<String, dynamic>();
    return SellDeal(
      stage: _s(j['stage']),
      nextAction: _s(j['nextAction']),
      agreedPrice: _n(j['agreedPrice']),
      paymentStatus: _s(vp['status']),
      heldAmount: _n(vp['heldAmount']) ?? 0,
      steps: (j['steps'] as List? ?? const [])
          .whereType<Map>()
          .map((m) =>
              DealStep(_s(m['label']), m['done'] == true, m['current'] == true))
          .toList(),
      sellerName: _s(cust['name']),
      sellerPhone: _s(cust['phone']),
      imei: imei,
      fulfilment: ful == null ? null : DealFulfilment.fromJson(ful),
      pickup: pk == null ? null : DealPickup.fromJson(pk),
      inspectionStatus: ins == null ? null : _s(ins['status']),
      finalValuation: _n(ins?['finalValuation']),
      customerDecision: ins == null ? null : _s(ins['customerDecision']),
      payoutStatus: pay == null ? null : _s(pay['status']),
      payoutAmount: _n(pay?['amount']),
      ended: j['ended'] == true,
    );
  }

  final String stage;
  final String nextAction;
  final num? agreedPrice;

  /// NONE | PENDING | SUBMITTED | HELD | REFUNDING | REFUNDED
  final String paymentStatus;
  final num heldAmount;
  final List<DealStep> steps;
  final String sellerName;
  final String sellerPhone;
  final String? imei;
  final DealFulfilment? fulfilment;
  final DealPickup? pickup;
  final String? inspectionStatus;
  final num? finalValuation;
  final String? customerDecision;
  final String? payoutStatus;
  final num? payoutAmount;
  final bool ended;

  bool get needsPayment =>
      paymentStatus == 'PENDING' || paymentStatus == 'SUBMITTED';
  bool get funded =>
      paymentStatus == 'HELD' ||
      paymentStatus == 'REFUNDING' ||
      paymentStatus == 'REFUNDED';
}

class DealStep {
  const DealStep(this.label, this.done, this.current);
  final String label;
  final bool done;
  final bool current;
}

class DealFulfilment {
  const DealFulfilment(
      {required this.mode,
      this.address,
      this.pincode,
      this.date,
      this.window,
      this.note});
  factory DealFulfilment.fromJson(Map<String, dynamic> j) => DealFulfilment(
        mode: _s(j['mode']),
        address: j['address'] as String?,
        pincode: j['pincode'] as String?,
        date: j['date'] as String?,
        window: j['window'] as String?,
        note: j['note'] as String?,
      );
  final String mode;
  final String? address;
  final String? pincode;
  final String? date;
  final String? window;
  final String? note;
  bool get pickup => mode == 'PICKUP';
}

class DealPickup {
  const DealPickup(
      {required this.status,
      this.provider,
      this.awb,
      this.courier,
      this.trackingUrl,
      this.auto = false,
      this.simulated = false});
  factory DealPickup.fromJson(Map<String, dynamic> j) => DealPickup(
        status: _s(j['status']),
        provider: j['provider'] as String?,
        awb: j['awb'] as String?,
        courier: j['courier'] as String?,
        trackingUrl: j['trackingUrl'] as String?,
        auto: j['auto'] == true,
        simulated: j['simulated'] == true,
      );
  final String status;

  /// Booked by Dealkr's system (Shiprocket) rather than typed in by the buyer.
  final bool auto;

  /// Demo pickup (no real courier).
  final bool simulated;
  final String? provider;
  final String? awb;
  final String? courier;
  final String? trackingUrl;
}

/// What Razorpay Checkout needs to open.
class RazorpayOrder {
  const RazorpayOrder(
      {required this.keyId,
      required this.orderId,
      required this.amount,
      required this.description});
  factory RazorpayOrder.fromJson(Map<String, dynamic> j) => RazorpayOrder(
        keyId: _s(j['keyId']),
        orderId: _s(j['orderId']),
        amount: (_n(j['amount']) ?? 0).toInt(),
        description: _s(j['description']),
      );
  final String keyId;
  final String orderId;

  /// In paise.
  final int amount;
  final String description;
}
