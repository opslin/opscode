import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Keeps purchase controls aligned with the desktop checkout content.
class WebPurchaseBar extends StatelessWidget {
  const WebPurchaseBar({required this.child, this.isWeb = kIsWeb, super.key});

  final Widget child;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    if (!isWeb || MediaQuery.sizeOf(context).width < 900) return child;
    return ColoredBox(
      color: Colors.white,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: SizedBox(width: 1200, child: child),
      ),
    );
  }
}
