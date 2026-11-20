import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_vendor/features/abandoned_carts/presentation/screens/abandoned_carts_screen.dart';
import 'package:dealker_vendor/features/deals/presentation/deal_detail_screen.dart';
import 'package:dealker_vendor/features/deals/presentation/deals_screen.dart';
import 'package:dealker_vendor/features/abandoned_carts/presentation/screens/cart_detail_screen.dart';
import 'package:dealker_vendor/features/abandoned_carts/presentation/screens/send_reminder_screen.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/auth/presentation/screens/login_screen.dart';
import 'package:dealker_vendor/features/auth/presentation/screens/otp_screen.dart';
import 'package:dealker_vendor/features/auth/presentation/screens/register_screen.dart';
import 'package:dealker_vendor/features/auth/presentation/screens/welcome_screen.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:dealker_vendor/features/orders/presentation/screens/orders_screen.dart';
import 'package:dealker_vendor/features/orders/presentation/screens/repair_detail_screen.dart';
import 'package:dealker_vendor/features/auctions/presentation/screens/auction_chat_screen.dart';
import 'package:dealker_vendor/features/auctions/presentation/screens/auction_created_screen.dart';
import 'package:dealker_vendor/features/auctions/presentation/screens/auctions_hub_screen.dart';
import 'package:dealker_vendor/features/auctions/presentation/screens/create_auction_screen.dart';
import 'package:dealker_vendor/features/auctions/presentation/screens/lot_detail_screen.dart';
import 'package:dealker_vendor/features/auctions/presentation/screens/my_auction_detail_screen.dart';
import 'package:dealker_vendor/features/demand/presentation/screens/demand_hub_screen.dart';
import 'package:dealker_vendor/features/demand/presentation/screens/offer_screen.dart';
import 'package:dealker_vendor/features/demand/presentation/screens/order_tracking_screen.dart';
import 'package:dealker_vendor/features/demand/presentation/screens/payment_screen.dart';
import 'package:dealker_vendor/features/demand/presentation/screens/post_demand_screen.dart';
import 'package:dealker_vendor/features/demand/presentation/screens/requirement_screen.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/screens/ad_wallet_screen.dart';
import 'package:dealker_vendor/features/business_profile/presentation/business_profile_screen.dart';
import 'package:dealker_vendor/features/payouts/presentation/payout_history_screen.dart';
import 'package:dealker_vendor/features/returns/presentation/return_chat_screen.dart';
import 'package:dealker_vendor/features/returns/presentation/return_detail_screen.dart';
import 'package:dealker_vendor/features/returns/presentation/returns_screen.dart';
import 'package:dealker_vendor/features/repairs/data/offer_draft.dart';
import 'package:dealker_vendor/features/repairs/presentation/device_check_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/job_quote_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_chat_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_handover_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ready_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_inbox_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_job_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_prices_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_progress_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_request_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/send_offer_screen.dart';
import 'package:dealker_vendor/features/repairs/presentation/set_price_screen.dart';
import 'package:dealker_vendor/features/sell_leads/presentation/sell_lead_chat_screen.dart';
import 'package:dealker_vendor/features/sell_leads/presentation/sell_lead_detail_screen.dart';
import 'package:dealker_vendor/features/sell_leads/presentation/sell_leads_screen.dart';
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_add_address_screen.dart' as rb;
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_booking_screens.dart' as rb;
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_chat_screen.dart' as rb;
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_home_screen.dart' as rb;
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_my_screen.dart' as rb;
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_pay_screen.dart' as rb;
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_quotes_screen.dart' as rb;
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_request_screen.dart' as rb;
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_shop_screen.dart' as rb;
import 'package:dealker_vendor/features/repair_book/presentation/screens/repair_status_screen.dart' as rb;
import 'package:dealker_vendor/features/my_orders/presentation/my_orders_screen.dart';
import 'package:dealker_vendor/features/wholesale/presentation/cart_screen.dart';
import 'package:dealker_vendor/features/wholesale/presentation/marketplace_screen.dart';
import 'package:dealker_vendor/features/wholesale/presentation/wholesale_orders_screen.dart';
import 'package:dealker_vendor/features/wholesale/presentation/wholesale_screens.dart';
import 'package:dealker_vendor/features/wallet/presentation/wallet_screen.dart';
import 'package:dealker_vendor/features/campaigns/presentation/screens/campaign_created_screen.dart';
import 'package:dealker_vendor/features/campaigns/presentation/screens/campaign_detail_screen.dart';
import 'package:dealker_vendor/features/campaigns/presentation/screens/campaigns_screen.dart';
import 'package:dealker_vendor/features/campaigns/presentation/screens/create_campaign_screen.dart';
import 'package:dealker_vendor/features/home/home_screen.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/presentation/screens/add_product_screen.dart';
import 'package:dealker_vendor/features/products/presentation/screens/bulk_add_screen.dart';
import 'package:dealker_vendor/features/products/presentation/screens/product_manage_screen.dart';
import 'package:dealker_vendor/features/products/presentation/screens/product_media_edit_screen.dart';
import 'package:dealker_vendor/features/products/presentation/screens/product_submitted_screen.dart';
import 'package:dealker_vendor/features/products/presentation/screens/products_screen.dart';
import 'package:dealker_vendor/features/profile/presentation/profile_screen.dart';
import 'package:dealker_vendor/features/splash/splash_screen.dart';
import 'package:dealker_vendor/features/store_settings/presentation/store_settings_screen.dart';
import 'package:dealker_vendor/features/support/presentation/help_support_screen.dart';
import 'package:dealker_vendor/features/support/presentation/new_ticket_screen.dart';
import 'package:dealker_vendor/features/support/presentation/notifications_screen.dart';
import 'package:dealker_vendor/features/support/presentation/support_chat_screen.dart';
import 'package:dealker_vendor/features/subscription/presentation/settings_screen.dart';
import 'package:dealker_vendor/features/subscription/presentation/subscription_screen.dart';
import 'package:dealker_vendor/routing/route_names.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (auth.restoring) return loc == Routes.splash ? null : Routes.splash;
      final isPublic = const {
        Routes.welcome,
        Routes.login,
        Routes.register,
        Routes.otp
      }.contains(loc);
      // Signed-in users leave the auth screens; every other route is theirs.
      if (auth.isSignedIn) {
        return (isPublic || loc == Routes.splash) ? Routes.home : null;
      }
      if (!isPublic) return Routes.welcome;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: Routes.otp,
          builder: (_, s) => OtpScreen(args: s.extra! as OtpArgs)),
      GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
      GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen()),
      GoRoute(path: Routes.myOrders, builder: (_, __) => const MyOrdersScreen()),
      GoRoute(path: '/profile/addresses/add', builder: (_, __) => const rb.RepairAddAddressScreen()),
      // Repair as a CUSTOMER: the vendor sends a device (or a bulk lot) for repair, picks a shop's offer, pays, tracks.
      // Ported from the customer app; the vendor's own repair-partner screens stay under /repairs.
      GoRoute(
        path: '/repair',
        builder: (_, __) => const rb.RepairHomeScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const rb.RepairRequestScreen()),
          GoRoute(path: 'mine', builder: (_, __) => const rb.RepairMyScreen()),
          GoRoute(
            path: ':id',
            builder: (_, s) => rb.RepairStatusScreen(repairId: s.pathParameters['id'] ?? ''),
            routes: [
              GoRoute(
                path: 'quotes',
                builder: (_, s) => rb.RepairQuotesScreen(repairId: s.pathParameters['id'] ?? ''),
                routes: [
                  GoRoute(
                    path: ':offerId',
                    builder: (_, s) => rb.RepairShopScreen(
                        repairId: s.pathParameters['id'] ?? '', offerId: s.pathParameters['offerId'] ?? ''),
                  ),
                ],
              ),
              GoRoute(
                path: 'book/:offerId',
                builder: (_, s) => rb.RepairAppointmentTypeScreen(
                    repairId: s.pathParameters['id'] ?? '', offerId: s.pathParameters['offerId'] ?? ''),
                routes: [
                  GoRoute(
                    path: 'store',
                    builder: (_, s) => rb.RepairStoreBookingScreen(
                        repairId: s.pathParameters['id'] ?? '', offerId: s.pathParameters['offerId'] ?? ''),
                  ),
                  GoRoute(
                    path: 'pickup',
                    builder: (_, s) => rb.RepairPickupBookingScreen(
                        repairId: s.pathParameters['id'] ?? '', offerId: s.pathParameters['offerId'] ?? ''),
                  ),
                ],
              ),
              GoRoute(path: 'chat', builder: (_, s) => rb.RepairChatScreen(repairId: s.pathParameters['id'] ?? '')),
              GoRoute(path: 'pay', builder: (_, s) => rb.RepairPayScreen(repairId: s.pathParameters['id'] ?? '')),
              GoRoute(path: 'confirmed', builder: (_, s) => rb.RepairConfirmedScreen(repairId: s.pathParameters['id'] ?? '')),
            ],
          ),
        ],
      ),

      GoRoute(
          path: Routes.products, builder: (_, __) => const ProductsScreen()),
      GoRoute(
          path: Routes.productAdd,
          builder: (_, __) => const AddProductScreen()),
      GoRoute(
          path: Routes.productBulk, builder: (_, __) => const BulkAddScreen()),
      GoRoute(
          path: Routes.productSubmitted,
          builder: (_, s) =>
              ProductSubmittedScreen(item: s.extra! as ListingDetail)),
      GoRoute(
          path: '/products/view/:id',
          builder: (_, s) => ProductManageScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/products/view/:id/media',
          builder: (_, s) =>
              ProductMediaEditScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: Routes.orders,
          builder: (_, s) => OrdersScreen(
              initialType: s.uri.queryParameters['type'] ?? 'all',
              initialTab: s.uri.queryParameters['tab'] ?? 'all')),
      GoRoute(
          path: '/orders/view/:id',
          builder: (_, s) => OrderDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/orders/repair/:id',
          builder: (_, s) => RepairDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: Routes.repairs, builder: (_, __) => const RepairInboxScreen()),
      GoRoute(
          path: Routes.repairPrices,
          builder: (_, __) => const RepairPricesScreen()),
      GoRoute(
          path: Routes.repairPriceAdd,
          builder: (_, __) => const AddRepairServiceScreen()),
      GoRoute(
          path: '/repairs/request/:id',
          builder: (_, s) => RepairRequestScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/repairs/request/:id/price',
          builder: (_, s) => SetPriceScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/repairs/request/:id/offer',
          builder: (_, s) => SendOfferScreen(draft: s.extra! as OfferDraft)),
      GoRoute(
          path: '/repairs/job/:id',
          builder: (_, s) => RepairJobScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/repairs/job/:id/check',
          builder: (_, s) => DeviceCheckScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/repairs/job/:id/quote',
          builder: (_, s) => JobQuoteScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/repairs/job/:id/progress',
          builder: (_, s) => RepairProgressScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/repairs/job/:id/chat',
          builder: (_, s) => RepairChatScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/repairs/job/:id/ready',
          builder: (_, s) => RepairReadyScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/repairs/job/:id/handover',
          builder: (_, s) => RepairHandoverScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: Routes.auctions, builder: (_, __) => const AuctionsHubScreen()),
      GoRoute(
          path: Routes.auctionCreate,
          builder: (_, __) => const CreateAuctionScreen()),
      GoRoute(
          path: Routes.auctionCreated,
          builder: (_, s) =>
              AuctionCreatedScreen(auction: s.extra! as AuctionItem)),
      GoRoute(
          path: '/auctions/view/:id/chat',
          builder: (_, s) => AuctionChatScreen(
              id: s.pathParameters['id']!, title: s.extra as String?)),
      GoRoute(
          path: '/auctions/view/:id',
          builder: (_, s) =>
              MyAuctionDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/auctions/lot/:id',
          builder: (_, s) => LotDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: Routes.campaigns, builder: (_, __) => const CampaignsScreen()),
      GoRoute(
          path: Routes.campaignCreate,
          builder: (_, __) => const CreateCampaignScreen()),
      GoRoute(
          path: Routes.campaignCreated,
          builder: (_, s) =>
              CampaignCreatedScreen(campaign: s.extra! as CampaignDetail)),
      GoRoute(
          path: Routes.adWallet, builder: (_, __) => const AdWalletScreen()),
      GoRoute(path: Routes.wallet, builder: (_, __) => const WalletScreen()),
      GoRoute(
          path: Routes.businessProfile,
          builder: (_, __) => const BusinessProfileScreen()),
      GoRoute(path: Routes.settings, builder: (_, __) => const SettingsScreen()),
      GoRoute(path: Routes.help, builder: (_, __) => const HelpSupportScreen()),
      GoRoute(path: Routes.helpNew, builder: (_, __) => const NewTicketScreen()),
      GoRoute(
          path: '/help/chat/:id',
          builder: (_, s) => SupportChatScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: Routes.notifications,
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: Routes.storeSettings,
          builder: (_, __) => const StoreSettingsScreen()),
      GoRoute(
          path: Routes.subscription,
          builder: (_, __) => const SubscriptionScreen()),
      GoRoute(
          path: Routes.payouts,
          builder: (_, __) => const PayoutHistoryScreen()),
      GoRoute(
          path: Routes.returns,
          builder: (_, state) => ReturnsScreen(
              initialState: state.uri.queryParameters['state'] ?? '')),
      GoRoute(
        path: '/returns/view/:id',
        builder: (_, state) => ReturnDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/returns/view/:id/chat',
        builder: (_, state) => ReturnChatScreen(returnId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: Routes.sellLeads, builder: (_, __) => const SellLeadsScreen()),
      GoRoute(
        path: '/sell-leads/view/:id',
        builder: (_, state) =>
            SellLeadDetailScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/sell-leads/view/:id/chat',
        builder: (_, state) =>
            SellLeadChatScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
          path: Routes.wholesale,
          builder: (_, __) => const MarketplaceScreen()),
      GoRoute(
          path: Routes.wholesaleCart,
          builder: (_, __) => const WholesaleCartScreen()),
      GoRoute(
          path: Routes.wholesaleOrders,
          builder: (_, __) => const WholesaleOrdersScreen()),
      GoRoute(
          path: '/wholesale/view/:id',
          builder: (_, s) =>
              WholesaleDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: Routes.deals, builder: (_, __) => const DealsScreen()),
      GoRoute(
          path: '/deals/view/:id',
          builder: (_, s) => DealDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: Routes.abandonedCarts,
          builder: (_, __) => const AbandonedCartsScreen()),
      GoRoute(
          path: '/abandoned-carts/view/:id',
          builder: (_, s) => CartDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/abandoned-carts/view/:id/remind',
          builder: (_, s) => SendReminderScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: Routes.demand,
          builder: (_, s) => DemandHubScreen(
              initialTab: HubTab.parse(s.uri.queryParameters['tab']))),
      GoRoute(
          path: Routes.demandPost,
          builder: (_, __) => const PostDemandScreen()),
      GoRoute(
          path: '/demand/view/:id',
          builder: (_, s) => RequirementScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/demand/view/:id/offer',
          builder: (_, s) => OfferScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/demand/view/:id/pay',
          builder: (_, s) =>
              PaymentScreen(requirementId: s.pathParameters['id']!)),
      GoRoute(
          path: '/demand/orders/:id',
          builder: (_, s) => OrderTrackingScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/campaigns/view/:id',
          builder: (_, s) => CampaignDetailScreen(id: s.pathParameters['id']!)),
    ],
  );
});
