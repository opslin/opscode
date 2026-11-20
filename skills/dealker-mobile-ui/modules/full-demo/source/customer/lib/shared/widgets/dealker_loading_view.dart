import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Branded loading hero: the Dealkr bag with its orbiting products, gently
/// floating. Use for waits where a bare spinner feels cheap.
class DealkerLoadingView extends StatefulWidget {
  const DealkerLoadingView({this.size, super.key});

  final double? size;

  @override
  State<DealkerLoadingView> createState() => _DealkerLoadingViewState();
}

class _DealkerLoadingViewState extends State<DealkerLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size ?? 150.h;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double t = Curves.easeInOut.transform(_controller.value);
          return Transform.translate(
            offset: Offset(0, -8.h * t),
            child: Transform.scale(scale: 1 + 0.03 * t, child: child),
          );
        },
        child: Image.asset(
          'assets/images/dealker-loading-hero.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
