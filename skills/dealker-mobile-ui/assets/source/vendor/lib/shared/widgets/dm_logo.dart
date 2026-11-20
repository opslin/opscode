import 'package:flutter/material.dart';

/// The Dealkr vendor logo (awning + bag on navy) as a rounded square, used on the
/// splash, welcome, login and profile screens and in the home header.
class DmLogo extends StatelessWidget {
  const DmLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/branding/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
