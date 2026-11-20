import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/sell_phone/data/sell_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_repository.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_providers.dart';
import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_ui.dart';

/// One sale from "offer accepted" to "money received": a single screen that always shows the next thing to do.
class SellStatusScreen extends ConsumerStatefulWidget {
  const SellStatusScreen({required this.requestId, super.key});
  final String requestId;

  @override
  ConsumerState<SellStatusScreen> createState() => _SellStatusScreenState();
}

class _SellStatusScreenState extends ConsumerState<SellStatusScreen> {
  Timer? _poll;
  bool _busy = false;

  // payout form
  String _method = 'UPI';
  final TextEditingController _upi = TextEditingController();
  final TextEditingController _holder = TextEditingController();
  final TextEditingController _acc = TextEditingController();
  final TextEditingController _acc2 = TextEditingController();
  final TextEditingController _ifsc = TextEditingController();

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_busy) {
        ref.invalidate(sellJourneyProvider(widget.requestId));
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final TextEditingController c in <TextEditingController>[
      _upi,
      _holder,
      _acc,
      _acc2,
      _ifsc,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _reload() {
    ref.invalidate(sellJourneyProvider(widget.requestId));
    ref.invalidate(mySalesProvider);
  }

  Future<T?> _run<T>(Future<T> Function() fn) async {
    setState(() => _busy = true);
    try {
      final T r = await fn();
      _reload();
      return r;
    } catch (e) {
      if (mounted) AppToast.show(context, sellErrorMessage(e));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(bool accept) async {
    if (!accept) {
      final bool? yes = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Decline the new price?'),
          content: const Text(
            'The sale is cancelled and the buyer returns your phone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Decline'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    await _run(
      () => ref
          .read(sellRepositoryProvider)
          .decidePrice(widget.requestId, accept: accept),
    );
  }

  Future<void> _sendPayout() async {
    final Map<String, dynamic> body = <String, dynamic>{'method': _method};
    if (_method == 'UPI') {
      if (!RegExp(r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$')
          .hasMatch(_upi.text.trim())) {
        AppToast.show(context, 'Enter a valid UPI ID, like name@bank');
        return;
      }
      body['upiId'] = _upi.text.trim();
    } else if (_method == 'BANK') {
      final String acc = _acc.text.replaceAll(RegExp(r'\s'), '');
      if (_holder.text.trim().length < 2) {
        AppToast.show(context, 'Enter the account holder name');
        return;
      }
      if (!RegExp(r'^\d{9,18}$').hasMatch(acc)) {
        AppToast.show(context, 'Account number must be 9 to 18 digits');
        return;
      }
      if (acc != _acc2.text.replaceAll(RegExp(r'\s'), '')) {
        AppToast.show(context, 'The account numbers do not match');
        return;
      }
      if (!RegExp(r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$')
          .hasMatch(_ifsc.text.trim())) {
        AppToast.show(context, 'Enter a valid IFSC code');
        return;
      }
      body['bank'] = <String, dynamic>{
        'holderName': _holder.text.trim(),
        'accountNumber': acc,
        'ifsc': _ifsc.text.trim().toUpperCase(),
      };
      body['confirmAccountNumber'] = acc;
    }
    await _run(
      () =>
          ref.read(sellRepositoryProvider).choosePayout(widget.requestId, body),
    );
  }

  Future<void> _open(String url) async {
    final Uri? u = Uri.tryParse(url);
    if (u == null ||
        !await launchUrl(u, mode: LaunchMode.externalApplication) && mounted) {
      if (mounted) AppToast.show(context, 'Could not open the link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SellJourney> q =
        ref.watch(sellJourneyProvider(widget.requestId));
    return SellScaffold(
      title: 'Your sale',
      onBack: () => context.canPop() ? context.pop() : context.go('/sell'),
      child: q.when(
        skipLoadingOnReload: true,
        loading: () => const DealkerPageLoader(),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(sellErrorMessage(e, 'Could not load this sale.')),
              TextButton(onPressed: _reload, child: const Text('Try again')),
            ],
          ),
        ),
        data: (SellJourney j) => RefreshIndicator(
          color: ReturnColors.indigo,
          onRefresh: () async =>
              ref.refresh(sellJourneyProvider(widget.requestId).future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
            children: <Widget>[
              SellStagesBar(current: sellStageIndex(j.stage)),
              SizedBox(height: 16.h),
              _action(j),
              SizedBox(height: 16.h),
              if (j.agreedPrice != null) ...<Widget>[
                _summary(j),
                SizedBox(height: 16.h),
              ],
              Text('Step by step', style: sellHead(17)),
              SizedBox(height: 12.h),
              SellTracker(steps: j.steps),
            ],
          ),
        ),
      ),
    );
  }

  String _day(String? iso) {
    final DateTime? d = DateTime.tryParse(iso ?? '');
    return d == null ? (iso ?? '') : DateFormat('EEE, d MMM').format(d);
  }

  Widget _summary(SellJourney j) => SellCard(
        child: Column(
          children: <Widget>[
            _kv('Buyer', j.buyerName ?? '—'),
            _kv('Agreed price', inr(j.agreedPrice!)),
            if (j.fulfilmentMode == 'PICKUP' && j.pickupDate != null)
              _kv('Pickup', '${_day(j.pickupDate)} · ${j.pickupWindow ?? ''}'),
            if (j.fulfilmentMode == 'PICKUP' && j.pickupAddress != null)
              _kv('From', j.pickupAddress!),
            if (j.fulfilmentMode == 'DROP_OFF')
              _kv('Hand over at', j.buyerAddress ?? 'The buyer\'s store'),
          ],
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 96.w,
              child: Text(
                k,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: ReturnColors.muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: ReturnColors.ink,
                ),
              ),
            ),
          ],
        ),
      );

  /// The one card that tells the customer what happens next.
  Widget _action(SellJourney j) {
    switch (j.nextAction) {
      case 'WAIT_FOR_OFFERS':
      case 'REFRESH_OFFERS':
        return _headline(
          SellArt.looking,
          'Your phone is listed',
          j.nextAction == 'REFRESH_OFFERS'
              ? 'The offers expired. Refresh to hear from buyers again.'
              : 'Buyers near you are making offers.',
          button: SellButton(
            'View offers',
            onPressed: () => context.go('/sell/${widget.requestId}/offers'),
          ),
        );
      case 'CHOOSE_FULFILMENT':
        return _headline(
          SellArt.deal,
          'Offer accepted',
          'Choose how you want to hand over your phone.',
          tone: SellTone.good,
          button: SellButton(
            'Choose pickup or drop-off',
            onPressed: () => context.go('/sell/${widget.requestId}/book'),
          ),
        );
      case 'WAIT_FOR_BUYER_PAYMENT':
        return _headline(
          SellArt.wait,
          'Waiting for the buyer to pay',
          'Dealkr holds the buyer\'s payment before your pickup is arranged, so your money is safe. We will notify you.',
        );
      case 'WAIT_FOR_PICKUP_SLOT':
        return _headline(
          SellArt.courier,
          'Pickup requested',
          'We are arranging the courier. You will be notified with the details.',
        );
      case 'DROP_OFF_DEVICE':
        return _headline(
          SellArt.pin,
          'Bring your phone to the store',
          j.buyerAddress ?? 'The buyer has your drop-off request.',
          tone: SellTone.good,
          button: j.buyerPhone == null
              ? null
              : SellButton(
                  'Call the store',
                  icon: Icons.call_rounded,
                  outlined: true,
                  onPressed: () => _open('tel:${j.buyerPhone}'),
                ),
        );
      case 'WAIT_FOR_PICKUP':
      case 'WAIT_FOR_DELIVERY_TO_BUYER':
        return _headline(
          j.nextAction == 'WAIT_FOR_PICKUP' ? SellArt.courier : SellArt.parcel,
          j.nextAction == 'WAIT_FOR_PICKUP'
              ? 'Pickup scheduled'
              : 'Your phone is on its way',
          j.pickupDate != null
              ? 'Keep your phone ready on ${_day(j.pickupDate)} (${j.pickupWindow ?? ''}).'
              : 'Keep your phone ready.',
          extra: _courier(j),
        );
      case 'WAIT_FOR_INSPECTION':
        return _headline(
          SellArt.check,
          'Your phone is being checked',
          'The buyer is inspecting it. This usually takes a few hours.',
        );
      case 'DECIDE_FINAL_PRICE':
        return _priceChange(j);
      case 'CHOOSE_PAYOUT':
        return _payoutForm(j);
      case 'PAYOUT_PROCESSING':
        return _headline(
          SellArt.paid,
          'Payment on its way',
          '${inr(j.payoutAmount ?? 0)} is being sent to ${j.payoutDisplay ?? 'you'}. It usually reaches you within a few hours.',
          tone: SellTone.good,
        );
      case 'DONE':
        return _success(j);
      case 'DEVICE_RETURNING':
        return _headline(
          SellArt.parcel,
          'Your phone is coming back',
          'This sale did not go through. The buyer will return your phone.',
          tone: SellTone.warn,
        );
      default:
        return _headline(
          SellArt.shield,
          'This sale is closed',
          j.status == 'REJECTED' ? 'It was declined.' : 'Nothing more to do.',
          tone: SellTone.warn,
          button: SellButton(
            'Sell another phone',
            onPressed: () => context.go('/sell/new'),
          ),
        );
    }
  }

  Widget _headline(
    String art,
    String title,
    String body, {
    Widget? button,
    Widget? extra,
    SellTone tone = SellTone.info,
  }) {
    final String n = switch (art) {
      SellArt.looking => 'When a buyer makes an offer, we send you a notification.',
      SellArt.deal => 'The buyer pays Dealkr first, so your money is safe.',
      SellArt.wait => 'As soon as the payment is safe with Dealkr, we book the pickup.',
      SellArt.courier => 'After pickup, the buyer checks your phone.',
      SellArt.pin => 'The buyer checks your phone, then your money is sent.',
      SellArt.parcel => 'The buyer checks your phone when it arrives.',
      SellArt.check => 'If it is as you described, you get the full price.',
      SellArt.paid => 'Nothing to do. We will tell you when it arrives.',
      _ => 'You can sell a phone again whenever you like.',
    };
    return SellGuideCard(
      guide: SellGuide(
        art: art,
        title: title,
        now: body,
        next: n,
        tone: tone,
        needsAction: button != null && tone == SellTone.good,
      ),
      child: (extra == null && button == null)
          ? null
          : Column(
              children: <Widget>[
                if (extra != null) extra,
                if (extra != null && button != null) SizedBox(height: 10.h),
                if (button != null) button,
              ],
            ),
    );
  }

  Widget _courier(SellJourney j) {
    if (j.courier == null && j.awb == null && j.trackingUrl == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: ReturnColors.indigoSoft,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.local_shipping_outlined,
            color: ReturnColors.indigo,
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  j.courier ?? 'Courier',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontFamily: RT.head,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (j.awb != null)
                  Text(
                    'AWB ${j.awb}',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: ReturnColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (j.trackingUrl != null)
            TextButton(
              onPressed: () => _open(j.trackingUrl!),
              child: const Text('Track'),
            ),
        ],
      ),
    );
  }

  Widget _priceChange(SellJourney j) {
    final double was = j.originalPrice ?? j.agreedPrice ?? 0;
    final double now = j.finalValuation ?? was;
    return SellCard(
      border: ReturnColors.amber.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'The buyer revised the price',
            style: TextStyle(
              fontSize: 16.sp,
              fontFamily: RT.head,
              fontWeight: FontWeight.w900,
              color: ReturnColors.ink,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'After checking your phone, the price changed.',
            style: TextStyle(fontSize: 13.sp, color: ReturnColors.muted),
          ),
          SizedBox(height: 12.h),
          Row(
            children: <Widget>[
              Expanded(child: _price('Offered', inr(was), strike: true)),
              Icon(
                Icons.arrow_forward_rounded,
                color: ReturnColors.muted,
                size: 20.sp,
              ),
              Expanded(child: _price('New price', inr(now), strong: true)),
            ],
          ),
          SizedBox(height: 14.h),
          SellButton(
            'Accept ${inr(now)}',
            busy: _busy,
            onPressed: () => _decide(true),
          ),
          SizedBox(height: 8.h),
          SellButton(
            'Decline and get my phone back',
            outlined: true,
            danger: true,
            onPressed: _busy ? null : () => _decide(false),
          ),
        ],
      ),
    );
  }

  Widget _price(
    String label,
    String value, {
    bool strike = false,
    bool strong = false,
  }) =>
      Column(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 11.5.sp, color: ReturnColors.muted),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 22.sp : 17.sp,
              fontFamily: RT.head,
              fontWeight: FontWeight.w900,
              color: strong ? ReturnColors.ink : ReturnColors.muted,
              decoration: strike ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      );

  Widget _payoutForm(SellJourney j) {
    final List<PayoutOption> opts = j.payoutOptions
        .where((PayoutOption o) => o.method != 'WALLET' || o.enabled)
        .toList();
    if (opts.isNotEmpty &&
        !opts.any((PayoutOption o) => o.method == _method && o.enabled)) {
      _method = opts
          .firstWhere((PayoutOption o) => o.enabled, orElse: () => opts.first)
          .method;
    }
    return SellCard(
      border: ReturnColors.green.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.verified_rounded,
                color: ReturnColors.green,
                size: 24.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Your phone is approved',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontFamily: RT.head,
                    fontWeight: FontWeight.w900,
                    color: ReturnColors.ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'You will receive ${inr(j.payoutAmount ?? j.agreedPrice ?? 0)}. Choose how you want to be paid.',
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.4,
              color: ReturnColors.muted,
            ),
          ),
          SizedBox(height: 12.h),
          ...opts.map((PayoutOption o) {
            final bool sel = _method == o.method;
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: InkWell(
                borderRadius: BorderRadius.circular(12.r),
                onTap:
                    o.enabled ? () => setState(() => _method = o.method) : null,
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: !o.enabled
                        ? ReturnColors.line.withValues(alpha: 0.3)
                        : sel
                            ? ReturnColors.indigoSoft
                            : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: sel ? ReturnColors.indigo : ReturnColors.line,
                      width: sel ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        switch (o.method) {
                          'UPI' => Icons.bolt_rounded,
                          'BANK' => Icons.account_balance_rounded,
                          _ => Icons.account_balance_wallet_rounded
                        },
                        color: sel ? ReturnColors.indigo : ReturnColors.muted,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              o.label,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontFamily: RT.head,
                                fontWeight: FontWeight.w800,
                                color: o.enabled
                                    ? ReturnColors.ink
                                    : ReturnColors.muted,
                              ),
                            ),
                            Text(
                              o.hint,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: ReturnColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        sel
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: sel ? ReturnColors.indigo : ReturnColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_method == 'UPI') ...<Widget>[
            SizedBox(height: 6.h),
            TextField(
              controller: _upi,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'UPI ID',
                hintText: 'name@bank',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
          if (_method == 'BANK') ...<Widget>[
            SizedBox(height: 6.h),
            _field(_holder, 'Account holder name'),
            _field(_acc, 'Account number', digits: true),
            _field(_acc2, 'Confirm account number', digits: true),
            _field(_ifsc, 'IFSC code', caps: true),
          ],
          SizedBox(height: 12.h),
          SellButton(
            _method == 'WALLET'
                ? 'Add to my wallet'
                : 'Get ${inr(j.payoutAmount ?? j.agreedPrice ?? 0)}',
            busy: _busy,
            onPressed: _sendPayout,
          ),
          SizedBox(height: 8.h),
          Text(
            'Your payment details are stored encrypted and only used to pay you for this sale.',
            style: TextStyle(fontSize: 11.sp, color: ReturnColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool digits = false,
    bool caps = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: TextField(
          controller: c,
          keyboardType: digits ? TextInputType.number : TextInputType.text,
          textCapitalization:
              caps ? TextCapitalization.characters : TextCapitalization.words,
          inputFormatters: digits
              ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      );

  Widget _success(SellJourney j) => SellCard(
        border: ReturnColors.green.withValues(alpha: 0.5),
        tint: ReturnColors.greenSoft,
        child: Column(
          children: <Widget>[
            Icon(
              Icons.check_circle_rounded,
              color: ReturnColors.green,
              size: 54.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              'Payment successful',
              style: TextStyle(
                fontSize: 18.sp,
                fontFamily: RT.head,
                fontWeight: FontWeight.w900,
                color: ReturnColors.green,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              inr(j.payoutAmount ?? 0),
              style: TextStyle(
                fontSize: 30.sp,
                fontFamily: RT.head,
                fontWeight: FontWeight.w900,
                color: ReturnColors.ink,
              ),
            ),
            SizedBox(height: 6.h),
            if (j.payoutDisplay != null)
              Text(
                'Sent to ${j.payoutDisplay}',
                style: TextStyle(fontSize: 13.sp, color: ReturnColors.muted),
              ),
            if (j.payoutRef != null)
              Text(
                'Reference ${j.payoutRef}',
                style: TextStyle(fontSize: 12.sp, color: ReturnColors.muted),
              ),
            if (j.paidAt != null)
              Text(
                returnDate(j.paidAt),
                style: TextStyle(fontSize: 12.sp, color: ReturnColors.muted),
              ),
            SizedBox(height: 14.h),
            SellButton('Back to home', onPressed: () => context.go('/home')),
          ],
        ),
      );
}
