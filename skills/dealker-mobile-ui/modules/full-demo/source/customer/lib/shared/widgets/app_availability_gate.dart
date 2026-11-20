import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/network/app_availability_provider.dart';
import 'package:dealker_app/routing/app_router.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/dealker_state_screen.dart';

class AppAvailabilityGate extends ConsumerWidget {
  const AppAvailabilityGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appAvailabilityProvider);

    return Stack(
      children: <Widget>[
        child,
        if (status == AppAvailabilityStatus.offline)
          Positioned.fill(
            child: DealkerStateScreen(
              illustrationAsset:
                  'assets/images/dealker-offline-state-illustration.png',
              icon: PhosphorIcons.wifiSlashBold,
              title: "You're offline",
              subtitle: 'Please check your internet connection\nand try again.',
              primaryLabel: 'Retry',
              onPrimary: () =>
                  ref.read(appAvailabilityProvider.notifier).retry(),
              secondaryLabel: 'Browse saved items',
              onSecondary: () {
                ref.read(appAvailabilityProvider.notifier).browseOffline();
                // Navigate via the router instance (this gate lives above the
                // Router subtree, so `context.go` has no GoRouter ancestor).
                ref.read(appRouterProvider).go(RouteNames.wishlist);
              },
            ),
          )
        else if (status == AppAvailabilityStatus.serviceUnavailable)
          Positioned.fill(
            child: DealkerStateScreen(
              illustrationAsset:
                  'assets/images/dealker-offline-state-illustration.png',
              icon: PhosphorIcons.cloudSlashBold,
              title: 'Service unavailable',
              subtitle:
                  'We could not reach Dealkr right now.\nPlease try again in a moment.',
              primaryLabel: 'Try again',
              onPrimary: () =>
                  ref.read(appAvailabilityProvider.notifier).retry(),
            ),
          ),
      ],
    );
  }
}
