import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Keeps service journeys readable in a wide browser while retaining their
/// full-height scrolling and sticky actions.
class WebServiceFrame extends StatelessWidget {
  const WebServiceFrame(
      {required this.child,
      required this.panelColor,
      this.isWeb = kIsWeb,
      super.key});

  final Widget child;
  final bool isWeb;
  final Color panelColor;

  @override
  Widget build(BuildContext context) {
    if (!isWeb || MediaQuery.sizeOf(context).width < 700) return child;
    return ColoredBox(
      color: const Color(0xFFF3F5F8),
      child: Center(
        child: SizedBox(
            width: 960,
            height: double.infinity,
            child: ColoredBox(color: panelColor, child: child)),
      ),
    );
  }
}
