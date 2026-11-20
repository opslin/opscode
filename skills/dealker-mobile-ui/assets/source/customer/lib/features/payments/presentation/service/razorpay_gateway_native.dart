import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dealker_app/features/payments/presentation/service/razorpay_gateway.dart';

RazorpayGateway createRazorpayGateway() => _NativeGateway();

class _NativeGateway implements RazorpayGateway {
  @override
  bool get isAvailable => true;

  final Razorpay _razorpay = Razorpay();
  bool _registered = false;
  void Function(PaymentSuccessResponse)? _success;
  void Function(PaymentFailureResponse)? _failure;
  void Function(ExternalWalletResponse)? _wallet;

  @override
  void open(Map<String, dynamic> options,
      {required void Function(PaymentSuccessResponse) onSuccess,
      required void Function(PaymentFailureResponse) onFailure,
      required void Function(ExternalWalletResponse) onWallet}) {
    _success = onSuccess;
    _failure = onFailure;
    _wallet = onWallet;
    if (!_registered) {
      _razorpay
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS,
            (PaymentSuccessResponse response) => _success?.call(response))
        ..on(Razorpay.EVENT_PAYMENT_ERROR,
            (PaymentFailureResponse response) => _failure?.call(response))
        ..on(Razorpay.EVENT_EXTERNAL_WALLET,
            (ExternalWalletResponse response) => _wallet?.call(response));
      _registered = true;
    }
    _razorpay.open(options);
  }

  @override
  void dispose() => _razorpay.clear();
}
