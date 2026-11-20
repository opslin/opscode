import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/core/utils/extensions/double_extensions.dart';
import 'package:dealker_app/core/utils/server_error.dart';
import 'package:dealker_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:dealker_app/features/payments/presentation/providers/payment_provider.dart';
import 'package:dealker_app/routing/route_names.dart';

const Color _ink = Color(0xFF001F5F);
const Color _accent = Color(0xFF1558E8);

/// Winner payment: pick a saved address and pay from the wallet or online.
/// Returns true when an order was created (and, for wallet, paid).
Future<bool> showAuctionCheckoutSheet(
  BuildContext context,
  WidgetRef ref, {
  required String auctionId,
  required double amountDue,
}) async {
  final bool? done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
    ),
    builder: (BuildContext c) =>
        _CheckoutSheet(auctionId: auctionId, amountDue: amountDue),
  );
  return done ?? false;
}

class _CheckoutSheet extends ConsumerStatefulWidget {
  const _CheckoutSheet({required this.auctionId, required this.amountDue});

  final String auctionId;
  final double amountDue;

  @override
  ConsumerState<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<_CheckoutSheet> {
  List<Map<String, dynamic>> _addresses = const <Map<String, dynamic>>[];
  String? _addressId;
  double _wallet = 0;
  String _method = 'ONLINE';
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = ref.read(dioClientProvider);
      final List<dynamic> res2 = await Future.wait<dynamic>(<Future<dynamic>>[
        dio.get<dynamic>('/addresses'),
        dio.get<dynamic>('/wallet'),
      ]);
      final dynamic a = (res2[0] as dynamic).data;
      final dynamic w = (res2[1] as dynamic).data;
      final List<Map<String, dynamic>> list = <Map<String, dynamic>>[
        if (a is Map && a['data'] is List)
          for (final dynamic r in a['data'] as List)
            if (r is Map) Map<String, dynamic>.from(r),
      ];
      final double bal = (w is Map && w['data'] is Map)
          ? ((w['data']['balance'] as num?) ?? 0).toDouble()
          : 0;
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _addressId = list.isEmpty
            ? null
            : (list.firstWhere(
                (Map<String, dynamic> r) => r['isDefault'] == true,
                orElse: () => list.first)['id'] as String);
        _wallet = bal;
        _method = bal >= widget.amountDue ? 'WALLET' : 'ONLINE';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your addresses. Please try again.';
        });
      }
    }
  }

  Future<void> _pay() async {
    if (_addressId == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(dioClientProvider).post<dynamic>(
        '/auctions/${widget.auctionId}/checkout',
        data: <String, dynamic>{
          'addressId': _addressId,
          'paymentMethod': _method
        },
      );
      final dynamic d = r.data is Map ? (r.data as Map)['data'] : null;
      if (d is! Map) throw StateError('bad response');
      if (_method == 'ONLINE' && d['payment_required'] == true) {
        final double total =
            ((d['amount_due'] as num?) ?? widget.amountDue).toDouble();
        final PaymentActionResult res =
            await ref.read(paymentProvider.notifier).startRazorpayFlow(
                  PlacedOrderEntity(
                    id: '${d['order_id']}',
                    orderNumber: '${d['order_number']}',
                    status: 'PENDING',
                    subtotal: ((d['subtotal'] as num?) ?? total).toDouble(),
                    discountAmount: ((d['fee_credit'] as num?) ?? 0).toDouble(),
                    deliveryFee: 0,
                    platformFee: 0,
                    totalAmount: total,
                    paymentMethod: 'ONLINE',
                    paymentStatus: 'PENDING',
                    createdAt: DateTime.now(),
                  ),
                );
        if (!res.isSuccess) {
          if (mounted) setState(() => _error = res.errorMessage);
          return;
        }
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (mounted) {
        Navigator.pop(context, true);
        AppToast.show(context, 'Payment done. Your order is placed.');
        context.go('${RouteNames.orders}/${d['order_id']}');
      }
    } catch (e) {
      final ServerError err = ServerError.from(e);
      if (mounted) setState(() => _error = err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool walletOk = _wallet >= widget.amountDue;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20.w, 20.h, 20.w, 20.h + MediaQuery.viewInsetsOf(context).bottom),
      child: _loading
          ? SizedBox(
              height: 160.h,
              child: const Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Complete your purchase',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Amount to pay: ${widget.amountDue.toInrCurrency}',
                  style:
                      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Deliver to',
                  style:
                      TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
                ),
                if (_addresses.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                            child: Text('You have no saved address.')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, false);
                            context.push('${RouteNames.profile}/addresses/add');
                          },
                          child: const Text('Add address'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final Map<String, dynamic> a in _addresses)
                    RadioListTile<String>(
                      activeColor: _accent,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: '${a['id']}',
                      groupValue: _addressId,
                      onChanged: (String? v) => setState(() => _addressId = v),
                      title: Text(
                        '${a['label'] ?? 'Address'}',
                        style: TextStyle(
                            fontSize: 13.sp, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${a['addressLine2'] ?? ''} ${a['addressLine1'] ?? ''}'
                            .trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ),
                SizedBox(height: 8.h),
                Text(
                  'Pay with',
                  style:
                      TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
                ),
                RadioListTile<String>(
                  activeColor: _accent,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: 'WALLET',
                  groupValue: _method,
                  onChanged: walletOk
                      ? (String? v) => setState(() => _method = v!)
                      : null,
                  title: Text(
                    'Dealkr wallet (${_wallet.toInrCurrency})',
                    style:
                        TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                  subtitle: walletOk
                      ? null
                      : Text(
                          'Not enough balance for this order',
                          style: TextStyle(fontSize: 12.sp),
                        ),
                ),
                RadioListTile<String>(
                  activeColor: _accent,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: 'ONLINE',
                  groupValue: _method,
                  onChanged: (String? v) => setState(() => _method = v!),
                  title: Text(
                    'UPI / Card / Net banking',
                    style:
                        TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Text(
                      _error!,
                      style: TextStyle(
                          color: Colors.red.shade700, fontSize: 12.sp),
                    ),
                  ),
                SizedBox(height: 10.h),
                FilledButton(
                  onPressed: (_addressId == null || _busy) ? null : _pay,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    minimumSize: Size.fromHeight(50.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          'Pay ${widget.amountDue.toInrCurrency}',
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            ),
    );
  }
}
