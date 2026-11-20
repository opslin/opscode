import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/features/auctions/data/auction_view.dart' show inr;
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';
import 'package:dealker_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:dealker_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:dealker_app/features/checkout/presentation/providers/coupon_provider.dart';

/// Opens the "Apply Coupon" bottom sheet over the cart. Returns true when a
/// coupon was applied.
Future<bool?> showCartCouponSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AU.ink.withValues(alpha: .45),
    builder: (_) => const _CouponSheet(),
  );
}

// Sheet-local tones — the amber "hint" and soft greys replace the old red error look.
const Color _sheetBg = Color(0xFFF4F6FB);
const Color _hintBg = Color(0xFFFFF7E6);
const Color _hintBorder = Color(0xFFFFE2A8);

class _CouponSheet extends ConsumerStatefulWidget {
  const _CouponSheet();

  @override
  ConsumerState<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends ConsumerState<_CouponSheet> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _focus = FocusNode();
  final Set<String> _expanded = <String>{};
  String? _busy; // code currently being validated
  String? _errorCode; // code the message below belongs to ('' = typed box)
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(availableCouponsProvider);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _apply(String raw, {required bool typed}) async {
    final String code = raw.trim().toUpperCase();
    if (code.isEmpty || _busy != null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = code;
      _errorCode = null;
      _errorMsg = null;
    });
    final CheckoutNotifier notifier = ref.read(checkoutProvider.notifier);
    final bool ok = await notifier.applyCoupon(code);
    if (!mounted) {
      return;
    }
    if (ok) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
      return;
    }
    final String? err = ref.read(checkoutProvider).errorMessage;
    notifier.clearError();
    setState(() {
      _busy = null;
      _errorCode = typed ? '' : code;
      _errorMsg = err ?? 'This coupon can’t be applied right now.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CouponEntity>> async =
        ref.watch(availableCouponsProvider);
    final CouponEntity? applied =
        ref.watch(checkoutProvider.select((s) => s.appliedCoupon));
    final double subtotal = ref.read(checkoutProvider.notifier).subtotal;
    final List<CouponEntity> coupons =
        async.asData?.value ?? const <CouponEntity>[];

    // Ready-to-use coupons first, locked ones after (closest to unlocking first).
    final List<CouponEntity> sorted = List<CouponEntity>.of(coupons)
      ..sort((a, b) {
        final bool ea = subtotal >= a.minOrderAmount;
        final bool eb = subtotal >= b.minOrderAmount;
        if (ea != eb) {
          return ea ? -1 : 1;
        }
        return a.minOrderAmount.compareTo(b.minOrderAmount);
      });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: .9,
        minChildSize: .55,
        maxChildSize: .95,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            color: _sheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(children: <Widget>[
            _header(),
            Expanded(
              child: ListView(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                    16.w, 4.h, 16.w, 24.h + MediaQuery.paddingOf(context).bottom),
                children: <Widget>[
                  _codeBox(),
                  if (_errorCode == '' && _errorMsg != null) ...<Widget>[
                    SizedBox(height: 10.h),
                    _Hint(text: _errorMsg!),
                  ],
                  if (applied != null) ...<Widget>[
                    SizedBox(height: 14.h),
                    _AppliedBanner(
                      coupon: applied,
                      onRemove: () {
                        HapticFeedback.selectionClick();
                        ref.read(checkoutProvider.notifier).removeCoupon();
                      },
                    ),
                  ],
                  SizedBox(height: 20.h),
                  Row(children: <Widget>[
                    Text('Available coupons',
                        style: jakarta(15.sp, color: AU.ink)),
                    if (sorted.isNotEmpty) ...<Widget>[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                            color: AU.indigoSoft,
                            borderRadius: BorderRadius.circular(20.r)),
                        child: Text('${sorted.length}',
                            style: dm(11.5.sp,
                                color: AU.indigo, w: FontWeight.w800)),
                      ),
                    ],
                  ]),
                  SizedBox(height: 12.h),
                  if (async.isLoading && coupons.isEmpty) ...<Widget>[
                    const _SkeletonTicket(),
                    SizedBox(height: 12.h),
                    const _SkeletonTicket(),
                  ] else if (async.hasError && coupons.isEmpty)
                    _Placeholder(
                      art: CartArt.coupon,
                      title: 'Couldn’t load coupons',
                      body: 'Check your connection and try again.',
                      action: 'Retry',
                      onAction: () => ref.invalidate(availableCouponsProvider),
                    )
                  else if (sorted.isEmpty)
                    const _Placeholder(
                      art: CartArt.giftbox,
                      title: 'No coupons right now',
                      body:
                          'Have a code? Type it above and we’ll check it for you.',
                    )
                  else
                    for (final CouponEntity c in sorted) ...<Widget>[
                      _CouponTicket(
                        coupon: c,
                        subtotal: subtotal,
                        isApplied: applied?.code == c.code,
                        busy: _busy == c.code,
                        locked: _busy != null && _busy != c.code,
                        expanded: _expanded.contains(c.code),
                        message: _errorCode == c.code ? _errorMsg : null,
                        onApply: () => _apply(c.code, typed: false),
                        onToggleTerms: () => setState(() {
                          if (!_expanded.add(c.code)) {
                            _expanded.remove(c.code);
                          }
                        }),
                      ),
                      SizedBox(height: 14.h),
                    ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 14.w, 12.h),
      child: Column(children: <Widget>[
        Container(
          width: 44.w,
          height: 4.h,
          decoration: BoxDecoration(
              color: AU.chipBorder, borderRadius: BorderRadius.circular(4.r)),
        ),
        SizedBox(height: 14.h),
        Row(children: <Widget>[
          const CartArtImage(CartArt.coupon, size: 34, float: true),
          SizedBox(width: 10.w),
          Expanded(
              child: Text('Apply Coupon', style: jakarta(21.sp, color: AU.ink))),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Icon(PhosphorIconsBold.x, size: 16.sp, color: AU.ink),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _codeBox() {
    final bool canApply = _code.text.trim().isNotEmpty && _busy == null;
    final bool busyTyped = _busy != null && _busy == _code.text.trim().toUpperCase();
    return Container(
      padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 6.h),
      decoration: cartCard(),
      child: Row(children: <Widget>[
        Expanded(
          child: Container(
            height: 48.h,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: _sheetBg,
              borderRadius: BorderRadius.circular(14.r),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _code,
              focusNode: _focus,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_-]')),
                LengthLimitingTextInputFormatter(24),
              ],
              onChanged: (_) {
                if (_errorCode == '') {
                  setState(() {
                    _errorCode = null;
                    _errorMsg = null;
                  });
                }
              },
              onSubmitted: (v) => _apply(v, typed: true),
              style: dm(14.5.sp,
                  color: AU.ink, w: FontWeight.w700),
              cursorColor: AU.indigo,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Enter coupon code',
                hintStyle: dm(14.5.sp, color: AU.grey, w: FontWeight.w500),
                prefixIcon: Icon(PhosphorIconsBold.ticket,
                    size: 18.sp, color: AU.grey),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 30.w, minHeight: 0),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          height: 48.h,
          child: TextButton(
            onPressed: canApply ? () => _apply(_code.text, typed: true) : null,
            style: TextButton.styleFrom(
              backgroundColor: canApply ? AU.indigo : Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: AU.grey,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r)),
            ),
            child: busyTyped
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Text('Apply', style: jakarta(14.sp, color: canApply ? Colors.white : AU.grey)),
          ),
        ),
      ]),
    );
  }
}

// ─── Applied banner ────────────────────────────────────────────────────────

class _AppliedBanner extends StatelessWidget {
  const _AppliedBanner({required this.coupon, required this.onRemove});
  final CouponEntity coupon;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String sub = coupon.discountAmount > 0
        ? 'You’re saving ${inr(coupon.discountAmount)} on this order'
        : coupon.freeDelivery
            ? 'Free delivery on this order'
            : coupon.cashbackAmount > 0
                ? '${inr(coupon.cashbackAmount)} cashback after your order'
                : 'Applied to this order';
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 8.w, 12.h),
      decoration: BoxDecoration(
        color: CU.savingsBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: CU.greenIcon.withValues(alpha: .35)),
      ),
      child: Row(children: <Widget>[
        const CartArtImage(CartArt.verified, size: 40),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${coupon.code} applied',
                    style: jakarta(14.5.sp, color: CU.green)),
                SizedBox(height: 2.h),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: dm(12.sp, color: CU.green, w: FontWeight.w600)),
              ]),
        ),
        TextButton(
          onPressed: onRemove,
          style: TextButton.styleFrom(
              foregroundColor: AU.ink,
              padding: EdgeInsets.symmetric(horizontal: 12.w)),
          child: Text('Remove', style: dm(13.sp, color: AU.ink, w: FontWeight.w800)),
        ),
      ]),
    );
  }
}

// ─── Ticket-style coupon card ──────────────────────────────────────────────

class _CouponTicket extends StatelessWidget {
  const _CouponTicket({
    required this.coupon,
    required this.subtotal,
    required this.isApplied,
    required this.busy,
    required this.locked,
    required this.expanded,
    required this.onApply,
    required this.onToggleTerms,
    this.message,
  });

  final CouponEntity coupon;
  final double subtotal;
  final bool isApplied;
  final bool busy;
  final bool locked; // another coupon is being validated
  final bool expanded;
  final String? message;
  final VoidCallback onApply;
  final VoidCallback onToggleTerms;

  bool get _eligible => subtotal >= coupon.minOrderAmount;
  double get _shortfall => (coupon.minOrderAmount - subtotal).clamp(0, 1e9);

  CartArt get _art => switch (coupon.discountType) {
        CouponDiscountType.FREE_DELIVERY => CartArt.van,
        CouponDiscountType.CASHBACK => CartArt.piggy,
        _ => CartArt.coupon,
      };

  String get _title {
    final String? d = coupon.description?.trim();
    if (d != null && d.isNotEmpty) {
      return d;
    }
    return switch (coupon.discountType) {
      CouponDiscountType.PERCENTAGE =>
        '${coupon.discountValue.toStringAsFixed(coupon.discountValue % 1 == 0 ? 0 : 1)}% off on your order${coupon.maxDiscount > 0 ? ', up to ${inr(coupon.maxDiscount)}' : ''}',
      CouponDiscountType.FLAT => 'Flat ${inr(coupon.discountValue)} off on your order',
      CouponDiscountType.CASHBACK => 'Cashback on your order',
      CouponDiscountType.FREE_DELIVERY => 'Free delivery on your order',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool eligible = _eligible;
    final bool dim = !eligible && !isApplied;
    final double progress = coupon.minOrderAmount <= 0
        ? 1
        : (subtotal / coupon.minOrderAmount).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: AU.ink.withValues(alpha: .06),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          color: Colors.white,
          child: Column(children: <Widget>[
            // ── top: art · title · action ──
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 6.h),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        color: dim ? const Color(0xFFF0F2F7) : CU.amberBg,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: dim ? .5 : 1,
                        child: ColorFiltered(
                          colorFilter: dim
                              ? const ColorFilter.matrix(<double>[
                                  .35, .5, .15, 0, 0,
                                  .35, .5, .15, 0, 0,
                                  .35, .5, .15, 0, 0,
                                  0, 0, 0, 1, 0,
                                ])
                              : const ColorFilter.mode(
                                  Colors.transparent, BlendMode.dst),
                          child: CartArtImage(_art, size: 38),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Text(_title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: jakarta(14.sp,
                                w: FontWeight.w700,
                                color: dim ? AU.grey : AU.ink,
                                h: 1.3)),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    _ApplyPill(
                      applied: isApplied,
                      enabled: eligible && !locked,
                      busy: busy,
                      onTap: onApply,
                    ),
                  ]),
            ),
            // ── status / hint ──
            if (message != null)
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
                child: _Hint(text: message!),
              )
            else if (isApplied)
              _statusRow(Icons.check_circle_rounded, 'Applied to this order',
                  CU.green)
            else if (!eligible)
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
                child: _Hint(
                  text: 'Add items worth ${inr(_shortfall)} more to unlock this offer',
                  progress: progress,
                ),
              ),
            // ── perforation with side notches ──
            SizedBox(
              height: 18.h,
              child: Stack(clipBehavior: Clip.hardEdge, children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w),
                    child: const CustomPaint(painter: _DashPainter()),
                  ),
                ),
                Positioned(left: -10.w, top: 0, bottom: 0, child: const _Notch()),
                Positioned(right: -10.w, top: 0, bottom: 0, child: const _Notch()),
              ]),
            ),
            // ── bottom: code chip · T&C ──
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 2.h, 8.w, 6.h),
              child: Row(children: <Widget>[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: dim ? const Color(0xFFF0F2F7) : AU.indigoSoft,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(coupon.code,
                      style: dm(12.5.sp,
                          color: dim ? AU.muted : AU.indigo,
                          w: FontWeight.w800,
                          h: 1.1)),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(10.r),
                  onTap: onToggleTerms,
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                    child: Row(children: <Widget>[
                      Text('T&C',
                          style: dm(12.5.sp, color: AU.muted, w: FontWeight.w800)),
                      SizedBox(width: 2.w),
                      AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(PhosphorIconsBold.caretDown,
                            size: 13.sp, color: AU.muted),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Container(
                      width: double.infinity,
                      margin: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: _sheetBg,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(_terms(),
                          style: dm(12.sp, color: AU.muted, h: 1.5)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            SizedBox(height: 4.h),
          ]),
        ),
      ),
    );
  }

  String _terms() {
    final String? t = coupon.terms?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    final List<String> lines = <String>[
      if (coupon.minOrderAmount > 0)
        '• Valid on a minimum cart value of ${inr(coupon.minOrderAmount)}.',
      if (coupon.discountType == CouponDiscountType.PERCENTAGE &&
          coupon.maxDiscount > 0)
        '• Maximum discount ${inr(coupon.maxDiscount)}.',
      '• One coupon per order; it can’t be combined with another coupon.',
    ];
    return lines.join('\n');
  }

  Widget _statusRow(IconData icon, String text, Color color) => Padding(
        padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
        child: Row(children: <Widget>[
          Icon(icon, size: 15.sp, color: color),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(text,
                style: dm(12.sp, color: color, w: FontWeight.w700)),
          ),
        ]),
      );
}

class _ApplyPill extends StatelessWidget {
  const _ApplyPill({
    required this.applied,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });
  final bool applied;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (applied) {
      return Container(
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
            color: CU.savingsBg, borderRadius: BorderRadius.circular(12.r)),
        alignment: Alignment.center,
        child: Text('Applied', style: dm(12.5.sp, color: CU.green, w: FontWeight.w800)),
      );
    }
    return SizedBox(
      height: 36.h,
      child: TextButton(
        onPressed: enabled && !busy ? onTap : null,
        style: TextButton.styleFrom(
          backgroundColor: enabled ? AU.indigo : const Color(0xFFF0F2F7),
          foregroundColor: Colors.white,
          disabledForegroundColor: AU.grey,
          minimumSize: Size(72.w, 36.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
        child: busy
            ? SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white))
            : Text('Apply',
                style: dm(13.sp,
                    color: enabled ? Colors.white : AU.grey, w: FontWeight.w800)),
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch();
  @override
  Widget build(BuildContext context) => Container(
        width: 20.w,
        decoration: const BoxDecoration(color: _sheetBg, shape: BoxShape.circle),
      );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = AU.chipBorder
      ..strokeWidth = 1.2;
    final double y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), p);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Soft amber hint (replaces red errors) ─────────────────────────────────

class _Hint extends StatelessWidget {
  const _Hint({required this.text, this.progress});
  final String text;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: _hintBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _hintBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: Icon(PhosphorIconsBold.info, size: 15.sp, color: CU.amber),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(text,
                style: dm(12.5.sp, color: CU.amber, w: FontWeight.w700, h: 1.35)),
          ),
        ]),
        if (progress != null) ...<Widget>[
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5.h,
              backgroundColor: CU.amberIcon.withValues(alpha: .2),
              valueColor: const AlwaysStoppedAnimation<Color>(CU.amberIcon),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Loading / empty states ────────────────────────────────────────────────

class _SkeletonTicket extends StatelessWidget {
  const _SkeletonTicket();
  @override
  Widget build(BuildContext context) => Container(
        height: 138.h,
        padding: EdgeInsets.all(14.w),
        decoration: cartCard(),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Bone(width: 52.w, height: 52.w, radius: 16.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              SizedBox(height: 4.h),
              Bone(width: 170.w, height: 14.h),
              SizedBox(height: 10.h),
              Bone(width: 110.w, height: 12.h),
            ]),
          ),
        ]),
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.art,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });
  final CartArt art;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 22.h),
        decoration: cartCard(),
        child: Column(children: <Widget>[
          CartArtImage(art, size: 64, float: true),
          SizedBox(height: 10.h),
          Text(title, style: jakarta(15.sp)),
          SizedBox(height: 4.h),
          Text(body,
              textAlign: TextAlign.center,
              style: dm(12.5.sp, color: AU.muted, h: 1.4)),
          if (action != null) ...<Widget>[
            SizedBox(height: 14.h),
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: dm(13.5.sp, color: AU.indigo, w: FontWeight.w800)),
            ),
          ],
        ]),
      );
}
