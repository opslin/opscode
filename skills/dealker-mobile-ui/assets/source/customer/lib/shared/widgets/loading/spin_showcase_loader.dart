import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/shared/widgets/loading/loader_sprites.dart';

/// Product-open loader: the product turns on a glowing pedestal while small
/// items orbit it (depth-scaled so they pass in front of / behind it).
class SpinShowcaseLoader extends StatefulWidget {
  const SpinShowcaseLoader({
    this.hero = LoaderSprite.mobile,
    this.orbit = const <LoaderSprite>[
      LoaderSprite.tag,
      LoaderSprite.coin,
      LoaderSprite.shield,
    ],
    this.size = 160,
    super.key,
  });

  final LoaderSprite hero;
  final List<LoaderSprite> orbit;
  final double size;

  @override
  State<SpinShowcaseLoader> createState() => _SpinShowcaseLoaderState();
}

class _SpinShowcaseLoaderState extends State<SpinShowcaseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    final double box = s * 2.1;
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final double t = _c.value;
          final double bob = math.sin(t * 2 * math.pi) * s * 0.05;
          final double glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
          final List<Widget> back = <Widget>[];
          final List<Widget> front = <Widget>[];
          for (int i = 0; i < widget.orbit.length; i++) {
            final double a = t * 2 * math.pi + i * 2 * math.pi / widget.orbit.length;
            final double depth = math.sin(a); // -1 back, 1 front
            final double x = math.cos(a) * s * 0.95;
            final double y = depth * s * 0.28;
            final double scale = 0.7 + 0.3 * (depth + 1) / 2;
            final Widget w = Positioned(
              left: box / 2 + x - s * 0.2,
              top: box / 2 + y - s * 0.2 + s * 0.1,
              child: Opacity(
                opacity: 0.55 + 0.45 * (depth + 1) / 2,
                child: Transform.scale(
                  scale: scale,
                  child: SpriteImage(widget.orbit[i], size: s * 0.4),
                ),
              ),
            );
            (depth < 0 ? back : front).add(w);
          }
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: s * 1.5,
                height: s * 1.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.brandYellow.withValues(alpha: 0.30 + 0.15 * glow),
                      AppColors.brandYellow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: box * 0.14,
                child: GroundShadow(width: s * 0.8, lift: 0.4 + 0.2 * glow),
              ),
              ...back,
              Transform.translate(
                offset: Offset(0, bob),
                child: Transform(
                  alignment: Alignment.center,
                  transform: perspectiveRotateY(t * 2 * math.pi),
                  child: SpriteImage(widget.hero, size: s),
                ),
              ),
              ...front,
            ],
          );
        },
      ),
    );
  }
}
