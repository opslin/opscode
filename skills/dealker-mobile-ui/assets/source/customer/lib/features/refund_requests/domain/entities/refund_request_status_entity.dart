/// One uploaded proof file on a return request.
class ReturnEvidence {
  const ReturnEvidence({required this.url, required this.isVideo});

  final String url;
  final bool isVideo;
}

/// One step of the customer-facing return journey (server-built from real timestamps).
class ReturnTimelineStep {
  const ReturnTimelineStep({
    required this.key,
    required this.title,
    this.at,
    this.current = false,
  });

  /// REQUESTED, UNDER_REVIEW, APPROVED, REFUNDED, REJECTED or CANCELLED.
  final String key;
  final String title;
  final DateTime? at;
  final bool current;
}

/// Courier pickup of the returned item (Shiprocket / Porter / our team). Status steps only — no live map.
class ReturnPickup {
  const ReturnPickup({
    required this.status,
    this.provider,
    this.awb,
    this.courierName,
    this.trackingUrl,
    this.scheduledAt,
    this.pickedUpAt,
    this.receivedAt,
  });

  /// PICKUP_SCHEDULED, PICKED_UP, IN_TRANSIT, RECEIVED, FAILED or CANCELLED.
  final String status;
  final String? provider;
  final String? awb;
  final String? courierName;
  final String? trackingUrl;
  final DateTime? scheduledAt;
  final DateTime? pickedUpAt;
  final DateTime? receivedAt;

  bool get isFailed => status == 'FAILED' || status == 'CANCELLED';
}

/// One line of the quality-check report.
class ReturnQcCheck {
  const ReturnQcCheck({required this.label, required this.status, this.note});

  final String label;

  /// OK, MINOR_ISSUE or FAILED.
  final String status;
  final String? note;
}

/// Quality-check report and (optional) revised refund price.
class ReturnQc {
  const ReturnQc({
    required this.checks,
    required this.originalPrice,
    required this.priceStatus,
    this.revisedPrice,
    this.summary,
    this.customerMessage,
  });

  final List<ReturnQcCheck> checks;
  final double originalPrice;
  final double? revisedPrice;

  /// NONE (no change), PROPOSED (waiting for the customer), ACCEPTED or CLARIFICATION.
  final String priceStatus;
  final String? summary;
  final String? customerMessage;

  bool get needsAnswer => priceStatus == 'PROPOSED';
  bool get hasPriceChange =>
      revisedPrice != null && revisedPrice! < originalPrice;
}

/// The latest refund request for one order — powers the order-detail
/// screen's status card and the return tracking screens.
class RefundRequestStatusEntity {
  const RefundRequestStatusEntity({
    required this.id,
    required this.itemScope,
    required this.description,
    required this.status,
    required this.createdAt,
    this.orderId,
    this.orderNumber,
    this.adminNote,
    this.refundAmount,
    this.refundTo,
    this.returnNumber,
    this.reasonCode,
    this.sellerName,
    this.refundReference,
    this.refundedAt,
    this.resolvedAt,
    this.evidence = const <ReturnEvidence>[],
    this.timeline = const <ReturnTimelineStep>[],
    this.items = const <String>[],
    this.returnApprovedAt,
    this.pickup,
    this.qc,
  });

  final String id;
  final String? orderId;
  final String? orderNumber;

  /// 'ALL' or 'SPECIFIC'.
  final String itemScope;
  final String description;

  /// 'PENDING', 'APPROVED', 'REJECTED', or 'CANCELLED'.
  final String status;
  final String? adminNote;
  final double? refundAmount;

  /// 'wallet' or 'original', set only once approved.
  final String? refundTo;
  final DateTime createdAt;
  final String? returnNumber;
  final String? reasonCode;
  final String? sellerName;
  final String? refundReference;
  final DateTime? refundedAt;
  final DateTime? resolvedAt;
  final List<ReturnEvidence> evidence;
  final List<ReturnTimelineStep> timeline;

  /// Names of the returned products (empty = whole order).
  final List<String> items;
  final DateTime? returnApprovedAt;
  final ReturnPickup? pickup;
  final ReturnQc? qc;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  /// Whether this request still blocks a fresh submission for the same
  /// order — only a cancelled request frees the order up again.
  bool get blocksNewRequest => !isCancelled;
}
