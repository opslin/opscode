import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/auctions/data/auction_view.dart' show inr;
import 'package:dealker_app/features/cart/presentation/providers/cart_points_provider.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';

/// "Offers & coupons" — a tap target, or the applied coupon with a Remove link.
class CartCouponCard extends StatelessWidget {
  const CartCouponCard(
      {required this.onTap,
      this.appliedCode,
      this.saves = 0,
      this.freeDelivery = false,
      this.onRemove,
      super.key});
  final VoidCallback onTap;
  final String? appliedCode;
  final num saves;
  final bool freeDelivery;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bool applied = appliedCode != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: applied ? null : onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        padding: EdgeInsets.all(14.w),
        decoration: cartCard(),
        child: Row(children: <Widget>[
          CartIconTile(
              art: applied ? CartArt.verified : CartArt.coupon,
              icon: PhosphorIconsBold.percent,
              bg: applied ? CU.greenIcon : CU.orange),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Offers & coupons', style: jakarta(16.sp)),
                  SizedBox(height: 3.h),
                  if (applied)
                    Text(
                      saves > 0
                          ? '$appliedCode applied · You save ${inr(saves)}'
                          : (freeDelivery
                              ? '$appliedCode applied · Free delivery'
                              : '$appliedCode applied'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dm(12.5.sp, color: CU.green, w: FontWeight.w800),
                    )
                  else
                    Text('Apply coupon for extra savings',
                        style: dm(13.5.sp, color: AU.muted)),
                ]),
          ),
          if (applied)
            InkWell(
                onTap: onRemove,
                child: Padding(
                    padding: EdgeInsets.all(4.w),
                    child: Text('Remove',
                        style:
                            dm(13.5.sp, color: AU.indigo, w: FontWeight.w800))))
          else
            Icon(PhosphorIconsBold.caretRight, size: 18.sp, color: AU.ink),
        ]),
      ),
    );
  }
}

/// "Dealkr Points" — collapsed with a chevron; switch + slider once it is on.
class CartPointsCard extends StatefulWidget {
  const CartPointsCard(
      {required this.info,
      required this.selection,
      required this.onTurnOn,
      required this.onTurnOff,
      required this.onPoints,
      super.key});
  final CartPointsInfo info;
  final PointsSelection selection;
  final VoidCallback onTurnOn;
  final VoidCallback onTurnOff;
  final ValueChanged<int> onPoints;

  @override
  State<CartPointsCard> createState() => _CartPointsCardState();
}

class _CartPointsCardState extends State<CartPointsCard> {
  late final TextEditingController _box =
      TextEditingController(text: '${widget.selection.points}');
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(CartPointsCard old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _box.text != '${widget.selection.points}')
      _box.text = '${widget.selection.points}';
  }

  @override
  void dispose() {
    _box.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _lo => widget.info.minRedeemable.clamp(0, widget.info.maxPoints);
  int get _hi => widget.info.maxPoints;

  void _commit() {
    final int v = (int.tryParse(_box.text) ?? _lo).clamp(_lo, _hi);
    _box.text = '$v';
    widget.onPoints(v);
  }

  @override
  Widget build(BuildContext context) {
    final CartPointsInfo info = widget.info;
    final bool on = widget.selection.on && info.canRedeem;
    final int used = widget.selection.points.clamp(0, info.maxPoints);
    final double off = used * info.pointValue;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: cartCard(),
      child: Column(children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: info.canRedeem && !on ? widget.onTurnOn : null,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(children: <Widget>[
              const CartIconTile(
                  art: CartArt.star,
                  icon: PhosphorIconsFill.coins,
                  bg: CU.coin,
                  fg: Color(0xFF8A5A00)),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Dealkr Points', style: jakarta(16.sp)),
                      SizedBox(height: 3.h),
                      Text.rich(TextSpan(children: <TextSpan>[
                        TextSpan(
                            text: 'You have ',
                            style: dm(13.5.sp, color: AU.muted)),
                        TextSpan(
                            text: '${info.balance} points',
                            style:
                                dm(13.5.sp, color: AU.ink, w: FontWeight.w800)),
                        TextSpan(
                            text: ' ( = ${inr(info.balanceValue)})',
                            style: dm(13.5.sp, color: AU.muted)),
                      ])),
                    ]),
              ),
              if (info.canRedeem)
                (on
                    ? CartSwitch(
                        value: true, onChanged: (_) => widget.onTurnOff())
                    : Icon(PhosphorIconsBold.caretRight,
                        size: 18.sp, color: AU.ink))
              else
                const SizedBox.shrink(),
            ]),
          ),
        ),
        if (!info.canRedeem && info.balance < info.minRedeemable)
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Reach ${info.minRedeemable} points to start using them.',
                    style: dm(12.5.sp))),
          ),
        if (on) ...<Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(TextSpan(children: <TextSpan>[
                TextSpan(
                    text: 'Using $used points',
                    style: dm(14.sp, color: AU.ink, w: FontWeight.w800)),
                TextSpan(
                    text: ' — ${inr(off)} off',
                    style: dm(14.sp, color: CU.green, w: FontWeight.w800)),
              ])),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 0),
            child: Row(children: <Widget>[
              _round(
                  PhosphorIconsBold.minus,
                  used > _lo
                      ? () => widget.onPoints((used - _step).clamp(_lo, _hi))
                      : null),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: AU.indigo,
                    inactiveTrackColor: const Color(0xFFE3E6F2),
                    thumbColor: AU.indigo,
                    overlayColor: AU.indigo.withValues(alpha: .12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: Slider(
                    min: _lo.toDouble(),
                    max: _hi <= _lo ? _lo + 1.0 : _hi.toDouble(),
                    value:
                        used.clamp(_lo, _hi <= _lo ? _lo + 1 : _hi).toDouble(),
                    onChanged: _hi <= _lo
                        ? null
                        : (double v) => widget.onPoints(v.round()),
                  ),
                ),
              ),
              _round(
                  PhosphorIconsBold.plus,
                  used < _hi
                      ? () => widget.onPoints((used + _step).clamp(_lo, _hi))
                      : null),
              SizedBox(width: 8.w),
              SizedBox(
                width: 64.w,
                height: 44.h,
                child: TextField(
                  controller: _box,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7)
                  ],
                  onSubmitted: (_) => _commit(),
                  style: dm(15.sp, color: AU.ink, w: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: AU.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: AU.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide:
                            const BorderSide(color: AU.indigo, width: 1.5)),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 12.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'You can use up to ${info.maxPoints} points on this order — admin cap ${info.maxRedemptionPct.toStringAsFixed(info.maxRedemptionPct % 1 == 0 ? 0 : 1)}%.',
                  style: dm(12.sp, h: 1.35)),
            ),
          ),
        ],
        if (info.earnEstimate > 0)
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, on ? 0 : 0, 14.w, 12.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  "You'll earn ~${info.earnEstimate} points on this order",
                  style: dm(12.5.sp, color: CU.green, w: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }

  int get _step => ((_hi - _lo) / 10).round().clamp(1, 50);

  Widget _round(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38.w,
          height: 38.w,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AU.chipBorder, width: 1.2)),
          child: Icon(icon,
              size: 16.sp, color: onTap == null ? AU.chipBorder : AU.ink),
        ),
      );
}

/// "Dealkr Wallet" — navy card with a floating 3D wallet, a coin toggle and an
/// animated "will be used / remaining" strip.
class CartWalletCard extends StatelessWidget {
  const CartWalletCard(
      {required this.balance,
      required this.on,
      required this.onChanged,
      required this.applied,
      required this.remaining,
      required this.onAddMoney,
      super.key});
  final double balance;
  final bool on;
  final ValueChanged<bool> onChanged;
  final double applied;
  final double remaining;
  final VoidCallback onAddMoney;

  @override
  Widget build(BuildContext context) {
    final bool has = balance > 0;
    final bool showUse = has && on && applied > 0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF001F5F), Color(0xFF123A8F)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: const Color(0xFF001F5F).withValues(alpha: .28),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(children: <Widget>[
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(children: <Widget>[
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Center(
                  child: CartArtImage(CartArt.wallet, size: 42.w, float: true)),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Dealkr Wallet',
                        style: jakarta(16.sp, color: Colors.white)),
                    SizedBox(height: 4.h),
                    Text.rich(TextSpan(children: <TextSpan>[
                      TextSpan(
                          text: 'Balance ',
                          style: dm(13.sp,
                              color: Colors.white.withValues(alpha: .72))),
                      TextSpan(
                          text: inr(balance),
                          style: dm(14.sp,
                              color: AppColors.brandYellow,
                              w: FontWeight.w700)),
                    ])),
                  ]),
            ),
            if (has)
              DealkerCoinToggle(value: on, onChanged: onChanged)
            else
              InkWell(
                borderRadius: BorderRadius.circular(20.r),
                onTap: onAddMoney,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.brandYellow,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text('Add money',
                      style: dm(13.sp,
                          color: AppColors.brandNavy, w: FontWeight.w700)),
                ),
              ),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showUse
              ? Container(
                  width: double.infinity,
                  margin: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.w),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.brandYellow,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(children: <Widget>[
                    CartArtImage(CartArt.piggy, size: 32.w, float: true),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${inr(applied)} will be used',
                                style: jakarta(14.sp,
                                    color: AppColors.brandNavy)),
                            SizedBox(height: 2.h),
                            Text(
                                remaining > 0
                                    ? 'Remaining ${inr(remaining)} to pay'
                                    : 'Your wallet covers this order',
                                style: dm(12.5.sp,
                                    color: AppColors.brandNavy,
                                    w: FontWeight.w600)),
                          ]),
                    ),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}
