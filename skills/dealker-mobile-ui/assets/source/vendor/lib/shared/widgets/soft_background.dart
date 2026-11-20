import 'package:flutter/material.dart';

/// Pale blue→lavender wash with soft blobs, as on the Welcome/Register mockups.
class SoftBackground extends StatelessWidget {
  const SoftBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF3F6FF), Colors.white, Colors.white],
              ),
            ),
          ),
        ),
        Positioned(
            top: -120, left: -140, child: _blob(const Color(0xFFCFE0FF), 320)),
        Positioned(
            bottom: -150,
            left: -120,
            child: _blob(const Color(0xFFBFD8FF), 340)),
        Positioned(
            bottom: -170,
            right: -130,
            child: _blob(const Color(0xFFE3CCFA), 340)),
        child,
      ],
    );
  }

  Widget _blob(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [c.withValues(alpha: 0.75), c.withValues(alpha: 0)]),
          ),
        ),
      );
}
