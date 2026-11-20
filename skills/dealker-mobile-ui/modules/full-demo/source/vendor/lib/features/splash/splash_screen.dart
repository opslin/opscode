import 'package:flutter/material.dart';

import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/features/auth/presentation/widgets/brand_ui.dart';
import 'package:dealker_vendor/shared/widgets/dm_logo.dart';

/// Navy splash with the Dealkr artwork; the logo eases in while the session is restored.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  late final Animation<double> _fade = CurvedAnimation(
      parent: _c, curve: const Interval(0, 0.7, curve: Curves.easeOut));
  late final Animation<double> _scale = Tween(begin: 0.84, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.navyDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/auth/splash_bg.jpg',
              fit: BoxFit.cover, filterQuality: FilterQuality.high),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                              color: Brand.yellow.withValues(alpha: 0.35),
                              blurRadius: 50,
                              spreadRadius: 2),
                        ],
                      ),
                      child: const DmLogo(size: 128),
                    ),
                    const SizedBox(height: 26),
                    const Text('Dealkr Vendor',
                        style: TextStyle(
                            fontFamily: AppTheme.headingFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            letterSpacing: -0.5,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('Sell smarter. Grow faster.',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Brand.yellow)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 150,
            child: const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.6, color: Brand.yellow),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
