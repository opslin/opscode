import 'package:razorpay_flutter/razorpay_flutter.dart';

abstract class RazorpayGateway {
  bool get isAvailable;
  void open(
    Map<String, dynamic> options, {
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onFailure,
    required void Function(ExternalWalletResponse) onWallet,
  });
  void dispose();
}
