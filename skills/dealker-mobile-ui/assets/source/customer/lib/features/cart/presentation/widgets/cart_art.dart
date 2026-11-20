import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dealker_app/core/theme/app_colors.dart';

/// 3D-style artwork for the cart (flat PNG sprites, animated in Flutter).
enum CartArt {
  coupon,
  cart,
  van,
  pin,
  clock,
  heart,
  trash,
  star,
  piggy,
  receipt,
  calendar,
  notepad,
  headset,
  verified,
  bolt,
  giftbox,
  bell,
  lock,
  emptyCart,
  wallet,
  coin,
  // Orders
  placed,
  confirmed,
  packed,
  rocket,
  ship,
  scooter,
  delivered,
  cancelled,
  returned,
  plane,
  truck,
  warehouse,
  refund,
  route,
  track,
  pending,
  parcels,
  thumbs,
  // Profile
  gavel,
  sellPhone,
  repair,
  document,
  share,
  info,
  logout,
  briefcase,
  cake,
  user,
  camera,
  gear,
  gamepad,
  chat,
  crown,
  mail,
  call,
  fingerprint;

  String get asset => switch (this) {
        CartArt.wallet => 'assets/loading/wallet.png',
        CartArt.coin => 'assets/loading/coin.png',
        CartArt.emptyCart => 'assets/cart/empty_cart.png',
        CartArt.placed ||
        CartArt.confirmed ||
        CartArt.packed ||
        CartArt.rocket ||
        CartArt.ship ||
        CartArt.scooter ||
        CartArt.delivered ||
        CartArt.cancelled ||
        CartArt.returned ||
        CartArt.plane ||
        CartArt.truck ||
        CartArt.warehouse ||
        CartArt.refund ||
        CartArt.route ||
        CartArt.track ||
        CartArt.pending ||
        CartArt.parcels ||
        CartArt.thumbs =>
          'assets/orders/$name.png',
        CartArt.gavel ||
        CartArt.sellPhone ||
        CartArt.repair ||
        CartArt.document ||
        CartArt.share ||
        CartArt.info ||
        CartArt.logout ||
        CartArt.briefcase ||
        CartArt.cake ||
        CartArt.user ||
        CartArt.camera ||
        CartArt.gear ||
        CartArt.gamepad ||
        CartArt.chat ||
        CartArt.crown ||
        CartArt.mail ||
        CartArt.call ||
        CartArt.fingerprint =>
          'assets/profile/$name.png',
        _ => 'assets/cart/$name.png',
      };
}

/// Sprite that can float (gentle bob + tilt) — keeps icons feeling alive.
class CartArtImage extends StatefulWidget {
  const CartArtImage(this.art,
      {required this.size, this.float = false, super.key});

  final CartArt art;
  final double size;
  final bool float;

  @override
  State<CartArtImage> createState() => _CartArtImageState();
}

class _CartArtImageState extends State<CartArtImage>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.float) {
      _c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2200 + (widget.art.index % 5) * 180),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget img = Image.asset(
      widget.art.asset,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    final AnimationController? c = _c;
    if (c == null) {
      return img;
    }
    return AnimatedBuilder(
      animation: c,
      child: img,
      builder: (context, child) {
        final double t = Curves.easeInOut.transform(c.value);
        return Transform.translate(
          offset: Offset(0, -widget.size * 0.06 * t),
          child: Transform.rotate(
            angle: math.sin(t * math.pi) * 0.04,
            child: child,
          ),
        );
      },
    );
  }
}

/// Custom wallet / points toggle: a gold coin rides a track, flips on every
/// change, and the track floods navy with a golden shimmer when on.
class DealkerCoinToggle extends StatefulWidget {
  const DealkerCoinToggle({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<DealkerCoinToggle> createState() => _DealkerCoinToggleState();
}

class _DealkerCoinToggleState extends State<DealkerCoinToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: widget.value ? 1 : 0,
  );

  @override
  void didUpdateWidget(DealkerCoinToggle old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      widget.value ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double w = 70;
    const double h = 38;
    const double knob = 30;
    final bool enabled = widget.onChanged != null;
    return Semantics(
      toggled: widget.value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onChanged!(!widget.value);
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: SizedBox(
            width: w,
            height: h + 6,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final double t = Curves.easeOutCubic.transform(_c.value);
                final double slide = Curves.easeInOutBack
                    .transform(_c.value)
                    .clamp(0.0, 1.0);
                final double flip =
                    Curves.easeOutBack.transform(_c.value) * 2 * math.pi;
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Track
                    Container(
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(h),
                        gradient: LinearGradient(
                          colors: <Color>[
                            Color.lerp(const Color(0xFFDDE4F3),
                                AppColors.brandNavy, t)!,
                            Color.lerp(const Color(0xFFE9EEF9),
                                const Color(0xFF14409A), t)!,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.brandNavy
                                .withValues(alpha: 0.10 + 0.22 * t),
                            blurRadius: 10 + 6 * t,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    // Label inside the track
                    Positioned(
                      left: 12,
                      child: Opacity(
                        opacity: t,
                        child: const Text('ON',
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: AppColors.brandYellow)),
                      ),
                    ),
                    Positioned(
                      right: 11,
                      child: Opacity(
                        opacity: 1 - t,
                        child: const Text('OFF',
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: Color(0xFF7E8CAB))),
                      ),
                    ),
                    // Coin knob
                    Positioned(
                      left: 4 + (w - knob - 8) * slide,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateY(flip),
                        child: Container(
                          width: knob,
                          height: knob,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.brandYellow
                                    .withValues(alpha: 0.35 * t),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Image.asset(CartArt.coin.asset,
                              fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
