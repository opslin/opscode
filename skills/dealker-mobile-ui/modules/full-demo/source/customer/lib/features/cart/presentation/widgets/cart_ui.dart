import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_art.dart';

export 'package:dealker_app/features/auctions/presentation/widgets/auction_ui.dart'
    show
        Bone,
        CloudArt,
        EmptyBoxArt,
        StateButton,
        StateView;
export 'package:dealker_app/features/cart/presentation/widgets/cart_art.dart';

/// Cart palette — Dealkr brand (navy + golden yellow on cool-white), kept
/// under the `AU` name so the cart widgets pick it up without per-file edits.
class AU {
  AU._();
  static const Color ink = Color(0xFF0A1B4D);
  static const Color indigo = AppColors.brandNavy;
  static const Color indigoSoft = Color(0xFFE8EEFB);
  static const Color muted = Color(0xFF5A6A8E);
  static const Color grey = Color(0xFF8793AB);
  static const Color border = Color(0xFFE3E8F3);
  static const Color chipBorder = Color(0xFFC5CEE3);
  static const Color band = Color(0xFFF5F7FC);
  // Extra tokens used by the Orders screens (same names as the auction page).
  static const Color live = Color(0xFFE5232E);
  static const Color liveSoft = Color(0xFFFDECEE);
  static const Color greenText = Color(0xFF15803D);
  static const Color greenSoft = Color(0xFFDDF5E4);
  static const Color amberText = Color(0xFF8A5A00);
  static const Color amberSoft = Color(0xFFFFF0C2);
  static const Color pillGrey = Color(0xFFEEF0F7);
  static const Color endedPill = Color(0xFF6E7487);
  static const Color verified = Color(0xFF4A8FB8);
  static const Color navy = AppColors.brandNavy;
}

/// Headings — Plus Jakarta Sans (geometric, friendly, strong at ExtraBold).
TextStyle jakarta(double size,
        {FontWeight w = FontWeight.w800, Color color = AU.ink, double? h}) =>
    TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: size,
        fontWeight: w,
        color: color,
        height: h,
        letterSpacing: -0.2);

/// Body + numbers — Inter with tabular figures so prices line up.
TextStyle dm(double size,
        {FontWeight w = FontWeight.w500, Color color = AU.grey, double? h}) =>
    TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: w,
        color: color,
        height: h,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

/// Colours that only the Cart page uses (measured from the approved cart design).
class CU {
  CU._();
  static const Color card = Colors.white;
  static const Color stripBg =
      Color(0xFFF1F5FD); // delivery strip, free-shipping nudge
  static const Color photoBg = Color(0xFFF4F5FB);
  static const Color savingsBg = Color(0xFFE3F6E9);
  static const Color green = Color(0xFF15803D);
  static const Color greenIcon = Color(0xFF1FA463);
  static const Color amberBg = Color(0xFFFFF1D6);
  static const Color amber = Color(0xFFB45309);
  static const Color amberIcon = Color(0xFFF59E0B);
  static const Color redBg = Color(0xFFFDE8E8);
  static const Color red = Color(0xFFD92D20);
  static const Color chipRedBg = Color(0xFFFDE9E3);
  static const Color orange = Color(0xFFF59E0B);
  static const Color coin = Color(0xFFF7C948);
  static const Color wallet = AppColors.brandNavy;
  static const Color disabled = Color(0xFFB7BECD);
}

BoxDecoration cartCard({Color? color}) => BoxDecoration(
      color: color ?? CU.card,
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(color: AU.border),
      boxShadow: <BoxShadow>[
        BoxShadow(
            color: const Color(0xFF0A1B4D).withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 8))
      ],
    );

/// Rounded square icon tile of the Offers / Points / Wallet cards.
class CartIconTile extends StatelessWidget {
  const CartIconTile(
      {this.icon,
      this.art,
      required this.bg,
      this.fg = Colors.white,
      super.key});
  final IconData? icon;

  /// 3D artwork — preferred over [icon]; floats gently.
  final CartArt? art;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: art != null ? AU.indigoSoft : bg,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: art != null
            ? Center(child: CartArtImage(art!, size: 34.w, float: true))
            : Icon(icon, color: fg, size: 24.sp),
      );
}

/// Custom animated toggle used by the Points and Wallet cards.
class CartSwitch extends StatelessWidget {
  const CartSwitch({required this.value, required this.onChanged, super.key});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) =>
      DealkerCoinToggle(value: value, onChanged: onChanged);
}

/// Light cloud with an indigo slash ("You're offline" on the cart).
class CloudSlashArt extends StatelessWidget {
  const CloudSlashArt({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 150.w,
      height: 120.h,
      child: CustomPaint(painter: _SlashPainter()));
}

class _SlashPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final double w = s.width, h = s.height;
    final Paint fill = Paint()..color = const Color(0xFFEAEEFB);
    final Paint line = Paint()
      ..color = const Color(0xFFB9C4EE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final Path cloud = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(w * .33, h * .62), radius: h * .26))
      ..addOval(
          Rect.fromCircle(center: Offset(w * .52, h * .46), radius: h * .32))
      ..addOval(
          Rect.fromCircle(center: Offset(w * .72, h * .64), radius: h * .24))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * .17, h * .6, w * .64, h * .3),
          Radius.circular(h * .15)));
    c.drawPath(cloud, fill);
    c.drawPath(cloud, line);
    c.drawLine(
        Offset(w * .38, h * .98),
        Offset(w * .74, h * .22),
        Paint()
          ..color = AU.indigo
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({this.size = 18, super.key});
  final double size;
  @override
  Widget build(BuildContext context) =>
      CartArtImage(CartArt.verified, size: size.sp);
}
