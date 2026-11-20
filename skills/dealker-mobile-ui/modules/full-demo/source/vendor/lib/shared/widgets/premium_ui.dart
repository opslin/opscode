import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';

/// Paths of the shared 3D artwork (same set the customer app uses, plus a few vendor-only extras).
class A3 {
  A3._();
  static String repair(String n) => 'assets/3d/repair/$n.png';
  static String sell(String n) => 'assets/3d/sell/$n.png';
  static String profile(String n) => 'assets/3d/profile/$n.png';
  static String shop(int n) => 'assets/3d/shops/shop$n.png';
  static String cart(String n) => 'assets/3d/cart/$n.png';
  static String exchange(String n) => 'assets/3d/exchange/$n.png';
  static String extra(String n) => 'assets/3d/new/$n.png';
}

/// A 3D picture that gently floats, so hero art feels alive without being distracting.
class Art3D extends StatefulWidget {
  const Art3D(this.path, {super.key, this.size = 80, this.float = false, this.tilt = 0});
  final String path;
  final double size;
  final bool float;
  final double tilt;

  @override
  State<Art3D> createState() => _Art3DState();
}

class _Art3DState extends State<Art3D> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour "reduce motion": no endless floating animation (also keeps tests settling).
    final still = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        Platform.environment.containsKey('FLUTTER_TEST');
    if (widget.float && !still) {
      _c ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    } else {
      _c?.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(widget.path,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => SizedBox(width: widget.size, height: widget.size));
    if (_c == null) {
      return widget.tilt == 0 ? img : Transform.rotate(angle: widget.tilt, child: img);
    }
    return AnimatedBuilder(
      animation: _c!,
      builder: (_, child) {
        final t = math.sin(_c!.value * math.pi * 2);
        return Transform.translate(
          offset: Offset(0, t * 5),
          child: Transform.rotate(angle: widget.tilt + t * 0.025, child: child),
        );
      },
      child: img,
    );
  }
}

/// Big gradient banner with floating 3D art, soft glow circles and an optional bottom row.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.art,
    this.colors = const [Color(0xFF3A63F0), Color(0xFF2038B8)],
    this.bottom,
    this.cta,
    this.artSize = 112,
  });

  final String title;
  final String subtitle;
  final String art;
  final List<Color> colors;
  final Widget? bottom;
  final Widget? cta;
  final double artSize;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.none,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(children: [
            Positioned(right: -40, top: -50, child: _glow(170, 0.10)),
            Positioned(left: -30, bottom: -60, child: _glow(140, 0.07)),
            Positioned(right: 60, bottom: 10, child: _glow(26, 0.14)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22, height: 1.15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.35)),
                      if (cta != null) ...[const SizedBox(height: 14), cta!],
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Art3D(art, size: artSize, float: true),
                ]),
                if (bottom != null) ...[const SizedBox(height: 14), bottom!],
              ]),
            ),
          ]),
        ),
      );

  Widget _glow(double s, double a) => Container(
      width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)));
}

/// Small translucent stat used inside a [HeroBanner].
class HeroStat extends StatelessWidget {
  const HeroStat(this.value, this.label, {super.key});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
          ]),
        ),
      );
}

/// A white pill button for use on a gradient banner.
class HeroButton extends StatelessWidget {
  const HeroButton(this.label, {super.key, required this.onTap, this.icon, this.color = const Color(0xFF2038B8)});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );
}

/// Option card with 3D art for pickers (auction type, campaign type, product type ...).
class ArtOptionCard extends StatelessWidget {
  const ArtOptionCard({
    super.key,
    required this.art,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.accent = const Color(0xFF2B55E6),
    this.badge,
    this.bullets = const [],
  });

  final String art;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final String? badge;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? accent : AppColors.cardBorder, width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                  color: (selected ? accent : const Color(0xFF1B2A6B)).withValues(alpha: selected ? 0.22 : 0.07),
                  blurRadius: selected ? 18 : 12,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [accent.withValues(alpha: 0.18), accent.withValues(alpha: 0.04)]),
                shape: BoxShape.circle,
              ),
              child: Center(child: Art3D(art, size: 62, float: selected)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                      child: Text(title,
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.navy))),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFFE9A8), borderRadius: BorderRadius.circular(10)),
                      child: Text(badge!,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF7A5200))),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textSecondary)),
                for (final b in bullets)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(PhosphorIconsBold.check, size: 13, color: accent)),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(b,
                              style: const TextStyle(fontSize: 12.5, height: 1.3, color: AppColors.textSecondary))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : Colors.transparent,
                  border: Border.all(color: selected ? accent : AppColors.cardBorder, width: 2)),
              child: selected ? const Icon(PhosphorIconsBold.check, size: 15, color: Colors.white) : null,
            ),
          ]),
        ),
      );
}

/// Empty / first-time state with a big floating 3D picture.
class ArtEmpty extends StatelessWidget {
  const ArtEmpty({super.key, required this.art, required this.title, required this.message, this.action});
  final String art;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [const Color(0xFF2B55E6).withValues(alpha: 0.14), Colors.transparent]),
            ),
            child: Center(child: Art3D(art, size: 112, float: true)),
          ),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondary)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// White elevated section card used across redesigned screens.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x141B2A6B), blurRadius: 14, offset: Offset(0, 5))],
          ),
          child: child,
        ),
      );
}

/// Tappable tile with a 3D picture and a label; used for quick-action grids.
class ArtTile extends StatelessWidget {
  const ArtTile({super.key, required this.art, required this.label, required this.onTap, this.sub});
  final String art;
  final String label;
  final String? sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x141B2A6B), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Art3D(art, size: 54),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.navy)),
            if (sub != null)
              Text(sub!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      );
}

/// Square-ish selectable tile with a 3D picture on top (channel / product-type pickers).
class ArtChoiceTile extends StatelessWidget {
  const ArtChoiceTile({
    super.key,
    required this.art,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
    this.accent = const Color(0xFF2B55E6),
    this.artSize = 52,
  });
  final String art;
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final double artSize;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? accent : AppColors.cardBorder, width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                  color: (selected ? accent : const Color(0xFF1B2A6B)).withValues(alpha: selected ? 0.2 : 0.06),
                  blurRadius: selected ? 14 : 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  height: artSize + 4,
                  child: Center(child: Art3D(art, size: artSize, float: selected))),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? accent : AppColors.navy)),
              ),
              if (sub != null)
                Text(sub!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11, height: 1.25, color: AppColors.textSecondary)),
            ]),
            if (selected)
              Positioned(
                right: -2,
                top: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: const Icon(PhosphorIconsBold.check, size: 12, color: Colors.white),
                ),
              ),
          ]),
        ),
      );
}
