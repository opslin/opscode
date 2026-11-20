import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dealker_app/features/payments/presentation/service/razorpay_gateway.dart';
import 'package:dealker_app/features/payments/presentation/service/web_checkout_outcome.dart';

@JS('Razorpay')
external JSFunction? get _razorpayConstructor;

RazorpayGateway createRazorpayGateway() => _WebGateway();

class _WebGateway implements RazorpayGateway {
  bool _disposed = false;

  @override
  bool get isAvailable => !_disposed && _razorpayConstructor != null;

  @override
  void open(Map<String, dynamic> options,
      {required void Function(PaymentSuccessResponse) onSuccess,
      required void Function(PaymentFailureResponse) onFailure,
      required void Function(ExternalWalletResponse) onWallet}) {
    final constructor = _razorpayConstructor;
    if (constructor == null)
      throw StateError('Razorpay checkout is unavailable');
    final outcome = WebCheckoutOutcome();
    Map<dynamic, dynamic>? failureDetails;
    final config = options.jsify()! as JSObject;
    config.setProperty(
        'handler'.toJS,
        ((JSAny? result) {
          if (_disposed || !outcome.completeSuccess()) return;
          final map = result?.dartify();
          if (map is Map) {
            onSuccess(PaymentSuccessResponse.fromMap(map));
          } else {
            onFailure(PaymentFailureResponse(
                Razorpay.UNKNOWN_ERROR, 'Payment response was invalid', null));
          }
        }).toJS);
    final modal = <String, dynamic>{}.jsify()! as JSObject;
    modal.setProperty(
        'ondismiss'.toJS,
        (() {
          if (_disposed) return;
          switch (outcome.dismiss()) {
            case WebCheckoutDismissal.ignored:
              return;
            case WebCheckoutDismissal.cancelled:
              onFailure(PaymentFailureResponse(
                  Razorpay.PAYMENT_CANCELLED, 'Payment cancelled', null));
            case WebCheckoutDismissal.unknown:
              onFailure(PaymentFailureResponse(Razorpay.UNKNOWN_ERROR,
                  'Payment could not be confirmed', failureDetails));
          }
        }).toJS);
    config.setProperty('modal'.toJS, modal);
    final checkout = constructor.callAsConstructor<JSObject>(config);
    checkout.callMethod<JSAny?>(
        'on'.toJS,
        'payment.failed'.toJS,
        ((JSAny? result) {
          if (_disposed) return;
          outcome.recordFailure();
          final converted = result?.dartify();
          failureDetails = converted is Map ? converted : null;
        }).toJS);
    checkout.callMethod<JSAny?>('open'.toJS);
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
