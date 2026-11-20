import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/shared/widgets/loading/loader_sprites.dart';

/// Order-submit loader: products drop into an open parcel one by one, the box
/// closes with a pop, then it bounces off ready for delivery.
class OrderPlacingLoader extends StatefulWidget {
  const OrderPlacingLoader({
    this.items = const <LoaderSprite>[
      LoaderSprite.mobile,
      LoaderSprite.headphones,
      LoaderSprite.smartwatch,
    ],
    this.size = 150,
    this.duration = const Duration(milliseconds: 4200),
    this.repeat = true,
    this.onClosed,
    super.key,
  });

  final List<LoaderSprite> items;
  final double size;
  final Duration duration;
  final bool repeat;

  /// Called once when the box closes (use to fire confetti etc.).
  final VoidCallback? onClosed;

  @override
  State<OrderPlacingLoader> createState() => _OrderPlacingLoaderState();
}

class _OrderPlacingLoaderState extends State<OrderPlacingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _closedFired = false;

  @override
  void initState() {
    super.initState();
    widget.repeat ? _c.repeat() : _c.forward();
    _c.addListener(() {
      final double closeAt = 0.04 + widget.items.length * 0.2 + 0.06;
      if (!_closedFired && _c.value >= closeAt) {
        _closedFired = true;
        widget.onClosed?.call();
      }
      if (_c.value < 0.05) {
        _closedFired = false;
      }
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
    final double w = s * 1.9;
    final double h = s * 2.1;
    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final double t = _c.value;
          final int n = widget.items.length;
          final List<Widget> falling = <Widget>[];
          double squash = 0;
          for (int i = 0; i < n; i++) {
            final double start = 0.04 + i * 0.2;
            final double end = start + 0.2;
            if (t < start || t > end + 0.05) continue;
            final double u = ((t - start) / (end - start)).clamp(0.0, 1.0);
            final double fall = Curves.easeIn.transform(u);
            final double y = -s * 1.15 + fall * s * 1.0;
            final double sc = 0.8 - 0.25 * fall;
            final double fade = u > 0.85 ? (1 - (u - 0.85) / 0.15) : 1;
            if (u >= 0.9) squash = math.max(squash, 0.1);
            falling.add(
              Positioned(
                bottom: s * 0.55 - y,
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: (1 - fall) * 0.4 * (i.isEven ? 1 : -1),
                    child: Transform.scale(
                      scale: sc,
                      child: SpriteImage(widget.items[i], size: s * 0.8),
                    ),
                  ),
                ),
              ),
            );
          }
          final double closeAt = 0.04 + n * 0.2 + 0.06;
          final bool closed = t >= closeAt;
          double pop = 0;
          if (closed) {
            final double u = ((t - closeAt) / 0.12).clamp(0.0, 1.0);
            pop = math.sin(u * math.pi) * 0.14;
          }
          // Hop away at the very end.
          double hop = 0;
          if (t > 0.9) {
            hop = math.sin(((t - 0.9) / 0.1) * math.pi) * s * 0.25;
          }
          return Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                bottom: s * 0.1,
                child: GroundShadow(width: s * 1.1, lift: hop / (s * 0.25)),
              ),
              Positioned(
                bottom: s * 0.25 + hop,
                child: Transform.scale(
                  scale: 1 - squash + pop,
                  alignment: Alignment.bottomCenter,
                  child: SpriteImage(
                    closed ? LoaderSprite.parcel : LoaderSprite.parcelOpen,
                    size: s * 1.25,
                  ),
                ),
              ),
              ...falling,
            ],
          );
        },
      ),
    );
  }
}

/// Small helper text style shared by the loader screens.
const TextStyle kLoaderTitle = TextStyle(
  fontFamily: 'Poppins',
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: AppColors.brandNavy,
);
