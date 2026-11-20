import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Thin Razorpay wrapper with the same surface the customer app's repair payment screen uses.
class RazorpayService {
  RazorpayService() {
    _r.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) => onSuccess?.call(r));
    _r.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) => onFailure?.call(r));
    _r.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) => onExternalWallet?.call(r));
  }
  final Razorpay _r = Razorpay();
  bool get isAvailable => true;
  void Function(PaymentSuccessResponse)? onSuccess;
  void Function(PaymentFailureResponse)? onFailure;
  void Function(ExternalWalletResponse)? onExternalWallet;

  void open(RazorpayOptions options) => _r.open(options.toMap());
  void dispose() => _r.clear();
}

class RazorpayOptions {
  const RazorpayOptions({
    required this.key,
    required this.amount,
    required this.razorpayOrderId,
    required this.name,
    required this.description,
    required this.themeColorHex,
    this.contact,
    this.email,
    this.prefillName,
  });

  final String key;
  final int amount;
  final String razorpayOrderId;
  final String name;
  final String description;
  final String themeColorHex;
  final String? contact;
  final String? email;
  final String? prefillName;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'key': key,
        'amount': amount,
        'order_id': razorpayOrderId,
        'name': name,
        'description': description,
        'prefill': <String, dynamic>{'contact': contact, 'email': email, 'name': prefillName}
          ..removeWhere((k, v) => v == null || v == ''),
        'theme': <String, dynamic>{'color': themeColorHex},
      };
}
