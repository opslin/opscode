import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/shared/widgets/loading/loader_sprites.dart';

/// Payment loader: a card floats inside a spinning secure ring while coins
/// orbit around it. Messages rotate so a slow bank response doesn't feel stuck.
class PaymentLoader extends StatefulWidget {
  const PaymentLoader({
    this.messages = const <String>[
      'Securing your payment',
      'Contacting your bank',
      'Confirming payment',
    ],
    this.size = 140,
    super.key,
  });

  final List<String> messages;
  final double size;

  @override
  State<PaymentLoader> createState() => _PaymentLoaderState();
}

class _PaymentLoaderState extends State<PaymentLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  Timer? _timer;
  int _msg = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) setState(() => _msg = (_msg + 1) % widget.messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    final double box = s * 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: box,
          height: box,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final double t = _c.value;
              final double bob = math.sin(t * 4 * math.pi) * s * 0.04;
              final List<Widget> coins = <Widget>[];
              for (int i = 0; i < 3; i++) {
                final double a = -t * 2 * math.pi + i * 2 * math.pi / 3;
                final double depth = math.sin(a);
                final double r = s * 0.92;
                coins.add(
                  Positioned(
                    left: box / 2 + math.cos(a) * r - s * 0.13,
                    top: box / 2 + depth * r * 0.32 - s * 0.13,
                    child: Opacity(
                      opacity: 0.6 + 0.4 * (depth + 1) / 2,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: perspectiveRotateY(t * 6 * math.pi + i),
                        child: Transform.scale(
                          scale: 0.75 + 0.25 * (depth + 1) / 2,
                          child: SpriteImage(LoaderSprite.coin, size: s * 0.26),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CustomPaint(
                    size: Size.square(box * 0.82),
                    painter: _RingPainter(t),
                  ),
                  Transform.translate(
                    offset: Offset(0, bob),
                    child: Transform.rotate(
                      angle: math.sin(t * 2 * math.pi) * 0.08,
                      child: SpriteImage(LoaderSprite.card, size: s * 0.95),
                    ),
                  ),
                  ...coins,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            widget.messages[_msg],
            key: ValueKey<int>(_msg),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.brandNavy,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Please don't close the app",
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = AppColors.brandNavy.withValues(alpha: 0.08);
    canvas.drawArc(rect.deflate(3), 0, 2 * math.pi, false, track);
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: const <Color>[
          Color(0x00FFC400),
          AppColors.brandYellow,
          AppColors.brandNavy,
        ],
        transform: GradientRotation(t * 2 * math.pi - math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect.deflate(3), t * 2 * math.pi - math.pi / 2, math.pi * 1.2, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}
