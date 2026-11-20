import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/features/demand/application/razorpay_pay.dart'
    show PayOutcome, PayResult;
import 'package:dealker_vendor/features/wallet/data/wallet_repository.dart';

/// Add money to the Dealkr wallet through Razorpay (UPI, cards, netbanking): create the order,
/// open Checkout, then let the server verify the signature and credit the wallet.
class WalletTopUp {
  WalletTopUp(this._repo);
  final WalletRepository _repo;

  Razorpay? _rzp;
  Completer<PayOutcome>? _done;
  TopUpOrder? _order;

  Future<PayOutcome> pay(num amount, {String? phone}) async {
    final o = await _repo.createTopUp(amount);
    _order = o;
    _rzp?.clear();
    final done = Completer<PayOutcome>();
    _done = done;
    final r = Razorpay();
    r.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaid);
    r.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    r.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
    _rzp = r;
    r.open({
      'key': o.keyId,
      'order_id': o.razorpayOrderId,
      'amount': o.amountPaise,
      'currency': 'INR',
      'name': 'Dealkr',
      'description': 'Add money to Dealkr wallet',
      'theme': {'color': '#2563EB'},
      'retry': {'enabled': true, 'max_count': 2},
      if (phone != null) 'prefill': {'contact': phone},
    });
    return done.future;
  }

  Future<void> _onPaid(PaymentSuccessResponse r) async {
    try {
      await _repo.verifyTopUp(
          orderId: r.orderId ?? _order?.razorpayOrderId ?? '',
          paymentId: r.paymentId ?? '',
          signature: r.signature ?? '');
      _finish(const PayOutcome(PayResult.paid));
    } catch (e) {
      _finish(PayOutcome(
          PayResult.failed,
          e is Failure
              ? e.message
              : 'We could not confirm the payment. If money was deducted it will be credited automatically.'));
    }
  }

  void _onError(PaymentFailureResponse r) => _finish(
      r.code == Razorpay.PAYMENT_CANCELLED
          ? const PayOutcome(PayResult.cancelled)
          : PayOutcome(PayResult.failed,
              r.message ?? 'The payment did not go through. You have not been charged.'));

  void _finish(PayOutcome o) {
    if (_done?.isCompleted == false) _done!.complete(o);
  }

  void dispose() {
    _rzp?.clear();
    _rzp = null;
  }
}
