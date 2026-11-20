import 'package:flutter/material.dart';


/// 3D artwork of the Repair journey (`assets/3d/repair/`).
String repairIssueArt(String key) => switch (key) {
      'SCREEN' => 'assets/3d/repair/screen.png',
      'BATTERY' => 'assets/3d/repair/battery.png',
      'CHARGING' => 'assets/3d/repair/charging.png',
      'WATER_DAMAGE' => 'assets/3d/repair/water.png',
      'CAMERA' => 'assets/3d/repair/camera.png',
      'AUDIO' => 'assets/3d/repair/audio.png',
      'SOFTWARE' => 'assets/3d/repair/software.png',
      'TOUCH' => 'assets/3d/repair/touch.png',
      'NETWORK' => 'assets/3d/repair/network.png',
      'BODY' => 'assets/3d/repair/body.png',
      'BOARD' => 'assets/3d/repair/board.png',
      'DATA' => 'assets/3d/repair/data.png',
      'BIOMETRIC' => 'assets/3d/profile/fingerprint.png',
      _ => 'assets/3d/repair/other.png',
    };

const String kRepairTechnician = 'assets/3d/repair/technician.png';
const String kRepairToolbox = 'assets/3d/repair/toolbox.png';
const String kRepairDone = 'assets/3d/repair/repaired.png';
const String kRepairSafe = 'assets/3d/repair/safe.png';
const String kRepairHandover = 'assets/3d/repair/handover.png';

/// A repair sprite, optionally floating gently.
class RArt extends StatelessWidget {
  const RArt(this.asset, {required this.size, this.float = false, super.key});

  final String asset;
  final double size;
  final bool float;

  @override
  Widget build(BuildContext context) {
    // CartArtImage animates enum sprites only; reuse its float for any asset.
    return float
        ? _Float(size: size, child: _img())
        : _img();
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
          offset: Offset(0, -widget.size * 0.05 * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
      );
}

const String kRepairShopArt = 'assets/3d/cart/pin.png';
