import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/refund_requests/presentation/widgets/return_ui.dart';
import 'package:dealker_app/features/sell_phone/data/sell_models.dart';
import 'package:dealker_app/shared/widgets/loading/dealker_loading_button.dart';
import 'package:dealker_app/shared/widgets/marketplace_product_box.dart';
import 'package:dealker_app/shared/widgets/web_service_frame.dart';

export 'package:dealker_app/features/refund_requests/presentation/widgets/return_ui.dart'
    show ReturnColors, ReturnStepper, returnDate;

String inr(num v) => MarketplaceProductBox.inr(v);

String inrRange(double? a, double? b) =>
    a == null || b == null ? '—' : '${inr(a)} – ${inr(b)}';

TextStyle sellHead(double size,
        {Color color = ReturnColors.ink, FontWeight w = FontWeight.w800}) =>
    TextStyle(
        fontFamily: RT.head,
        fontSize: size.sp,
        fontWeight: w,
        color: color,
        height: 1.2);

TextStyle sellBody(double size,
        {Color color = ReturnColors.muted, FontWeight w = FontWeight.w500}) =>
    TextStyle(
        fontFamily: RT.body,
        fontSize: size.sp,
        fontWeight: w,
        color: color,
        height: 1.35);

const Color kSellCanvas = Color(0xFFF5F7FC);
const Color kSellGold = Color(0xFFFFC400);

// ── artwork ──────────────────────────────────────────────────────────────────

/// 3D artwork of the sell journey (`assets/sell/`).
class SellArt {
  SellArt._();
  static const String hero = 'assets/sell/hero.png';
  static const String tell = 'assets/sell/tell.png';
  static const String looking = 'assets/sell/looking.png';
  static const String offer = 'assets/sell/offer.png';
  static const String deal = 'assets/sell/deal.png';
  static const String courier = 'assets/sell/courier.png';
  static const String parcel = 'assets/sell/parcel.png';
  static const String check = 'assets/sell/check.png';
  static const String paid = 'assets/sell/paid.png';
  static const String wait = 'assets/sell/wait.png';
  static const String bell = 'assets/sell/bell.png';
  static const String shield = 'assets/sell/shield.png';
  static const String chat = 'assets/sell/chat.png';
  static const String camera = 'assets/sell/camera.png';
  static const String pin = 'assets/sell/pin.png';
  static const String bank = 'assets/sell/bank.png';
  static const String upi = 'assets/sell/upi.png';
  static const String timer = 'assets/sell/timer.png';
}

class SellImage extends StatelessWidget {
  const SellImage(this.asset, {required this.size, super.key});
  final String asset;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
}

// ── frame ────────────────────────────────────────────────────────────────────

/// Clean white header (back + title), pale canvas, optional bottom action bar.
class SellScaffold extends StatelessWidget {
  const SellScaffold({
    required this.title,
    required this.child,
    this.onBack,
    this.bottom,
    this.actions,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSellCanvas,
      body: WebServiceFrame(
        panelColor: kSellCanvas,
        child: Column(
          children: <Widget>[
            Container(
              padding: EdgeInsets.fromLTRB(
                  4.w, MediaQuery.of(context).padding.top + 6.h, 8.w, 8.h),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: ReturnColors.line)),
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: ReturnColors.ink),
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(child: Text(title, style: sellHead(18))),
                  ...?actions,
                ],
              ),
            ),
            Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child,
                ),
              ),
            if (bottom != null)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: ReturnColors.line)),
                ),
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w,
                    MediaQuery.of(context).padding.bottom + 12.h),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

// ── basic blocks ─────────────────────────────────────────────────────────────

/// White rounded block with a hairline border — the surface every sell screen is built from.
class SellCard extends StatelessWidget {
  const SellCard(
      {required this.child, this.padding, this.tint, this.border, super.key});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: tint ?? Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: border ?? ReturnColors.line),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: RT.blue.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: child,
      );
}

class SellHeading extends StatelessWidget {
  const SellHeading(this.title, {this.subtitle, super.key});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: sellHead(19)),
            if (subtitle != null)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Text(subtitle!, style: sellBody(13.5)),
              ),
          ],
        ),
      );
}

/// Big, easy-to-tap action. Primary = brand yellow, outlined = navy line, danger = red line.
class SellButton extends StatelessWidget {
  const SellButton(
    this.label, {
    required this.onPressed,
    this.busy = false,
    this.outlined = false,
    this.danger = false,
    this.icon,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool outlined;
  final bool danger;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !busy;
    final Color c = danger ? ReturnColors.red : ReturnColors.indigo;
    final Color fg = outlined ? c : ReturnColors.indigo;
    final Widget content = busy
        ? DealkerBounceDots(color: fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 19.sp, color: fg),
                SizedBox(width: 8.w)
              ],
              Flexible(
                  child: Text(label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: sellHead(15.5, color: fg))),
            ],
          );
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: outlined
          ? OutlinedButton(
              onPressed: enabled ? onPressed : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: c,
                side: BorderSide(
                    color: enabled ? c : ReturnColors.line, width: 1.5),
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r)),
              ),
              child: content,
            )
          : ElevatedButton(
              onPressed: enabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kSellGold,
                foregroundColor: ReturnColors.indigo,
                disabledBackgroundColor:
                    kSellGold.withValues(alpha: busy ? 1 : 0.45),
                disabledForegroundColor:
                    ReturnColors.indigo.withValues(alpha: 0.6),
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r)),
              ),
              child: content,
            ),
    );
  }
}

/// A selectable pill (condition, window, payout method…).
class SellChoice extends StatelessWidget {
  const SellChoice(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.sub,
      super.key});
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: selected ? ReturnColors.indigo : Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                  color: selected ? ReturnColors.indigo : ReturnColors.line,
                  width: 1.3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: sellBody(
                    14,
                    color: onTap == null
                        ? ReturnColors.muted
                        : (selected ? Colors.white : ReturnColors.ink),
                    w: FontWeight.w700,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: sellBody(11,
                        color: selected ? Colors.white70 : ReturnColors.muted),
                  ),
              ],
            ),
          ),
        ),
      );
}

enum SellTone { good, bad, warn, info }

class SellInlineMessage extends StatelessWidget {
  const SellInlineMessage(this.text,
      {this.tone = SellTone.info, this.icon, super.key});
  final String text;
  final SellTone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData ic) = switch (tone) {
      SellTone.good => (
          ReturnColors.greenSoft,
          ReturnColors.green,
          Icons.check_circle_rounded
        ),
      SellTone.bad => (
          ReturnColors.redSoft,
          ReturnColors.red,
          Icons.error_rounded
        ),
      SellTone.warn => (
          const Color(0xFFFFF4DC),
          const Color(0xFF8A5A00),
          Icons.info_rounded
        ),
      SellTone.info => (
          ReturnColors.indigoSoft,
          ReturnColors.indigo,
          Icons.info_rounded
        ),
    };
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14.r)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon ?? ic, size: 20.sp, color: fg),
          SizedBox(width: 10.w),
          Expanded(
              child: Text(text,
                  style: sellBody(13.5, color: fg, w: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ── plain-language guide ─────────────────────────────────────────────────────

/// What is happening, what (if anything) the customer must do, and what comes next.
class SellGuide {
  const SellGuide({
    required this.art,
    required this.title,
    required this.now,
    required this.next,
    this.tone = SellTone.info,
    this.needsAction = false,
  });
  final String art;
  final String title;
  final String now;
  final String next;
  final SellTone tone;

  /// True when the customer has to tap something now.
  final bool needsAction;
}

SellGuide sellGuide(
    {String? stage,
    String status = 'PENDING',
    int offers = 0,
    bool offersOpen = true}) {
  if (status == 'CANCELLED' || status == 'REJECTED') {
    return const SellGuide(
      art: SellArt.shield,
      title: 'This sale is closed',
      now: 'It was cancelled or declined. There is nothing more to do here.',
      next: 'You can sell a phone again whenever you like.',
      tone: SellTone.warn,
    );
  }
  switch (stage) {
    case 'LISTED':
    case null:
      if (offers > 0) {
        return SellGuide(
          art: SellArt.offer,
          title: offers == 1 ? 'You have 1 offer!' : 'You have $offers offers!',
          now:
              'Buyers want your phone. Look at the prices and pick the one you like.',
          next: 'After you pick one, we arrange the pickup from your home.',
          tone: SellTone.good,
          needsAction: true,
        );
      }
      if (!offersOpen) {
        return const SellGuide(
          art: SellArt.wait,
          title: 'No offers came in yet',
          now:
              'The waiting time is over and no buyer made an offer. This happens sometimes.',
          next:
              'Tap "Ask buyers again" and buyers will look at your phone once more.',
          tone: SellTone.warn,
          needsAction: true,
        );
      }
      return const SellGuide(
        art: SellArt.looking,
        title: 'Buyers are looking at your phone',
        now:
            'Your phone is shown to trusted buyers near you. They are choosing their price. You do not need to do anything.',
        next:
            'When a buyer makes an offer, we send you a notification. Then you choose the best one.',
      );
    case 'OFFER_ACCEPTED':
      return const SellGuide(
        art: SellArt.deal,
        title: 'Offer accepted',
        now:
            'Now choose how to give your phone: we collect it from your home, or you take it to the shop.',
        next: 'The buyer pays Dealkr first, so your money is safe.',
        tone: SellTone.good,
        needsAction: true,
      );
    case 'PICKUP_REQUESTED':
      return const SellGuide(
        art: SellArt.courier,
        title: 'We are arranging the pickup',
        now: 'A courier is being booked. Keep your phone and charger ready.',
        next: 'We will tell you the day and time very soon.',
      );
    case 'PICKUP_SCHEDULED':
      return const SellGuide(
        art: SellArt.courier,
        title: 'Pickup is booked',
        now:
            'A courier will come to your home. Keep your phone ready and switched on.',
        next: 'After pickup, the buyer checks your phone.',
      );
    case 'PICKED_UP':
    case 'IN_TRANSIT':
      return const SellGuide(
        art: SellArt.parcel,
        title: 'Your phone is on its way',
        now: 'The courier has your phone and is taking it to the buyer.',
        next: 'The buyer will check it. Nothing to do now.',
      );
    case 'RECEIVED':
    case 'INSPECTING':
      return const SellGuide(
        art: SellArt.check,
        title: 'The buyer is checking your phone',
        now: 'This usually takes a few hours. You do not need to do anything.',
        next: 'If it is as you described, you get the full price.',
      );
    case 'FINAL_PRICE':
      return const SellGuide(
        art: SellArt.check,
        title: 'Please look at the final price',
        now:
            'After checking, the buyer has a new price. You decide if it is OK.',
        next:
            'If you say yes, your money is sent. If no, your phone comes back free.',
        tone: SellTone.warn,
        needsAction: true,
      );
    case 'PAYOUT_PENDING':
      return const SellGuide(
        art: SellArt.paid,
        title: 'Your phone is approved',
        now: 'Tell us where to send your money.',
        next: 'It reaches you within a few hours.',
        tone: SellTone.good,
        needsAction: true,
      );
    case 'PAID':
      return const SellGuide(
        art: SellArt.paid,
        title: 'You got your money!',
        now: 'The sale is complete. Thank you for selling with Dealkr.',
        next: 'Have another old phone? You can sell it too.',
        tone: SellTone.good,
      );
    case 'RETURNING':
      return const SellGuide(
        art: SellArt.parcel,
        title: 'Your phone is coming back',
        now: 'This sale did not go through. The buyer sends your phone back.',
        next: 'It is free for you.',
        tone: SellTone.warn,
      );
    default:
      return const SellGuide(
        art: SellArt.shield,
        title: 'This sale is closed',
        now: 'There is nothing more to do here.',
        next: 'You can sell a phone again whenever you like.',
        tone: SellTone.warn,
      );
  }
}

/// 0 listed · 1 offers · 2 hand over · 3 checked · 4 paid. [done] steps before the returned index.
int sellStageIndex(String? stage) => switch (stage) {
      'OFFER_ACCEPTED' ||
      'PICKUP_REQUESTED' ||
      'PICKUP_SCHEDULED' ||
      'PICKED_UP' ||
      'IN_TRANSIT' =>
        2,
      'RECEIVED' || 'INSPECTING' || 'FINAL_PRICE' => 3,
      'PAYOUT_PENDING' => 4,
      'PAID' => 5,
      _ => 1,
    };

/// The big picture: five stages with a picture each; done = green tick, now = gold ring.
class SellStagesBar extends StatelessWidget {
  const SellStagesBar({required this.current, super.key});
  final int current;

  static const List<(String, String)> _stages = <(String, String)>[
    ('Listed', SellArt.tell),
    ('Offers', SellArt.offer),
    ('Hand over', SellArt.courier),
    ('Checked', SellArt.check),
    ('Paid', SellArt.paid),
  ];

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < _stages.length; i++) ...<Widget>[
            Expanded(child: _node(i)),
          ],
        ],
      );

  Widget _node(int i) {
    final bool done = i == 0 || i < current;
    final bool now = i == current;
    final Color ring =
        done ? ReturnColors.green : (now ? kSellGold : ReturnColors.line);
    return Column(
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: 50.w,
              height: 50.w,
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: now ? const Color(0xFFFFF6D6) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: now ? 2.6 : 1.6),
              ),
              child: Opacity(
                opacity: done || now ? 1 : 0.45,
                child: Image.asset(_stages[i].$2, fit: BoxFit.contain),
              ),
            ),
            if (done)
              Positioned(
                right: -2.w,
                bottom: -2.w,
                child: Container(
                  width: 18.w,
                  height: 18.w,
                  decoration: BoxDecoration(
                    color: ReturnColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(Icons.check_rounded,
                      size: 11.sp, color: Colors.white),
                ),
              ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          _stages[i].$1,
          textAlign: TextAlign.center,
          style: sellBody(11,
              color: now || done ? ReturnColors.ink : ReturnColors.muted,
              w: now ? FontWeight.w800 : FontWeight.w600),
        ),
      ],
    );
  }
}

/// Navy card with a 3D picture: title, "what is happening", "what comes next".
class SellGuideCard extends StatelessWidget {
  const SellGuideCard({required this.guide, this.child, super.key});
  final SellGuide guide;

  /// Extra content (buttons, courier info…) shown under the text.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (guide.tone) {
      SellTone.good => const Color(0xFF7BE0A5),
      SellTone.warn => kSellGold,
      SellTone.bad => const Color(0xFFFF8A8F),
      SellTone.info => kSellGold,
    };
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF001F5F), Color(0xFF0B3A8C)],
        ),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (guide.needsAction)
                      Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                            color: kSellGold,
                            borderRadius: BorderRadius.circular(20.r)),
                        child: Text('YOUR TURN',
                            style: sellHead(10.5,
                                color: ReturnColors.indigo,
                                w: FontWeight.w900)),
                      ),
                    Text(guide.title, style: sellHead(21, color: Colors.white)),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              SellImage(guide.art, size: 92.w),
            ],
          ),
          SizedBox(height: 10.h),
          Text(guide.now,
              style: sellBody(14.5,
                  color: Colors.white.withValues(alpha: 0.95),
                  w: FontWeight.w500)),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.east_rounded, size: 18.sp, color: accent),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: <InlineSpan>[
                      TextSpan(
                          text: 'What happens next: ',
                          style:
                              sellBody(13, color: accent, w: FontWeight.w800)),
                      TextSpan(
                          text: guide.next,
                          style: sellBody(13,
                              color: Colors.white.withValues(alpha: 0.9))),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          if (child != null) ...<Widget>[SizedBox(height: 14.h), child!],
        ],
      ),
    );
  }
}

/// Vertical tracker (ticks for done steps, gold dot for the current one).
class SellTracker extends StatelessWidget {
  const SellTracker({required this.steps, super.key});
  final List<JourneyStep> steps;
  @override
  Widget build(BuildContext context) => Column(
        children: List<Widget>.generate(steps.length, (int i) {
          final JourneyStep s = steps[i];
          final bool last = i == steps.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 30.w,
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 24.w,
                        height: 24.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.done
                              ? ReturnColors.green
                              : (s.current ? kSellGold : Colors.white),
                          border: Border.all(
                            color: s.done
                                ? ReturnColors.green
                                : (s.current ? kSellGold : ReturnColors.line),
                            width: 2,
                          ),
                        ),
                        child: s.done
                            ? Icon(Icons.check_rounded,
                                size: 15.sp, color: Colors.white)
                            : s.current
                                ? Container(
                                    width: 8.w,
                                    height: 8.w,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: ReturnColors.indigo),
                                  )
                                : null,
                      ),
                      if (!last)
                        Expanded(
                            child: Container(
                                width: 2,
                                color: s.done
                                    ? ReturnColors.green
                                    : ReturnColors.line)),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: last ? 0 : 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          s.label,
                          style: sellBody(
                            14.5,
                            color: s.done || s.current
                                ? ReturnColors.ink
                                : ReturnColors.muted,
                            w: s.current ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        if (s.at != null)
                          Text(returnDate(s.at), style: sellBody(11.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      );
}

/// What a phone is called in lists.
String deviceTitle(String model, String variant) =>
    variant.isEmpty ? model : '$model · $variant';

/// Friendly label for a request's stage.
String stageLabel(String? stage, String status) {
  if (status == 'CANCELLED') return 'Cancelled';
  if (status == 'REJECTED') return 'Declined';
  return switch (stage) {
    'LISTED' => 'Waiting for offers',
    'OFFER_ACCEPTED' => 'Choose pickup',
    'PICKUP_REQUESTED' => 'Pickup being arranged',
    'PICKUP_SCHEDULED' => 'Pickup booked',
    'PICKED_UP' || 'IN_TRANSIT' => 'On its way',
    'RECEIVED' || 'INSPECTING' => 'Being checked',
    'FINAL_PRICE' => 'Check final price',
    'PAYOUT_PENDING' => 'Get your money',
    'PAID' => 'Paid',
    'RETURNING' => 'Coming back to you',
    _ => 'Closed',
  };
}

Color stageColor(String? stage, String status) {
  if (status == 'CANCELLED' || status == 'REJECTED') return ReturnColors.red;
  if (stage == 'PAID') return ReturnColors.green;
  if (stage == 'FINAL_PRICE' ||
      stage == 'PAYOUT_PENDING' ||
      stage == 'OFFER_ACCEPTED') {
    return const Color(0xFF8A5A00);
  }
  return ReturnColors.indigo;
}
