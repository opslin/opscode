import 'package:flutter/material.dart';

/// 3D-style artwork used by the loaders (flat PNG sprites, animated in
/// Flutter — no 3D engine involved).
enum LoaderSprite {
  mobile,
  headphones,
  smartwatch,
  tablet,
  powerbank,
  speaker,
  accessories,
  electronics,
  gift,
  bag,
  coin,
  parcel,
  parcelOpen,
  shield,
  card,
  wallet,
  tag,
  scooter;

  String get asset => switch (this) {
        LoaderSprite.gift => 'assets/loading/all.png',
        LoaderSprite.parcelOpen => 'assets/loading/parcel_open.png',
        _ => 'assets/loading/$name.png',
      };
}

class SpriteImage extends StatelessWidget {
  const SpriteImage(this.sprite, {required this.size, super.key});

  final LoaderSprite sprite;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      sprite.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Soft ground shadow that shrinks/fades as the item lifts (0 = on ground).
class GroundShadow extends StatelessWidget {
  const GroundShadow({required this.width, required this.lift, super.key});

  final double width;
  final double lift; // 0..1

  @override
  Widget build(BuildContext context) {
    final double s = 1 - 0.5 * lift;
    return Container(
      width: width * s,
      height: width * 0.2 * s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.elliptical(width, width * 0.2)),
        gradient: RadialGradient(
          colors: <Color>[
            const Color(0xFF001F5F).withValues(alpha: 0.22 * (1 - 0.6 * lift)),
            const Color(0xFF001F5F).withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

Matrix4 perspectiveRotateY(double angle) => Matrix4.identity()
  ..setEntry(3, 2, 0.0014)
  ..rotateY(angle);
