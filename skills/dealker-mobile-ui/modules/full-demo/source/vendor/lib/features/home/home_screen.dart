import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/realtime/live_service.dart';
import 'package:dealker_vendor/core/realtime/visibility_reporter.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/abandoned_carts/application/cart_providers.dart';
import 'package:dealker_vendor/features/abandoned_carts/presentation/widgets/home_cart_card.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/business_profile/presentation/shop_location_section.dart';
import 'package:dealker_vendor/features/auth/presentation/screens/store_setup_screen.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_banner.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_actions.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_header_stats.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_marketplace.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/live_section.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/needs_action.dart';
import 'package:dealker_vendor/features/wholesale/application/wholesale_providers.dart';

/// Partner Hub — the vendor's landing page after sign-in.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    if (session != null && !session.hasVendorAccess)
      return const StoreSetupScreen();

    return VisibilityReporter(
        onChanged: (on) => ref.read(homeVisibleProvider.notifier).set(on),
        child: ShopLocationAutoPrompt(
        child: Scaffold(
      backgroundColor: AppColors.canvas,
      bottomNavigationBar: const HomeBottomNav(),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: RefreshIndicator(
          color: AppColors.primary,
          edgeOffset: MediaQuery.paddingOf(context).top,
          onRefresh: () async {
            refreshHome(ref);
            ref
              ..invalidate(cartSummaryProvider)
              ..invalidate(wholesaleListProvider);
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: const [
              HomeHeader(),
              Padding(
                padding: EdgeInsets.fromLTRB(14, 16, 14, 24),
                child: Column(
                  children: [
                    QuickActions(),
                    SizedBox(height: 16),
                    DemandBanner(),
                    SizedBox(height: 16),
                    NeedsAction(),
                    SizedBox(height: 16),
                    HomeCartCard(),
                    SizedBox(height: 18),
                    LiveAuctionsAndCampaigns(),
                    SizedBox(height: 22),
                    HomeMarketplace(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )));
  }
}
