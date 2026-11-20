import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/features/auctions/data/auction_view.dart';

/// Colours of the Auctions page, measured from the approved design.
class AU {
  AU._();
  static const Color ink = Color(0xFF0B1033);
  static const Color indigo = Color(0xFF4F3FE0);
  static const Color indigoSoft = Color(0xFFEEEBFF);
  static const Color muted = Color(0xFF6B7390); // inactive tab, secondary text
  static const Color grey = Color(0xFF8A93AB); // "Sold by", counts
  static const Color live = Color(0xFFE5232E);
  static const Color liveSoft = Color(0xFFFDECEE);
  static const Color greenText = Color(0xFF15803D);
  static const Color greenSoft = Color(0xFFDDF5E4);
  static const Color amberText = Color(0xFF8A5A00);
  static const Color amberSoft = Color(0xFFFFF0C2);
  static const Color pillGrey = Color(0xFFEEF0F7);
  static const Color endedPill = Color(0xFF6E7487);
  static const Color border = Color(0xFFE6E9F2);
  static const Color chipBorder = Color(0xFFC9CFE3);
  static const Color band = Color(0xFFF7F8FD);
  static const Color verified = Color(0xFF4A8FB8);
  static const Color navy = Color(0xFF1B1760);
}

TextStyle jakarta(double size,
        {FontWeight w = FontWeight.w800, Color color = AU.ink, double? h}) =>
    TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: size,
        fontWeight: w,
        color: color,
        height: h);

TextStyle dm(double size,
        {FontWeight w = FontWeight.w500, Color color = AU.grey, double? h}) =>
    TextStyle(
        fontFamily: 'DMSans',
        fontSize: size,
        fontWeight: w,
        color: color,
        height: h);

/// Re-builds [builder] every second (countdowns) without rebuilding its parent.
class Ticking extends StatefulWidget {
  const Ticking({required this.builder, super.key});
  final Widget Function(BuildContext context) builder;
  @override
  State<Ticking> createState() => _TickingState();
}

class _TickingState extends State<Ticking> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Small rounded pill: [icon] [text].
class Pill extends StatelessWidget {
  const Pill({
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
    this.size = 11,
    this.vertical = 4,
    this.horizontal = 8,
    this.weight = FontWeight.w800,
    super.key,
  });
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final double size;
  final double vertical;
  final double horizontal;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: horizontal.w, vertical: vertical.h),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9.r)),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: (size + 1.5).sp, color: fg),
            SizedBox(width: 4.w)
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text,
                  maxLines: 1, style: jakarta(size.sp, w: weight, color: fg)),
            ),
          ),
        ]),
      );
}

/// Red LIVE badge.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
            color: AU.live, borderRadius: BorderRadius.circular(8.r)),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Container(
              width: 7.w,
              height: 7.w,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle)),
          SizedBox(width: 4.w),
          Text('LIVE', style: jakarta(10.5.sp, color: Colors.white)),
        ]),
      );
}

/// STARTS IN 2h / ENDED / LIVE — the status badge in the card's top-left corner.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.a, {super.key});
  final AuctionView a;
  @override
  Widget build(BuildContext context) {
    if (a.isLive && !a.isOverByClock) return const LiveBadge();
    if (a.isUpcoming) {
      return Ticking(
          builder: (_) => Pill(
                text: startsInLabel(a.startsIn ?? Duration.zero),
                bg: AU.pillGrey,
                fg: AU.ink,
                size: 10.5,
                vertical: 5,
                weight: FontWeight.w800,
              ));
    }
    return Pill(
        text: 'ENDED',
        bg: AU.endedPill,
        fg: Colors.white,
        size: 10.5,
        vertical: 5);
  }
}

/// Red clock + "02h 14m 08s" on a light-red pill; counts down every second.
class CountdownPill extends StatelessWidget {
  const CountdownPill(this.a,
      {this.solid = false, this.short = false, this.onDone, super.key});
  final AuctionView a;

  /// Solid red with white text (the Ending-soon strip).
  final bool solid;
  final bool short;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) => Ticking(builder: (_) {
        final Duration d = a.timeLeft ?? Duration.zero;
        if (d.inSeconds <= 0 && onDone != null)
          WidgetsBinding.instance.addPostFrameCallback((_) => onDone!());
        return Pill(
          text: short ? clockShort(d) : clockHms(d),
          bg: solid ? AU.live : AU.liveSoft,
          fg: solid ? Colors.white : AU.live,
          icon: PhosphorIconsRegular.clock,
          size: solid ? 11.5 : 12,
          vertical: solid ? 4 : 5,
        );
      });
}

class VerifiedCheck extends StatelessWidget {
  const VerifiedCheck({this.size = 14, super.key});
  final double size;
  @override
  Widget build(BuildContext context) =>
      Icon(PhosphorIconsFill.sealCheck, size: size.sp, color: AU.verified);
}

/// Heart toggle: outline, or filled indigo while watching.
class WatchHeart extends StatelessWidget {
  const WatchHeart({required this.on, required this.onTap, super.key});
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 22.w,
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Icon(on ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
              size: 22.sp, color: on ? AU.indigo : AU.ink),
        ),
      );
}

/// Pulsing grey block for skeletons.
class Bone extends StatefulWidget {
  const Bone({this.width, required this.height, this.radius = 8, super.key});
  final double? width;
  final double height;
  final double radius;
  @override
  State<Bone> createState() => _BoneState();
}

class _BoneState extends State<Bone> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
                const Color(0xFFEBEDF5), const Color(0xFFF5F6FB), _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

// ── Illustrations for the empty / error / offline states ─────────────────────

/// Open blue box with rays ("No live auctions right now").
class EmptyBoxArt extends StatelessWidget {
  const EmptyBoxArt({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 150.w, height: 130.h, child: CustomPaint(painter: _BoxPainter()));
}

class _BoxPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final double w = s.width, h = s.height;
    final Paint ray = Paint()
      ..color = AU.indigo
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(w * .5, 0), Offset(w * .5, h * .17), ray);
    c.drawLine(Offset(w * .22, h * .06), Offset(w * .33, h * .18), ray);
    c.drawLine(Offset(w * .78, h * .06), Offset(w * .67, h * .18), ray);
    Path poly(List<Offset> p) => Path()..addPolygon(p, true);
    final Offset a = Offset(w * .5, h * .30),
        left = Offset(w * .12, h * .50),
        right = Offset(w * .88, h * .50),
        mid = Offset(w * .5, h * .62);
    c.drawPath(poly(<Offset>[a, left, mid, right]),
        Paint()..color = const Color(0xFF8E9CFB));
    // front left / right faces
    c.drawPath(
        poly(<Offset>[
          Offset(w * .22, h * .56),
          mid,
          Offset(w * .5, h),
          Offset(w * .22, h * .82)
        ]),
        Paint()..color = const Color(0xFF4F5FE8));
    c.drawPath(
        poly(<Offset>[
          mid,
          Offset(w * .78, h * .56),
          Offset(w * .78, h * .82),
          Offset(w * .5, h)
        ]),
        Paint()..color = const Color(0xFF6B7BF3));
    // open flaps
    c.drawPath(
        poly(<Offset>[
          Offset(w * .12, h * .50),
          Offset(w * .30, h * .38),
          mid,
          Offset(w * .22, h * .56)
        ]),
        Paint()..color = const Color(0xFF7E8DF6));
    c.drawPath(
        poly(<Offset>[
          Offset(w * .88, h * .50),
          Offset(w * .70, h * .38),
          mid,
          Offset(w * .78, h * .56)
        ]),
        Paint()..color = const Color(0xFFA9B4FB));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Grey cloud with a red "!" ("Couldn't load auctions") or a wifi-off glyph ("You're offline").
class CloudArt extends StatelessWidget {
  const CloudArt({required this.offline, super.key});
  final bool offline;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150.w,
        height: 120.h,
        child: Stack(alignment: Alignment.center, children: <Widget>[
          CustomPaint(size: Size(150.w, 110.h), painter: _CloudPainter()),
          if (offline)
            Padding(
              padding: EdgeInsets.only(top: 14.h),
              child: Icon(PhosphorIconsRegular.wifiSlash,
                  size: 46.sp, color: const Color(0xFF8D93AE)),
            )
          else
            Positioned(
              bottom: 2.h,
              child: Container(
                width: 46.w,
                height: 46.w,
                decoration: const BoxDecoration(
                    color: Color(0xFFEF4565), shape: BoxShape.circle),
                child: Icon(PhosphorIconsBold.exclamationMark,
                    color: Colors.white, size: 26.sp),
              ),
            ),
        ]),
      );
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final Paint p = Paint()..color = const Color(0xFFDFE2F2);
    final double w = s.width, h = s.height;
    c.drawCircle(Offset(w * .36, h * .56), h * .34, p);
    c.drawCircle(Offset(w * .56, h * .40), h * .40, p);
    c.drawCircle(Offset(w * .74, h * .60), h * .30, p);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .18, h * .55, w * .66, h * .38),
            Radius.circular(h * .19)),
        p);
    c.drawCircle(
        Offset(w * .90, h * .30), 3, Paint()..color = const Color(0xFFB9C0E6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Centered illustration + title + body + button, on the faint page background.
class StateView extends StatelessWidget {
  const StateView(
      {required this.art,
      required this.title,
      required this.body,
      required this.button,
      super.key});
  final Widget art;
  final String title;
  final String body;
  final Widget button;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32.w, 0, 32.w, 80.h),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            art,
            SizedBox(height: 26.h),
            Text(title, textAlign: TextAlign.center, style: jakarta(20.sp)),
            SizedBox(height: 8.h),
            Text(body,
                textAlign: TextAlign.center,
                style: dm(14.sp, color: const Color(0xFF3F4663), h: 1.45)),
            SizedBox(height: 24.h),
            button,
          ]),
        ),
      );
}

/// Indigo filled button used by the state views.
class StateButton extends StatelessWidget {
  const StateButton(
      {required this.label,
      required this.onTap,
      this.icon,
      this.busy = false,
      super.key});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52.h,
        child: FilledButton(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AU.indigo,
            padding: EdgeInsets.symmetric(horizontal: 34.w),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r)),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 20.sp, color: Colors.white),
                    SizedBox(width: 8.w)
                  ],
                  Flexible(
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label,
                              style: jakarta(16.sp, color: Colors.white)))),
                ]),
        ),
      );
}

double minMax(double v, double a, double b) => math.max(a, math.min(b, v));
