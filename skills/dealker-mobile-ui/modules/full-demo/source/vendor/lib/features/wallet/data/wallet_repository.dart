import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/wallet/data/wallet_models.dart';

/// The vendor's Dealkr wallet (`/wallet`) and the transfer from sales
/// earnings into it (`/settlements/transfer-to-wallet`). The JWT carries the
/// vendor; nothing here takes an id.
class WalletRepository {
  WalletRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? query, Object? body}) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(path,
          data: body, queryParameters: query, options: Options(method: method));
      return res.data ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Map<String, dynamic> _map(dynamic v) =>
      (v as Map?)?.cast<String, dynamic>() ?? const {};

  Future<VendorWallet> balances() async {
    final w = _map((await _send('GET', '/wallet'))['data']);
    final s = _map((await _send('GET', '/settlements/summary'))['data']);
    num n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
    return VendorWallet(wallet: n(w['balance']), earnings: n(s['available']));
  }

  Future<List<WalletTxn>> transactions({int limit = 30}) async {
    final b =
        await _send('GET', '/wallet/transactions', query: {'limit': limit});
    return ((b['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WalletTxn.fromJson)
        .toList();
  }

  /// Moves [amount] from earnings into the Dealkr wallet. The idempotency key
  /// makes a retried tap safe.
  Future<void> transfer(num amount, {required String idempotencyKey}) =>
      _send('POST', '/settlements/transfer-to-wallet',
          body: {'amount': amount, 'idempotencyKey': idempotencyKey});

  /// Step 1 of adding money: a Razorpay order for [amount] (server limits: ₹10 – ₹10,000, and the wallet cap).
  Future<TopUpOrder> createTopUp(num amount) async {
    final d = _map((await _send('POST', '/wallet/topup', body: {'amount': amount}))['data']);
    final a = d['amount'];
    return TopUpOrder(
      keyId: '${d['keyId'] ?? ''}',
      razorpayOrderId: '${d['razorpayOrderId'] ?? ''}',
      amountPaise: (((a is num ? a : num.tryParse('$a')) ?? amount) * 100).round(),
    );
  }

  /// Step 2: the server checks Razorpay's signature and credits the wallet exactly once.
  Future<void> verifyTopUp(
          {required String orderId,
          required String paymentId,
          required String signature}) =>
      _send('POST', '/wallet/topup/verify',
          body: {'orderId': orderId, 'paymentId': paymentId, 'signature': signature});
}

class TopUpOrder {
  const TopUpOrder(
      {required this.keyId, required this.razorpayOrderId, required this.amountPaise});
  final String keyId;
  final String razorpayOrderId;
  final int amountPaise;
}
