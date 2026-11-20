import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/data/demand_repository.dart';

enum PayResult { paid, cancelled, failed }

class PayOutcome {
  const PayOutcome(this.result, [this.message]);
  final PayResult result;
  final String? message;
}

/// Opens Razorpay Checkout for one or many wholesale orders and turns its callbacks into one answer.
/// Mirrors the sell-phone flow: a verified payment goes to escrow; when the callback is lost the server
/// is asked to look the payment up, so money is never left half-applied.
class RazorpayPayment {
  RazorpayPayment(this._repo);
  final DemandRepository _repo;

  Razorpay? _rzp;
  Completer<PayOutcome>? _done;
  GatewayOrder? _order;

  String _msg(Object e, String fallback) => e is Failure ? e.message : fallback;

  Future<PayOutcome> pay(List<String> requirementIds,
      {String? name, String? phone, String? email}) async {
    final order = await _repo.razorpayOrder(requirementIds);
    _order = order;
    _rzp?.clear();
    final done = Completer<PayOutcome>();
    _done = done;
    final r = Razorpay();
    r.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaid);
    r.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    r.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
    _rzp = r;
    r.open({
      'key': order.keyId,
      'order_id': order.orderId,
      'amount': order.amount,
      'currency': 'INR',
      'name': 'Dealkr',
      'description': order.description,
      'theme': {'color': '#2563EB'},
      'retry': {'enabled': true, 'max_count': 2},
      if (phone != null || email != null)
        'prefill': {
          if (phone != null) 'contact': phone,
          if (email != null) 'email': email,
        },
    });
    return done.future;
  }

  Future<void> _onPaid(PaymentSuccessResponse r) async {
    final id = r.orderId ?? _order?.orderId ?? '';
    try {
      await _repo.razorpayVerify(
          orderId: id,
          paymentId: r.paymentId ?? '',
          signature: r.signature ?? '');
      _finish(const PayOutcome(PayResult.paid));
    } catch (e) {
      // The money may have left the account even though verification failed: ask the server to look it up.
      try {
        await _repo.razorpaySync(id);
        _finish(const PayOutcome(PayResult.paid));
      } catch (_) {
        _finish(PayOutcome(
            PayResult.failed, _msg(e, 'We could not confirm your payment.')));
      }
    }
  }

  Future<void> _onError(PaymentFailureResponse r) async {
    final id = _order?.orderId ?? '';
    // Closing Checkout is not a failure; a payment that went through but lost its callback is recovered here.
    try {
      await _repo.razorpaySync(id);
      _finish(const PayOutcome(PayResult.paid));
      return;
    } catch (_) {}
    if (r.code == Razorpay.PAYMENT_CANCELLED) {
      _finish(const PayOutcome(PayResult.cancelled));
    } else {
      _finish(PayOutcome(
          PayResult.failed,
          r.message?.isNotEmpty == true
              ? r.message
              : 'The payment did not go through. You have not been charged.'));
    }
  }

  void _finish(PayOutcome o) {
    final d = _done;
    if (d != null && !d.isCompleted) d.complete(o);
  }

  void dispose() {
    _rzp?.clear();
    _rzp = null;
  }
}
