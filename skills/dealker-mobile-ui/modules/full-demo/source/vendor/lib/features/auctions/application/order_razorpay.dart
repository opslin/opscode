import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/features/auctions/data/auction_repository.dart';
import 'package:dealker_vendor/features/demand/application/razorpay_pay.dart' show PayOutcome, PayResult;

/// Razorpay Checkout (UPI, cards, netbanking) for one order that already exists on the server — used
/// to pay for a won auction lot. The signature is verified by the server, which then marks the lot sold.
class OrderRazorpay {
  OrderRazorpay(this._repo);
  final AuctionRepository _repo;

  Razorpay? _rzp;
  Completer<PayOutcome>? _done;
  OrderGateway? _order;

  Future<PayOutcome> pay(String orderId,
      {required String description, String? phone}) async {
    final g = await _repo.gatewayOrder(orderId);
    _order = g;
    _rzp?.clear();
    final done = Completer<PayOutcome>();
    _done = done;
    final r = Razorpay();
    r.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaid);
    r.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    r.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
    _rzp = r;
    r.open({
      'key': g.keyId,
      'order_id': g.razorpayOrderId,
      'amount': g.amountPaise,
      'currency': 'INR',
      'name': 'Dealkr',
      'description': description,
      'theme': {'color': '#2563EB'},
      'retry': {'enabled': true, 'max_count': 2},
      if (phone != null) 'prefill': {'contact': phone},
    });
    return done.future;
  }

  Future<void> _onPaid(PaymentSuccessResponse r) async {
    try {
      await _repo.verifyGateway(
          orderId: r.orderId ?? _order?.razorpayOrderId ?? '',
          paymentId: r.paymentId ?? '',
          signature: r.signature ?? '');
      _finish(const PayOutcome(PayResult.paid));
    } catch (e) {
      _finish(PayOutcome(
          PayResult.failed,
          e is Failure
              ? e.message
              : 'We could not confirm your payment. If money was deducted it will be reconciled automatically.'));
    }
  }

  void _onError(PaymentFailureResponse r) {
    final closed = r.code == Razorpay.PAYMENT_CANCELLED;
    _finish(closed
        ? const PayOutcome(PayResult.cancelled)
        : PayOutcome(PayResult.failed, r.message ?? 'The payment did not go through.'));
  }

  void _finish(PayOutcome o) {
    if (_done?.isCompleted == false) _done!.complete(o);
  }

  void dispose() {
    _rzp?.clear();
    _rzp = null;
  }
}
