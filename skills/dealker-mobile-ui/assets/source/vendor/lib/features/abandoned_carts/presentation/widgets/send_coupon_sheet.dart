import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/abandoned_carts/application/cart_providers.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_models.dart';
import 'package:dealker_vendor/features/abandoned_carts/presentation/widgets/cart_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// "Send a coupon" for ONE product the shopper left in the cart: flat ₹ or percentage, validity, preview.
/// The server enforces every rule; the sheet only explains them.
Future<void> showSendCouponSheet(BuildContext context, {required CartDetail cart, required CartLine line}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _Sheet(cart: cart, line: line),
    );

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.cart, required this.line});
  final CartDetail cart;
  final CartLine line;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  bool _percent = true;
  final _value = TextEditingController(text: '10');
  int _days = 3;
  bool _busy = false;
  String? _error;

  CouponRules get _rules => widget.cart.couponRules;
  num get _maxFlat => (widget.line.lineTotal * _rules.maxFlatShare).floor();
  num get _entered => num.tryParse(_value.text.trim()) ?? 0;

  String? get _problem {
    final v = _entered;
    if (_percent) {
      if (v < 1 || v > _rules.maxPercent) return 'Enter 1 to ${_rules.maxPercent} %';
    } else if (v < 1 || v > _maxFlat) {
      return 'Enter ₹1 to ${formatInr(_maxFlat)}';
    }
    return null;
  }

  num get _off => _problem != null
      ? 0
      : (_percent ? widget.line.lineTotal * _entered / 100 : _entered);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _pick(bool percent) => setState(() {
        _percent = percent;
        _value.text = percent ? '10' : '${(_maxFlat / 5).floor().clamp(1, 1000000)}';
        _error = null;
      });

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(cartRepositoryProvider).sendCoupon(widget.cart.id,
          productId: widget.line.productId,
          discountType: _percent ? 'PERCENTAGE' : 'FLAT',
          value: _entered,
          validDays: _days);
      if (!mounted) return;
      refreshCarts(ref, id: widget.cart.id);
      Navigator.of(context).pop();
      showAppToast(context, 'Coupon sent — the customer has it in their Coupons');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, 'Could not send the coupon.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    final presets = _percent ? [5, 10, 15, 20] : [for (final f in [0.05, 0.1, 0.15]) (l.lineTotal * f).round()].where((x) => x >= 1 && x <= _maxFlat).toSet().toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text('Send a coupon', style: heading(size: 20)),
          const SizedBox(height: 12),
          Row(children: [
            ProductThumb(l.thumbnail, size: 52, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${formatInr(l.lineTotal)}  ·  Qty ${l.quantity}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _Seg('Percentage %', _percent, () => _pick(true)),
            const SizedBox(width: 10),
            _Seg('Flat ₹', !_percent, () => _pick(false)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _value,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: _percent ? 'Discount percentage' : 'Discount amount',
              prefixText: _percent ? null : '₹ ',
              suffixText: _percent ? '%' : null,
              errorText: _problem,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final p in presets)
              ActionChip(
                label: Text(_percent ? '$p%' : formatInr(p)),
                onPressed: () => setState(() => _value.text = '$p'),
              ),
          ]),
          const SizedBox(height: 14),
          Text('Valid for', style: heading(size: 14)),
          const SizedBox(height: 8),
          Row(children: [
            for (final d in _rules.validDays) ...[
              _Seg(d == 1 ? '1 day' : '$d days', _days == d, () => setState(() => _days = d)),
              const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(PhosphorIconsFill.tag, color: AppColors.mint, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _problem != null
                      ? 'Enter a valid discount to see what the customer pays.'
                      : 'Customer pays ${formatInr(l.lineTotal - _off)} for this product instead of ${formatInr(l.lineTotal)}.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          for (final t in [
            'One-time coupon — works once, for this customer only.',
            'Applies to this product only. Other items in the cart get no discount.',
            'You fund the discount; it is deducted from your payout when the coupon is used.',
            'The coupon appears in the customer\'s Coupons and they get a notification.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(PhosphorIconsFill.checkCircle, size: 14, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Expanded(child: Text(t, style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary))),
              ]),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          CartButton(
            label: 'Send coupon',
            icon: PhosphorIconsBold.paperPlaneTilt,
            loading: _busy,
            onPressed: _problem == null && !_busy ? _send : null,
          ),
        ]),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg(this.label, this.on, this.onTap);
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? kCartViolet : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? kCartViolet : AppColors.cardBorder),
            ),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: on ? Colors.white : AppColors.navy)),
          ),
        ),
      );
}
