import 'package:flutter/material.dart';

/// 3D artwork of the Exchange journey (`assets/exchange/`).
///
/// [exchangeTypeArt] takes the `icon` an admin picked for a device type in the dashboard.
String exchangeTypeArt(String icon) => switch (icon) {
      'phone' => 'assets/exchange/phone.png',
      'tablet' => 'assets/exchange/tablet.png',
      'laptop' => 'assets/exchange/laptop.png',
      'headphones' => 'assets/exchange/headphones.png',
      'earbuds' => 'assets/exchange/earbuds.png',
      'watch' => 'assets/exchange/watch.png',
      'speaker' => 'assets/exchange/speaker.png',
      'camera' => 'assets/exchange/camera.png',
      'console' => 'assets/exchange/console.png',
      _ => 'assets/exchange/swap.png',
    };

const String kExLikeNew = 'assets/exchange/likenew.png';
const String kExGood = 'assets/exchange/good.png';
const String kExWorn = 'assets/exchange/worn.png';
const String kExDamaged = 'assets/exchange/damaged.png';
const String kExBox = 'assets/exchange/box.png';
const String kExBill = 'assets/exchange/bill.png';
const String kExCharger = 'assets/exchange/charger.png';
const String kExSwap = 'assets/exchange/swap.png';
const String kExMoney = 'assets/exchange/money.png';

class ExArt extends StatelessWidget {
  const ExArt(this.asset, {required this.size, super.key});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
}
