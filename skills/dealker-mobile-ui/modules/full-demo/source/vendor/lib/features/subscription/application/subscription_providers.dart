import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/demand/application/razorpay_pay.dart'
    show PayOutcome, PayResult;
import 'package:dealker_vendor/features/subscription/data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
    (ref) => SubscriptionRepository(ref.watch(dioProvider)));

final subPlansProvider = FutureProvider.autoDispose<List<SubPlan>>(
    (ref) => ref.watch(subscriptionRepositoryProvider).plans());

/// Followers + shop photo for the signed-in vendor.
final growthProvider = FutureProvider.autoDispose<Growth>(
    (ref) => ref.watch(subscriptionRepositoryProvider).growth());

/// Buy or renew a plan through Razorpay (UPI, cards, netbanking): create the order, open Checkout,
/// then let the server verify the signature and switch the plan on.
class SubscriptionPay {
  SubscriptionPay(this._repo);
  final SubscriptionRepository _repo;

  Razorpay? _rzp;
  Completer<PayOutcome>? _done;
  SubCheckout? _order;

  Future<PayOutcome> pay(String tier, bool yearly, {String? phone}) async {
    final o = await _repo.checkout(tier, yearly);
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
      'order_id': o.orderId,
      'amount': o.amountPaise,
      'currency': 'INR',
      'name': 'Dealkr',
      'description': '${o.planName} plan · ${yearly ? 'yearly' : 'monthly'}',
      'theme': {'color': '#2563EB'},
      'retry': {'enabled': true, 'max_count': 2},
      if (phone != null) 'prefill': {'contact': phone},
    });
    return done.future;
  }

  Future<void> _onPaid(PaymentSuccessResponse r) async {
    try {
      await _repo.verify(
          orderId: r.orderId ?? _order?.orderId ?? '',
          paymentId: r.paymentId ?? '',
          signature: r.signature ?? '');
      _finish(const PayOutcome(PayResult.paid));
    } catch (e) {
      _finish(PayOutcome(
          PayResult.failed,
          e is Failure
              ? e.message
              : 'We could not confirm the payment yet. If money was deducted, pull down to refresh or contact support.'));
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
