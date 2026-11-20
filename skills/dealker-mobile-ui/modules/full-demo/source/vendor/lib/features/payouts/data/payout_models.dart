num _n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

enum PayoutStatus {
  pending('Pending'),
  processing('Processing'),
  paid('Paid'),
  failed('Failed'),
  cancelled('Cancelled');

  const PayoutStatus(this.label);
  final String label;

  static PayoutStatus parse(String? v) =>
      PayoutStatus.values.firstWhere((s) => s.name == (v ?? '').toLowerCase(),
          orElse: () => PayoutStatus.pending);
}

/// One transfer from Dealkr to the vendor's bank (a settlement payout).
class Payout {
  const Payout({
    required this.id,
    required this.number,
    required this.amount,
    required this.status,
    this.utr,
    this.paidAt,
    this.createdAt,
  });

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
        id: '${j['id'] ?? ''}',
        number: '${j['payout_number'] ?? ''}',
        amount: _n(j['amount']),
        status: PayoutStatus.parse(j['status'] as String?),
        utr: (j['utr_number'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['utr_number'] as String,
        paidAt: DateTime.tryParse('${j['paid_at'] ?? ''}')?.toLocal(),
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
      );

  final String id;
  final String number;
  final num amount;
  final PayoutStatus status;
  final String? utr;
  final DateTime? paidAt;
  final DateTime? createdAt;
}

class PayoutSummary {
  const PayoutSummary(
      {this.paid = 0,
      this.inProgress = 0,
      this.paidCount = 0,
      this.inProgressCount = 0});
  factory PayoutSummary.fromJson(Map<String, dynamic> j) => PayoutSummary(
        paid: _n(j['paid']),
        inProgress: _n(j['in_progress']),
        paidCount: _n(j['paid_count']).toInt(),
        inProgressCount: _n(j['in_progress_count']).toInt(),
      );
  final num paid;
  final num inProgress;
  final int paidCount;
  final int inProgressCount;
}

class PayoutPage {
  const PayoutPage(
      {required this.items, required this.summary, required this.total});
  final List<Payout> items;
  final PayoutSummary summary;
  final int total;
}
