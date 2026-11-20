import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dealker_app/features/payments/presentation/service/razorpay_gateway.dart';
import 'package:dealker_app/features/payments/presentation/service/razorpay_gateway_native.dart'
    if (dart.library.js_interop) 'package:dealker_app/features/payments/presentation/service/razorpay_gateway_web.dart'
    as platform;

class RazorpayService {
  RazorpayService({RazorpayGateway? gateway})
      : _gateway = gateway ?? platform.createRazorpayGateway();
  final RazorpayGateway _gateway;
  bool get isAvailable => _gateway.isAvailable;
  void Function(PaymentSuccessResponse)? onSuccess;
  void Function(PaymentFailureResponse)? onFailure;
  void Function(ExternalWalletResponse)? onExternalWallet;

  void open(RazorpayOptions options) => _gateway.open(
        options.toMap(),
        onSuccess: (response) => onSuccess?.call(response),
        onFailure: (response) => onFailure?.call(response),
        onWallet: (response) => onExternalWallet?.call(response),
      );
  void dispose() => _gateway.dispose();
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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'key': key,
      'amount': amount,
      'order_id': razorpayOrderId,
      'name': name,
      'description': description,
      'prefill': <String, dynamic>{
        'contact': contact,
        'email': email,
        'name': prefillName,
      }..removeWhere((key, value) => value == null || value == ''),
      'theme': <String, dynamic>{
        'color': themeColorHex,
      },
    };
  }
}
