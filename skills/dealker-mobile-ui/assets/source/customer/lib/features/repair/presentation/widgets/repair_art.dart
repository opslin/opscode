import 'package:flutter/material.dart';

import 'package:dealker_app/features/cart/presentation/widgets/cart_art.dart';

/// 3D artwork of the Repair journey (`assets/repair/`).
String repairIssueArt(String key) => switch (key) {
      'SCREEN' => 'assets/repair/screen.png',
      'BATTERY' => 'assets/repair/battery.png',
      'CHARGING' => 'assets/repair/charging.png',
      'WATER_DAMAGE' => 'assets/repair/water.png',
      'CAMERA' => 'assets/repair/camera.png',
      'AUDIO' => 'assets/repair/audio.png',
      'SOFTWARE' => 'assets/repair/software.png',
      'TOUCH' => 'assets/repair/touch.png',
      'NETWORK' => 'assets/repair/network.png',
      'BODY' => 'assets/repair/body.png',
      'BOARD' => 'assets/repair/board.png',
      'DATA' => 'assets/repair/data.png',
      'BIOMETRIC' => 'assets/profile/fingerprint.png',
      _ => 'assets/repair/other.png',
    };

const String kRepairTechnician = 'assets/repair/technician.png';
const String kRepairToolbox = 'assets/repair/toolbox.png';
const String kRepairDone = 'assets/repair/repaired.png';
const String kRepairSafe = 'assets/repair/safe.png';
const String kRepairHandover = 'assets/repair/handover.png';

/// A repair sprite, optionally floating gently.
class RArt extends StatelessWidget {
  const RArt(this.asset, {required this.size, this.float = false, super.key});

  final String asset;
  final double size;
  final bool float;

  @override
  Widget build(BuildContext context) {
    // CartArtImage animates enum sprites only; reuse its float for any asset.
    return float ? _Float(size: size, child: _img()) : _img();
  }

  Widget _img() => Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
}

class _Float extends StatefulWidget {
  const _Float({required this.child, required this.size});

  final Widget child;
  final double size;

  @override
  State<_Float> createState() => _FloatState();
}

class _FloatState extends State<_Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(
              0, -widget.size * 0.05 * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
      );
}

// Keeps the cart_art import used for shared sprites referenced from repair.
const CartArt kRepairShopArt = CartArt.pin;
