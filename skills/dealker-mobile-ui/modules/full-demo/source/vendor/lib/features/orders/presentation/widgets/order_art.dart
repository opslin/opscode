import 'package:flutter/material.dart';

/// 3D artwork used across the vendor order flow (same sprites the customer app shows, so both sides
/// of an order look alike). Pass the raw seller-order status to [OrderArt.forStatus].
enum OrderArt {
  placed('assets/orders/placed.png'),
  confirmed('assets/orders/confirmed.png'),
  packed('assets/orders/packed.png'),
  ship('assets/orders/ship.png'),
  truck('assets/orders/truck.png'),
  scooter('assets/orders/scooter.png'),
  rocket('assets/orders/rocket.png'),
  delivered('assets/orders/delivered.png'),
  cancelled('assets/orders/cancelled.png'),
  returned('assets/orders/returned.png'),
  pending('assets/orders/pending.png'),
  track('assets/orders/track.png'),
  parcels('assets/orders/parcels.png'),
  thumbs('assets/orders/thumbs.png'),
  parcel('assets/art/parcel.png'),
  parcelOpen('assets/art/parcel_open.png'),
  wallet('assets/art/wallet.png'),
  coin('assets/art/coin.png'),
  chat('assets/art/chat.png'),
  call('assets/art/call.png'),
  user('assets/art/user.png');

  const OrderArt(this.asset);
  final String asset;

  static OrderArt forStatus(String status, {bool awaitingPayment = false}) {
    if (awaitingPayment) return OrderArt.pending;
    return switch (status.toUpperCase()) {
      'ORDER_PLACED' => OrderArt.placed,
      'CONFIRMED' => OrderArt.confirmed,
      'PACKED' || 'READY_TO_SHIP' => OrderArt.packed,
      'SHIPPED' => OrderArt.truck,
      'OUT_FOR_DELIVERY' => OrderArt.scooter,
      'DELIVERED' || 'CLOSED' => OrderArt.delivered,
      'RETURNED' => OrderArt.returned,
      _ => OrderArt.cancelled,
    };
  }
}

class OrderArtImage extends StatelessWidget {
  const OrderArtImage(this.art, {super.key, this.size = 48});
  final OrderArt art;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(art.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size));
}

/// Gently bobs up and down so the hero artwork feels alive.
class FloatingArt extends StatefulWidget {
  const FloatingArt(this.art, {super.key, this.size = 96});
  final OrderArt art;
  final double size;

  @override
  State<FloatingArt> createState() => _FloatingArtState();
}

class _FloatingArtState extends State<FloatingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
            offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
            child: child),
        child: OrderArtImage(widget.art, size: widget.size),
      );
}
