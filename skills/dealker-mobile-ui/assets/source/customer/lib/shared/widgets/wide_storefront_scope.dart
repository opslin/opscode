import 'package:flutter/widgets.dart';

/// Marks content rendered inside the wide web storefront shell.
class WideStorefrontScope extends InheritedWidget {
  const WideStorefrontScope({required super.child, super.key});

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WideStorefrontScope>() != null;

  @override
  bool updateShouldNotify(WideStorefrontScope oldWidget) => false;
}
