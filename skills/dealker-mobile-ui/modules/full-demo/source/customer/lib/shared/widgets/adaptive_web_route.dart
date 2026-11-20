import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/web_storefront_shell.dart';

/// Gives pages outside the branch navigator the same web navigation chrome.
class AdaptiveWebRoute extends StatelessWidget {
  const AdaptiveWebRoute({required this.child, this.isWeb = kIsWeb, super.key});

  final Widget child;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    if (!isWeb || MediaQuery.sizeOf(context).width < 700) return child;
    return WebStorefrontShell(
      selectedIndex: -1,
      onNavigate: (path) => context.push(path),
      onSelect: (index) {
        const paths = [
          RouteNames.home,
          RouteNames.orders,
          RouteNames.categories,
          RouteNames.profile
        ];
        context.go(paths[index]);
      },
      onSearch: (query) {
        final value = query.trim();
        final uri = Uri(
            path: RouteNames.search,
            queryParameters: value.isEmpty ? null : {'q': value});
        context.push(uri.toString());
      },
      onCart: () => context.push(RouteNames.cart),
      child: child,
    );
  }
}
