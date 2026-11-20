/// Models for the sell-your-phone flow. Every price, range and status comes from the server; the app only
/// sends answers (see `docs` in dealker-backend `modules/sell-requests`).
library;

double? _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
DateTime? _t(Object? v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();
List<String> _strings(Object? v) =>
    v is List ? v.map((Object? e) => '$e').toList() : <String>[];

class ImeiCheckItem {
  const ImeiCheckItem({
    required this.key,
    required this.label,
    required this.status,
    this.message,
  });
  factory ImeiCheckItem.fromJson(Map<String, dynamic> j) => ImeiCheckItem(
        key: '${j['key']}',
        label: '${j['label']}',
        status: '${j['status']}',
        message: j['message'] as String?,
      );
  final String key;
  final String label;

  /// PASS | FAIL | WARN | INFO
  final String status;
  final String? message;
}

class ImeiCheck {
  const ImeiCheck({
    required this.checkId,
    required this.imei,
    required this.eligible,
    required this.checks,
  });
  factory ImeiCheck.fromJson(Map<String, dynamic> j) => ImeiCheck(
        checkId: '${j['checkId']}',
        imei: '${j['imei']}',
        eligible: j['eligible'] == true,
        checks: (j['checks'] as List? ?? <Object?>[])
            .whereType<Map>()
            .map(
              (Map e) => ImeiCheckItem.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );
  final String checkId;
  final String imei;
  final bool eligible;
  final List<ImeiCheckItem> checks;
}

class SellConfig {
  const SellConfig({
    required this.enabled,
    required this.offerWindowMinutes,
    required this.pickupEnabled,
    required this.dropoffEnabled,
    required this.pickupWindows,
    required this.maxImages,
    this.hubBannerUrl,
    this.hubStepIcons = const <String>[],
  });
  factory SellConfig.fromJson(Map<String, dynamic> j) => SellConfig(
        enabled: j['enabled'] != false,
        offerWindowMinutes: (j['offerWindowMinutes'] as num?)?.toInt() ?? 60,
        pickupEnabled: j['pickupEnabled'] != false,
        dropoffEnabled: j['dropoffEnabled'] != false,
        pickupWindows: _strings(j['pickupWindows']),
        maxImages: (j['maxImages'] as num?)?.toInt() ?? 6,
        hubBannerUrl: (j['hubBannerUrl'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['hubBannerUrl'] as String).trim(),
        hubStepIcons: _strings(j['hubStepIcons']),
      );

  /// Admin-uploaded artwork for the Sell landing page; empty = the app's built-in art.
  final String? hubBannerUrl;
  final List<String> hubStepIcons;
  final bool enabled;
  final int offerWindowMinutes;
  final bool pickupEnabled;
  final bool dropoffEnabled;
  final List<String> pickupWindows;
  final int maxImages;
}

class SellEstimate {
  const SellEstimate({
    required this.quote,
    required this.condition,
    required this.estimateMin,
    required this.estimateMax,
    required this.vendorsNearby,
    required this.offerWindowMinutes,
    required this.deductions,
  });
  factory SellEstimate.fromJson(Map<String, dynamic> j) => SellEstimate(
        quote: _d(j['quote']) ?? 0,
        condition: '${j['condition']}',
        estimateMin: _d(j['estimateMin']) ?? 0,
        estimateMax: _d(j['estimateMax']) ?? 0,
        vendorsNearby: (j['vendorsNearby'] as num?)?.toInt() ?? 0,
        offerWindowMinutes: (j['offerWindowMinutes'] as num?)?.toInt() ?? 60,
        deductions: (j['deductions'] as List? ?? <Object?>[])
            .whereType<Map>()
            .map((Map e) => '${e['label']}')
            .toList(),
      );
  final double quote;
  final String condition;
  final double estimateMin;
  final double estimateMax;
  final int vendorsNearby;
  final int offerWindowMinutes;
  final List<String> deductions;

  String get conditionLabel => switch (condition) {
        'EXCELLENT' => 'Excellent',
        'GOOD' => 'Good',
        'FAIR' => 'Fair',
        _ => 'Poor',
      };
}

class SellOffer {
  const SellOffer({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.amount,
    required this.rating,
    required this.best,
    this.city,
    this.distanceKm,
    this.note,
    this.status = 'OPEN',
    this.unread = 0,
  });
  factory SellOffer.fromJson(Map<String, dynamic> j) => SellOffer(
        id: '${j['id']}',
        vendorId: '${j['vendorId']}',
        vendorName: '${j['vendorName']}',
        amount: _d(j['amount']) ?? 0,
        rating: _d(j['rating']) ?? 0,
        best: j['best'] == true,
        city: j['city'] as String?,
        distanceKm: _d(j['distanceKm']),
        note: j['note'] as String?,
        status: '${j['status']}',
        unread: (j['unread'] as num?)?.toInt() ?? 0,
      );
  final int unread;
  final String id;
  final String vendorId;
  final String vendorName;
  final double amount;
  final double rating;
  final bool best;
  final String? city;
  final double? distanceKm;
  final String? note;
  final String status;
}

class SellOffers {
  const SellOffers({
    required this.requestId,
    required this.code,
    required this.estimateMin,
    required this.estimateMax,
    required this.closesAt,
    required this.open,
    required this.refreshesLeft,
    required this.offers,
    this.askingPrice,
  });
  factory SellOffers.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> est = Map<String, dynamic>.from(
      (j['estimate'] as Map?) ?? <String, dynamic>{},
    );
    return SellOffers(
      requestId: '${j['requestId']}',
      code: '${j['code']}',
      estimateMin: _d(est['min']),
      estimateMax: _d(est['max']),
      closesAt: _t(j['offersCloseAt']),
      open: j['open'] == true,
      refreshesLeft: (j['refreshesLeft'] as num?)?.toInt() ?? 0,
      askingPrice: _d(j['askingPrice']),
      offers: (j['offers'] as List? ?? <Object?>[])
          .whereType<Map>()
          .map((Map e) => SellOffer.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
  final String requestId;
  final String code;
  final double? estimateMin;
  final double? estimateMax;
  final DateTime? closesAt;
  final bool open;
  final int refreshesLeft;
  final List<SellOffer> offers;

  /// What the customer asked for.
  final double? askingPrice;
}

class JourneyStep {
  const JourneyStep({
    required this.key,
    required this.label,
    required this.done,
    required this.current,
    this.at,
  });
  factory JourneyStep.fromJson(Map<String, dynamic> j) => JourneyStep(
        key: '${j['key']}',
        label: '${j['label']}',
        done: j['done'] == true,
        current: j['current'] == true,
        at: _t(j['at']),
      );
  final String key;
  final String label;
  final bool done;
  final bool current;
  final DateTime? at;
}

class PayoutOption {
  const PayoutOption({
    required this.method,
    required this.enabled,
    required this.label,
    required this.hint,
  });
  factory PayoutOption.fromJson(Map<String, dynamic> j) => PayoutOption(
        method: '${j['method']}',
        enabled: j['enabled'] == true,
        label: '${j['label']}',
        hint: '${j['hint'] ?? ''}',
      );
  final String method;
  final bool enabled;
  final String label;
  final String hint;
}

/// The customer's view of one sale (`GET /sell-requests/:id/journey`).
class SellJourney {
  const SellJourney({
    required this.stage,
    required this.status,
    required this.nextAction,
    required this.steps,
    required this.ended,
    this.estimateMin,
    this.estimateMax,
    this.offersCloseAt,
    this.agreedPrice,
    this.buyerName,
    this.buyerPhone,
    this.buyerAddress,
    this.fulfilmentMode,
    this.pickupAddress,
    this.pickupDate,
    this.pickupWindow,
    this.courier,
    this.awb,
    this.trackingUrl,
    this.pickupStatus,
    this.finalValuation,
    this.originalPrice,
    this.customerDecision,
    this.payoutMethod,
    this.payoutDisplay,
    this.payoutStatus,
    this.payoutAmount,
    this.payoutRef,
    this.paidAt,
    this.vendorPaymentStatus,
    this.payoutOptions = const <PayoutOption>[],
  });

  factory SellJourney.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? m(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    final Map<String, dynamic>? est = m(j['estimate']);
    final Map<String, dynamic>? buyer = m(j['buyer']);
    final Map<String, dynamic>? ful = m(j['fulfilment']);
    final Map<String, dynamic>? pk = m(j['pickup']);
    final Map<String, dynamic>? insp = m(j['inspection']);
    final Map<String, dynamic>? pay = m(j['payout']);
    final Map<String, dynamic>? vp = m(j['vendorPayment']);
    return SellJourney(
      stage: '${j['stage']}',
      status: '${j['status']}',
      nextAction: '${j['nextAction']}',
      ended: j['ended'] == true,
      steps: (j['steps'] as List? ?? <Object?>[])
          .whereType<Map>()
          .map((Map e) => JourneyStep.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      estimateMin: _d(est?['min']),
      estimateMax: _d(est?['max']),
      offersCloseAt: _t(j['offersCloseAt']),
      agreedPrice: _d(j['agreedPrice']),
      buyerName: buyer?['name'] as String?,
      buyerPhone: buyer?['phone'] as String?,
      buyerAddress: buyer?['address'] as String?,
      fulfilmentMode: ful?['mode'] as String?,
      pickupAddress: ful?['address'] as String?,
      pickupDate: ful?['date'] as String?,
      pickupWindow: ful?['window'] as String?,
      courier: (pk?['courier'] ?? pk?['provider']) as String?,
      awb: pk?['awb'] as String?,
      trackingUrl: pk?['trackingUrl'] as String?,
      pickupStatus: pk?['status'] as String?,
      finalValuation: _d(insp?['finalValuation']),
      originalPrice: _d(insp?['originalPrice']),
      customerDecision: insp?['customerDecision'] as String?,
      payoutMethod: pay?['method'] as String?,
      payoutDisplay: pay?['display'] as String?,
      payoutStatus: pay?['status'] as String?,
      payoutAmount: _d(pay?['amount']),
      payoutRef: pay?['receiptRef'] as String?,
      paidAt: _t(pay?['paidAt']),
      vendorPaymentStatus: vp?['status'] as String?,
      payoutOptions: (j['payoutOptions'] as List? ?? <Object?>[])
          .whereType<Map>()
          .map((Map e) => PayoutOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  final String stage;
  final String status;
  final String nextAction;
  final List<JourneyStep> steps;
  final bool ended;
  final double? estimateMin;
  final double? estimateMax;
  final DateTime? offersCloseAt;
  final double? agreedPrice;
  final String? buyerName;
  final String? buyerPhone;
  final String? buyerAddress;
  final String? fulfilmentMode;
  final String? pickupAddress;
  final String? pickupDate;
  final String? pickupWindow;
  final String? courier;
  final String? awb;
  final String? trackingUrl;
  final String? pickupStatus;
  final double? finalValuation;
  final double? originalPrice;
  final String? customerDecision;
  final String? payoutMethod;
  final String? payoutDisplay;
  final String? payoutStatus;
  final double? payoutAmount;
  final String? payoutRef;
  final DateTime? paidAt;
  final String? vendorPaymentStatus;
  final List<PayoutOption> payoutOptions;
}

/// A row of "My sales".
class SellListItem {
  const SellListItem({
    required this.id,
    required this.code,
    required this.status,
    required this.model,
    required this.variant,
    required this.quote,
    required this.createdAt,
    this.finalPrice,
    this.stage,
    this.nextAction,
    this.askingPrice,
    this.imageUrl,
    this.offerCount = 0,
    this.bestOffer,
    this.unreadMessages = 0,
    this.offersOpen = true,
  });
  factory SellListItem.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> dev =
        Map<String, dynamic>.from((j['device'] as Map?) ?? <String, dynamic>{});
    final Map<String, dynamic>? jr = j['journey'] is Map
        ? Map<String, dynamic>.from(j['journey'] as Map)
        : null;
    return SellListItem(
      id: '${j['id']}',
      code: '${j['code']}',
      status: '${j['status']}',
      model: '${dev['model'] ?? ''}',
      variant: '${dev['variant'] ?? ''}',
      quote: _d(j['quote']) ?? 0,
      finalPrice: _d(j['finalPrice']),
      createdAt: _t(j['createdAt']),
      stage: (j['stage'] ?? jr?['stage']) as String?,
      nextAction: jr?['nextAction'] as String?,
      askingPrice: _d(j['askingPrice']),
      imageUrl: j['imageUrl'] as String?,
      offerCount: (j['offerCount'] as num?)?.toInt() ?? 0,
      bestOffer: _d(j['bestOffer']),
      unreadMessages: (j['unreadMessages'] as num?)?.toInt() ?? 0,
      offersOpen: j['offersOpen'] != false,
    );
  }
  final String id;
  final String code;
  final String status;
  final String model;
  final String variant;
  final double quote;
  final double? finalPrice;
  final DateTime? createdAt;
  final String? stage;
  final String? nextAction;

  /// The price the customer asked for (their own, not the system's suggestion).
  final double? askingPrice;
  final String? imageUrl;
  final int offerCount;
  final double? bestOffer;
  final int unreadMessages;

  /// False once the waiting time for offers is over.
  final bool offersOpen;
}

/// One buyer the customer can talk to about a listing.
class SellThreadSummary {
  const SellThreadSummary({
    required this.vendorId,
    required this.vendorName,
    required this.unread,
    required this.canReply,
    this.city,
    this.rating = 0,
    this.offerAmount,
    this.offerStatus,
    this.lastMessage,
    this.lastFromMe = false,
    this.lastAt,
  });
  factory SellThreadSummary.fromJson(Map<String, dynamic> j) =>
      SellThreadSummary(
        vendorId: '${j['vendorId']}',
        vendorName: '${j['vendorName']}',
        city: j['city'] as String?,
        rating: _d(j['rating']) ?? 0,
        offerAmount: _d(j['offerAmount']),
        offerStatus: j['offerStatus'] as String?,
        lastMessage: j['lastMessage'] as String?,
        lastFromMe: j['lastFrom'] == 'ME',
        lastAt: _t(j['lastAt']),
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        canReply: j['canReply'] != false,
      );
  final String vendorId;
  final String vendorName;
  final String? city;
  final double rating;
  final double? offerAmount;
  final String? offerStatus;
  final String? lastMessage;
  final bool lastFromMe;
  final DateTime? lastAt;
  final int unread;
  final bool canReply;
}

class SellChatMessage {
  const SellChatMessage({
    required this.id,
    required this.mine,
    required this.body,
    required this.at,
  });
  factory SellChatMessage.fromJson(Map<String, dynamic> j) => SellChatMessage(
        id: (j['id'] as num?)?.toInt() ?? 0,
        mine: j['from'] == 'ME',
        body: '${j['body']}',
        at: _t(j['at']),
      );
  final int id;
  final bool mine;
  final String body;
  final DateTime? at;
}

/// A conversation with one buyer, plus that buyer's offer.
class SellThread {
  const SellThread({
    required this.requestId,
    required this.vendorId,
    required this.vendorName,
    required this.canReply,
    required this.messages,
    this.city,
    this.rating = 0,
    this.offerId,
    this.offerAmount,
    this.offerStatus,
    this.offerNote,
    this.lockedReason,
  });
  factory SellThread.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> v =
        Map<String, dynamic>.from((j['vendor'] as Map?) ?? <String, dynamic>{});
    final Map<String, dynamic>? o =
        j['offer'] is Map ? Map<String, dynamic>.from(j['offer'] as Map) : null;
    return SellThread(
      requestId: '${j['requestId']}',
      vendorId: '${v['id']}',
      vendorName: '${v['name']}',
      city: v['city'] as String?,
      rating: _d(v['rating']) ?? 0,
      offerId: o?['id'] as String?,
      offerAmount: _d(o?['amount']),
      offerStatus: o?['status'] as String?,
      offerNote: o?['note'] as String?,
      canReply: j['canReply'] != false,
      lockedReason: j['lockedReason'] as String?,
      messages: (j['messages'] as List? ?? <Object?>[])
          .whereType<Map>()
          .map(
            (Map e) => SellChatMessage.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
  final String requestId;
  final String vendorId;
  final String vendorName;
  final String? city;
  final double rating;
  final String? offerId;
  final double? offerAmount;
  final String? offerStatus;
  final String? offerNote;
  final bool canReply;
  final String? lockedReason;
  final List<SellChatMessage> messages;
}
