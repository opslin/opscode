import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/features/auctions/data/auction_view.dart' show inr;
import 'package:dealker_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';

/// "Bill details": every amount is the server's bill; points and wallet are the only things taken off after it.
class CartBillCard extends StatefulWidget {
  const CartBillCard({
    required this.summary,
    required this.itemCount,
    required this.toPay,
    required this.pointsOff,
    required this.pointsUsed,
    required this.walletUsed,
    required this.saved,
    this.couponCode,
    super.key,
  });

  final BillSummaryEntity summary;
  final int itemCount;

  /// What is still payable after points and wallet (the grand total).
  final double toPay;
  final double pointsOff;
  final int pointsUsed;
  final double walletUsed;
  final double saved;
  final String? couponCode;

  @override
  State<CartBillCard> createState() => _CartBillCardState();
}

class _CartBillCardState extends State<CartBillCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final BillSummaryEntity s = widget.summary;
    final double mrp = s.itemTotal.original;
    final double discounted = s.itemTotal.discounted;
    final double productDiscount = (mrp - discounted).clamp(0, double.infinity);
    // A coupon shrinks the amount GST is charged on. billSummaryProvider already re-derives the total at that rate,
    // so the GST row shows the matching amount (total − everything else) instead of the pre-coupon figure.
    final double nonGst = discounted -
        s.couponDiscount +
        s.fees
            .where((FeeLine f) => f.code != 'GST')
            .fold<double>(0, (double a, FeeLine f) => a + f.amount) +
        s.tipAmount;
    final double gstNow = (s.payable - nonGst).clamp(0.0, double.infinity);
    final List<FeeLine> fees = s.fees
        .map((FeeLine f) => f.code == 'GST' && f.amount > 0
            ? f.copyWith(amount: double.parse(gstNow.toStringAsFixed(2)))
            : f)
        .where((FeeLine f) => f.code != 'GST' || f.amount > 0)
        .toList();
    final double feesTotal =
        fees.fold(0, (double a, FeeLine f) => a + f.amount);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              Expanded(child: Text('Bill details', style: jakarta(20.sp))),
              InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Row(children: <Widget>[
                  Text(_open ? 'Hide breakup' : 'View breakup',
                      style: dm(13.5.sp, color: AU.indigo, w: FontWeight.w800)),
                  SizedBox(width: 4.w),
                  Icon(
                      _open
                          ? PhosphorIconsBold.arrowUp
                          : PhosphorIconsBold.arrowDown,
                      size: 13.sp,
                      color: AU.indigo),
                ]),
              ),
            ]),
            SizedBox(height: 12.h),
            _row(
                'Item total (${widget.itemCount} item${widget.itemCount == 1 ? '' : 's'})',
                inr(mrp)),
            if (productDiscount > 0)
              _row('Product discount', '- ${inr(productDiscount)}',
                  green: true),
            if (s.couponDiscount > 0)
              _row(
                  widget.couponCode != null
                      ? 'Coupon discount (${widget.couponCode})'
                      : (s.firstTimeOffer?.name ?? 'Offer discount'),
                  '- ${inr(s.couponDiscount)}',
                  green: true),
            if (widget.pointsOff > 0)
              _row('Dealkr Points (${widget.pointsUsed})',
                  '- ${inr(widget.pointsOff)}',
                  green: true),
            if (widget.walletUsed > 0)
              _row('Wallet balance', '- ${inr(widget.walletUsed)}',
                  green: true),
            if (_open)
              for (final FeeLine f in fees) _feeRow(f)
            else if (feesTotal > 0)
              _row('Fees & taxes', inr(feesTotal)),
            if (s.tipAmount > 0) _row('Tip', inr(s.tipAmount)),
            Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: const Divider(height: 1, color: AU.border)),
            Row(children: <Widget>[
              Expanded(child: Text('Grand total', style: jakarta(20.sp))),
              Text(inr(widget.toPay), style: jakarta(22.sp)),
            ]),
            if (widget.saved > 0) ...<Widget>[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                    color: CU.savingsBg,
                    borderRadius: BorderRadius.circular(12.r)),
                child: Row(children: <Widget>[
                  Icon(PhosphorIconsRegular.sealCheck,
                      size: 24.sp, color: CU.greenIcon),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text.rich(TextSpan(children: <InlineSpan>[
                      TextSpan(
                          text: 'You saved ',
                          style:
                              dm(14.5.sp, color: CU.green, w: FontWeight.w600)),
                      TextSpan(
                          text: inr(widget.saved),
                          style: jakarta(14.5.sp, color: CU.green)),
                      TextSpan(
                          text: ' on this order',
                          style:
                              dm(14.5.sp, color: CU.green, w: FontWeight.w600)),
                    ])),
                  ),
                ]),
              ),
            ],
          ]),
    );
  }

  Widget _row(String label, String value,
          {bool green = false, Widget? trailingLabel}) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 5.h),
        child: Row(children: <Widget>[
          Expanded(
            child: Row(children: <Widget>[
              Flexible(
                  child: Text(label,
                      style: dm(14.5.sp,
                          color: const Color(0xFF4A5170), w: FontWeight.w500))),
              if (trailingLabel != null) trailingLabel,
            ]),
          ),
          Text(value,
              style: dm(14.5.sp,
                  color: green ? CU.green : AU.ink,
                  w: green ? FontWeight.w700 : FontWeight.w600)),
        ]),
      );

  Widget _feeRow(FeeLine f) {
    final String label = f.label.isEmpty ? f.code : f.label;
    final Widget? info = f.description.isEmpty
        ? null
        : InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (BuildContext c) => AlertDialog(
                title: Text(label, style: jakarta(17.sp)),
                content: Text(f.description,
                    style: dm(14.sp, color: AU.ink, h: 1.4)),
                actions: <Widget>[
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('OK'))
                ],
              ),
            ),
            child: Padding(
                padding: EdgeInsets.only(left: 6.w),
                child: Icon(PhosphorIconsRegular.info,
                    size: 17.sp, color: AU.muted)),
          );
    if (f.waived || f.amount <= 0) {
      return _row(label, 'FREE', green: true, trailingLabel: info);
    }
    return _row(label, inr(f.amount), trailingLabel: info);
  }
}

/// Three small reassurance icons under the bill.
class CartTrustRow extends StatelessWidget {
  const CartTrustRow({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(CartArt art, String a, String b) => Expanded(
          child: Row(children: <Widget>[
            CartArtImage(art, size: 32.sp),
            SizedBox(width: 8.w),
            Flexible(
                child: Text('$a\n$b',
                    style: dm(12.5.sp,
                        color: const Color(0xFF4A5170),
                        w: FontWeight.w600,
                        h: 1.3))),
          ]),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 4.h),
      child: Row(children: <Widget>[
        item(CartArt.lock, 'Secure', 'payments'),
        item(CartArt.verified, 'Genuine', 'products'),
        item(CartArt.calendar, 'Easy', 'returns'),
      ]),
    );
  }
}
