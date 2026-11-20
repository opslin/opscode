num _n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

/// What a vendor can spend where. [earnings] is the settlement balance (sales
/// money); [wallet] is the Dealkr wallet that auction fees and winning bids
/// are charged to.
class VendorWallet {
  const VendorWallet({this.wallet = 0, this.earnings = 0});
  final num wallet;
  final num earnings;
}

class WalletTxn {
  const WalletTxn({
    required this.id,
    required this.credit,
    required this.amount,
    required this.description,
    required this.balanceAfter,
    this.createdAt,
  });

  factory WalletTxn.fromJson(Map<String, dynamic> j) => WalletTxn(
        id: '${j['id'] ?? ''}',
        credit: '${j['type']}'.toUpperCase() == 'CREDIT',
        amount: _n(j['amount']),
        description: '${j['description'] ?? ''}',
        balanceAfter: _n(j['balanceAfter']),
        createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal(),
      );

  final String id;
  final bool credit;
  final num amount;
  final String description;
  final num balanceAfter;
  final DateTime? createdAt;
}
