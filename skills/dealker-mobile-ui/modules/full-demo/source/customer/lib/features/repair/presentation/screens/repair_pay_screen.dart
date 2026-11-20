import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/core/utils/server_error.dart';
import 'package:dealker_app/features/payments/presentation/service/razorpay_service.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';
import 'package:dealker_app/routing/app_router.dart' show currentUserProvider;

enum _Method { upi, card, wallet, shop }

/// "Payment (in app)": pay the advance or balance by UPI / card (Razorpay) or from the Dealkr wallet.
class RepairPayScreen extends ConsumerStatefulWidget {
  const RepairPayScreen({required this.repairId, super.key});

  final String repairId;

  @override
  ConsumerState<RepairPayScreen> createState() => _RepairPayScreenState();
}

class _RepairPayScreenState extends ConsumerState<RepairPayScreen> {
  _Method? _picked;

  /// The chosen method, or the first one that can be used right now.
  _Method _method(RepairPayOptions? o) {
    if (_picked != null) return _picked!;
    if (o == null) return _Method.upi;
    if (o.online) return _Method.upi;
    if (o.walletBalance >= (o.amount ?? 0)) return _Method.wallet;
    return _Method.shop;
  }

  bool _busy = false;
  String? _error;
  String _orderId = '';
  late final String _walletKey =
      'w${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(9999)}';

  RazorpayService? _rzp;

  @override
  void dispose() {
    _rzp?.dispose();
    super.dispose();
  }

  void _done() {
    ref.invalidate(repairRequestProvider(widget.repairId));
    ref.invalidate(repairPayOptionsProvider(widget.repairId));
    ref.invalidate(repairMineProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment received. Thank you!')));
    context.canPop() ? context.pop() : context.go('/repair/${widget.repairId}');
  }

  Future<void> _pay(RepairPayOptions o) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final RepairApi api = ref.read(repairApiProvider);
    try {
      switch (_method(o)) {
        case _Method.shop:
          if (mounted)
            context.canPop()
                ? context.pop()
                : context.go('/repair/${widget.repairId}');
          return;
        case _Method.wallet:
          await api.payWallet(widget.repairId, _walletKey);
          _done();
        case _Method.upi:
        case _Method.card:
          final RazorpayService svc = _rzp ??= RazorpayService();
          if (!svc.isAvailable) {
            setState(() {
              _busy = false;
              _error =
                  'Online checkout is unavailable. Please try again later.';
            });
            return;
          }
          final Map<String, dynamic> order =
              await api.payOrder(widget.repairId);
          _orderId = '${order['orderId']}';
          svc
            ..onSuccess = (PaymentSuccessResponse r) async {
              try {
                await api.payVerify(widget.repairId,
                    orderId: r.orderId ?? _orderId,
                    paymentId: r.paymentId ?? '',
                    signature: r.signature ?? '');
                _done();
              } catch (e) {
                if (mounted)
                  setState(() => _error = ServerError.from(e).message);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            }
            ..onFailure = (PaymentFailureResponse r) {
              if (mounted) {
                setState(() {
                  _busy = false;
                  _error = r.message ?? 'The payment was not completed.';
                });
              }
            };
          final user = ref.read(currentUserProvider);
          svc.open(RazorpayOptions(
            key: '${order['keyId']}',
            amount: (order['amount'] as num).toInt(),
            razorpayOrderId: _orderId,
            name: 'Dealkr',
            description: '${order['description'] ?? 'Repair payment'}',
            themeColorHex: '#001F5F',
            contact: user?.phone,
            email: user?.email,
            prefillName: user?.name,
          ));
          return; // the Razorpay callbacks finish the flow
      }
    } catch (e) {
      if (mounted) setState(() => _error = ServerError.from(e).message);
    }
    final _Method used = _method(o);
    if (mounted && used != _Method.upi && used != _Method.card)
      setState(() => _busy = false);
    if (mounted &&
        (used == _Method.upi || used == _Method.card) &&
        _error != null) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RepairPayOptions> opt =
        ref.watch(repairPayOptionsProvider(widget.repairId));
    final RepairPayOptions? o = opt.asData?.value;
    return RepairShell(
      title: 'Payment',
      onBack: () => context.canPop()
          ? context.pop()
          : context.go('/repair/${widget.repairId}'),
      bottom: o == null
          ? null
          : RButton(
              label: _method(o) == _Method.shop
                  ? 'I will pay at the shop'
                  : 'Pay ${rupees(o.amount ?? o.due)}',
              loading: _busy,
              onTap: (o.amount ?? 0) <= 0 ? null : () => _pay(o),
            ),
      body: o == null
          ? (opt.hasError
              ? RErrorView(
                  offline: isOfflineError(opt.error!),
                  onRetry: () =>
                      ref.invalidate(repairPayOptionsProvider(widget.repairId)))
              : const RSkeletonCards())
          : ListView(
              padding: const EdgeInsets.fromLTRB(RT.gutter, 16, RT.gutter, 24),
              children: <Widget>[
                RCard(
                  child: Column(
                    children: <Widget>[
                      _line('Total amount', rupees(o.total)),
                      _line('Paid so far', rupees(o.paid), color: RT.green),
                      const Divider(height: 18, color: RT.border),
                      _line(
                          o.kind == 'ADVANCE'
                              ? 'Advance to pay now'
                              : 'Pay now',
                          rupees(o.amount ?? o.due),
                          bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Select payment method', style: rtHead(18)),
                const SizedBox(height: 10),
                _tile(o, _Method.upi, 'UPI', 'PhonePe · GPay · Paytm',
                    PhosphorIconsBold.qrCode, 'assets/sell/upi.png',
                    enabled: o.online,
                    off: 'Online payment is not available right now'),
                _tile(
                    o,
                    _Method.card,
                    'Credit / Debit card',
                    'Visa · Mastercard · RuPay',
                    PhosphorIconsBold.creditCard,
                    'assets/auction/card.png',
                    enabled: o.online,
                    off: 'Online payment is not available right now'),
                _tile(
                    o,
                    _Method.wallet,
                    'Dealkr wallet',
                    'Balance ${rupees(o.walletBalance)}',
                    PhosphorIconsBold.wallet,
                    'assets/auction/fee.png',
                    enabled: o.walletBalance >= (o.amount ?? 0),
                    off: 'Balance is too low — add money in Wallet'),
                _tile(
                    o,
                    _Method.shop,
                    'Cash (pay at the shop)',
                    'Hand the money to the shop; they mark it as paid',
                    PhosphorIconsBold.money,
                    'assets/exchange/bill.png',
                    enabled: true,
                    off: ''),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  RBand(_error!, kind: BandKind.danger),
                ],
              ],
            ),
    );
  }

  Widget _line(String l, String v, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
                child: Text(l,
                    style: rtBody(14.5,
                        color: bold ? RT.ink : RT.grey,
                        w: bold ? FontWeight.w700 : FontWeight.w400))),
            Text(v,
                style: rtHead(bold ? 19 : 15,
                    color: color ?? (bold ? RT.blue : RT.ink))),
          ],
        ),
      );

  Widget _tile(RepairPayOptions o, _Method m, String title, String sub,
      PhosphorIconData icon, String art,
      {required bool enabled, required String off}) {
    final bool on = _method(o) == m && enabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: enabled ? () => setState(() => _picked = m) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: on ? RT.tint : Colors.white,
              borderRadius: BorderRadius.circular(RT.cardRadius),
              border: Border.all(
                  color: on ? RT.blue : RT.border, width: on ? 1.5 : 1),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Colors.white,
                        on ? RT.tint : const Color(0xFFEAF1FF)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RT.blue.withValues(alpha: 0.14)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: RT.blue.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Image.asset(art,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (BuildContext _, Object __, StackTrace? ___) =>
                              PhosphorIcon(icon, color: RT.blue, size: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: rtHead(15.5)),
                      Text(enabled ? sub : off, style: rtBody(12.5)),
                    ],
                  ),
                ),
                PhosphorIcon(
                    on
                        ? PhosphorIconsFill.radioButton
                        : PhosphorIconsRegular.circle,
                    color: on ? RT.blue : RT.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
