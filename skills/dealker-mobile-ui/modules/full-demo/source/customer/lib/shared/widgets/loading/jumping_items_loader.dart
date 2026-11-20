import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/shared/widgets/loading/loader_sprites.dart';

/// General page / app-start loader: products take turns jumping, spinning in
/// mid-air and squashing on landing, with a shadow on the ground.
class JumpingItemsLoader extends StatefulWidget {
  const JumpingItemsLoader({
    this.items = const <LoaderSprite>[
      LoaderSprite.mobile,
      LoaderSprite.headphones,
      LoaderSprite.smartwatch,
      LoaderSprite.bag,
      LoaderSprite.speaker,
    ],
    this.size = 150,
    super.key,
  });

  final List<LoaderSprite> items;
  final double size;

  @override
  State<JumpingItemsLoader> createState() => _JumpingItemsLoaderState();
}

class _JumpingItemsLoaderState extends State<JumpingItemsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  int _index = 0;
  double _last = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (_c.value < _last) {
        setState(() => _index = (_index + 1) % widget.items.length);
      }
      _last = _c.value;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    final double jump = s * 0.85;
    return SizedBox(
      width: s * 1.6,
      height: s + jump + s * 0.5,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final double t = _c.value;
          // 0..0.18 squat, 0.18..0.82 airborne, 0.82..1 land + squash.
          double lift = 0;
          double squash = 0;
          double spin = 0;
          if (t < 0.15) {
            squash = Curves.easeOut.transform(t / 0.15) * 0.14;
          } else if (t < 0.8) {
            final double u = (t - 0.15) / 0.65;
            lift = math.sin(math.pi * u);
            spin = Curves.easeInOut.transform(u) * 2 * math.pi;
            squash = -0.06 * lift; // stretch while rising
          } else {
            squash = Curves.easeOut.transform(1 - (t - 0.8) / 0.2) * 0.16;
          }
          final double pop = t < 0.15 ? Curves.easeOutBack.transform(t / 0.15) : 1;
          return Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Positioned(
                bottom: s * 0.25,
                child: GroundShadow(width: s * 0.95, lift: lift),
              ),
              Positioned(
                bottom: s * 0.25 + lift * jump,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..scale(1 + squash * 0.7, 1 - squash, 1),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: perspectiveRotateY(spin),
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * pop,
                      child: SpriteImage(
                        widget.items[_index],
                        size: s,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: _Dots(progress: t),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (int i) {
        final double p = (progress * 3 - i) % 3;
        final double a = (1 - (p - 0.5).abs().clamp(0.0, 1.0));
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(
              AppColors.brandNavy.withValues(alpha: 0.25),
              AppColors.brandYellow,
              a.clamp(0.0, 1.0),
            ),
          ),
        );
      }),
    );
  }
}
