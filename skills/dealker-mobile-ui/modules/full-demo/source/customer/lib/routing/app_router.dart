import 'package:dealker_app/features/auth/presentation/widgets/web_auth_frame.dart';
import 'package:dealker_app/shared/widgets/adaptive_web_route.dart';
import 'package:flutter/material.dart';
import 'package:dealker_app/features/exchange/data/exchange_models.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_policy_screen.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_routes.dart';
import 'package:dealker_app/features/exchange/presentation/exchange_screen.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_booking_screen.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_chat_screen.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_hub_screen.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_new_screen.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_offers_screen.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_status_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:dealker_app/core/constants/storage_keys.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_booking_screens.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_chat_screen.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_pay_screen.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_home_screen.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_my_screen.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_quotes_screen.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_request_screen.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_shop_screen.dart';
import 'package:dealker_app/features/repair/presentation/screens/repair_status_screen.dart';
import 'package:dealker_app/features/auctions/presentation/screens/auction_chat_screen.dart';
import 'package:dealker_app/features/auctions/presentation/screens/auction_detail_screen.dart';
import 'package:dealker_app/features/auctions/presentation/screens/auctions_screen.dart';
import 'package:dealker_app/features/auctions/presentation/screens/auctions_watching_screen.dart';
import 'package:dealker_app/core/storage/hive_service.dart';
import 'package:dealker_app/features/addresses/presentation/screens/add_edit_address_screen.dart';
import 'package:dealker_app/features/addresses/presentation/screens/address_list_screen.dart';
import 'package:dealker_app/features/auth/presentation/screens/otp_verify_screen.dart';
import 'package:dealker_app/features/auth/presentation/screens/phone_entry_screen.dart';
import 'package:dealker_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:dealker_app/features/categories/presentation/screens/categories_screen.dart';
import 'package:dealker_app/features/categories/presentation/screens/category_products_screen.dart';
import 'package:dealker_app/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:dealker_app/features/home/presentation/screens/home_screen.dart';
import 'package:dealker_app/features/location/presentation/screens/location_unavailable_screen.dart';
import 'package:dealker_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:dealker_app/features/notifications/presentation/screens/notification_preferences_screen.dart';
import 'package:dealker_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:dealker_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:dealker_app/features/orders/presentation/screens/order_success_screen.dart';
import 'package:dealker_app/features/products/presentation/screens/product_detail_screen.dart';
import 'package:dealker_app/features/products/presentation/screens/product_qc_screen.dart';
import 'package:dealker_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:dealker_app/features/support/presentation/screens/support_chat_screen.dart';
import 'package:dealker_app/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:dealker_app/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:dealker_app/features/addresses/domain/entities/address_entity.dart';
import 'package:dealker_app/features/auth/domain/entities/user_entity.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:dealker_app/features/business_account/presentation/screens/business_account_screen.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_state.dart';
import 'package:dealker_app/features/search/presentation/screens/search_screen.dart';
import 'package:dealker_app/features/shops/presentation/screens/shop_profile_screen.dart';
import 'package:dealker_app/features/shops/presentation/screens/shops_list_screen.dart';
import 'package:dealker_app/features/splash/splash_screen.dart';
import 'package:dealker_app/features/tracking/presentation/screens/order_tracking_screen.dart';
import 'package:dealker_app/features/wallet/presentation/screens/send_money_screen.dart';
import 'package:dealker_app/features/wallet/presentation/screens/topup_screen.dart';
import 'package:dealker_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:dealker_app/features/wishlist/presentation/screens/wishlist_screen.dart';
import 'package:dealker_app/routing/route_guards.dart';
import 'package:dealker_app/routing/route_access.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/app_bottom_nav.dart';

part 'app_router.g.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _homeBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'homeBranch');
final GlobalKey<NavigatorState> _ordersBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'ordersBranch');
final GlobalKey<NavigatorState> _categoriesBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'categoriesBranch');
final GlobalKey<NavigatorState> _profileBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'profileBranch');

@riverpod
UserEntity? currentUser(Ref ref) {
  final authState = ref.watch(authStateProvider);
  return switch (authState) {
    AuthAuthenticated(:final user) => user,
    _ => null,
  };
}

@riverpod
bool isAuthenticated(Ref ref) {
  return ref.watch(authStateProvider) is AuthAuthenticated;
}

@riverpod
GoRouter appRouter(Ref ref) {
  final authGuard = ref.watch(authGuardProvider.notifier);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: authGuard,
    redirect: (BuildContext context, GoRouterState state) {
      final authenticated = ref.read(isAuthenticatedProvider);
      final pendingIntent = ref.read(pendingAuthIntentProvider);
      final location = state.matchedLocation;
      final onboardingValue = HiveService.settingsBox.get(
        StorageKeys.onboardingShown,
      );
      final onboardingShown = onboardingValue is bool ? onboardingValue : false;
      final isAuthRoute =
          location == RouteNames.phone || location == RouteNames.otp;
      final isSplashRoute = location == RouteNames.splash;
      final isOnboardingRoute = location == RouteNames.onboarding;

      if (onboardingShown && isOnboardingRoute) {
        return RouteNames.home;
      }

      if (!authenticated &&
          !isAuthRoute &&
          !isSplashRoute &&
          !isOnboardingRoute &&
          RouteAccess.isProtectedLocation(location)) {
        ref
            .read(authGateControllerProvider)
            .rememberRouteIntent(state.uri.toString());
        return RouteNames.phone;
      }

      if (authenticated && isAuthRoute && pendingIntent == null) {
        return RouteNames.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.splash,
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: RouteNames.phone,
        builder: (BuildContext context, GoRouterState state) {
          return const WebAuthFrame(child: PhoneEntryScreen());
        },
      ),
      GoRoute(
        path: RouteNames.otp,
        builder: (BuildContext context, GoRouterState state) {
          return WebAuthFrame(
              child: OtpVerifyScreen(
            phone: state.uri.queryParameters['phone'] ?? '',
          ));
        },
      ),
      GoRoute(
        path: RouteNames.shops,
        builder: (BuildContext context, GoRouterState state) {
          return const AdaptiveWebRoute(child: ShopsListScreen());
        },
      ),
      GoRoute(
        path: RouteNames.shopProfile,
        builder: (BuildContext context, GoRouterState state) {
          return AdaptiveWebRoute(
              child: ShopProfileScreen(
                  shopId: state.pathParameters['shopId'] ?? ''));
        },
      ),
      GoRoute(
        path: RouteNames.search,
        builder: (BuildContext context, GoRouterState state) {
          return AdaptiveWebRoute(
              child:
                  SearchScreen(initialQuery: state.uri.queryParameters['q']));
        },
      ),
      // General support chat: root-level so it covers the shell's bottom nav.
      GoRoute(
        path: RouteNames.supportChat,
        builder: (BuildContext context, GoRouterState state) {
          final Map<String, String> q = state.uri.queryParameters;
          return AdaptiveWebRoute(
              child: SupportChatScreen(
            orderNumber: q['order'],
            topic: q['topic'],
          ));
        },
      ),
      GoRoute(
        path: RouteNames.exchange,
        builder: (BuildContext context, GoRouterState state) {
          final Map<String, String> q = state.uri.queryParameters;
          return AdaptiveWebRoute(
              child: ExchangeScreen(
            initialTypeKey: q['type'],
            target: ExchangeTarget(
              productId: q['productId'] ?? '',
              name: q['name'] ?? '',
              price: double.tryParse(q['price'] ?? '') ?? 0,
            ),
          ));
        },
      ),
      // Sell your phone: root-level so it covers the shell's bottom nav.
      GoRoute(
        path: '/sell',
        builder: (BuildContext context, GoRouterState state) =>
            const AdaptiveWebRoute(child: SellHubScreen()),
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            builder: (BuildContext context, GoRouterState state) =>
                const AdaptiveWebRoute(child: SellNewScreen()),
          ),
          GoRoute(
            path: ':id',
            builder: (BuildContext context, GoRouterState state) =>
                AdaptiveWebRoute(
                    child: SellStatusScreen(
                        requestId: state.pathParameters['id'] ?? '')),
            routes: <RouteBase>[
              GoRoute(
                path: 'offers',
                builder: (BuildContext context, GoRouterState state) =>
                    AdaptiveWebRoute(
                        child: SellOffersScreen(
                            requestId: state.pathParameters['id'] ?? '')),
              ),
              GoRoute(
                path: 'chat/:vendorId',
                builder: (BuildContext context, GoRouterState state) =>
                    AdaptiveWebRoute(
                        child: SellChatScreen(
                  requestId: state.pathParameters['id'] ?? '',
                  vendorId: state.pathParameters['vendorId'] ?? '',
                )),
              ),
              GoRoute(
                path: 'book',
                builder: (BuildContext context, GoRouterState state) =>
                    AdaptiveWebRoute(
                        child: SellBookingScreen(
                            requestId: state.pathParameters['id'] ?? '')),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/repair',
        builder: (BuildContext context, GoRouterState state) =>
            const AdaptiveWebRoute(child: RepairHomeScreen()),
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            builder: (BuildContext context, GoRouterState state) =>
                const AdaptiveWebRoute(child: RepairRequestScreen()),
          ),
          GoRoute(
            path: 'mine',
            builder: (BuildContext context, GoRouterState state) =>
                const AdaptiveWebRoute(child: RepairMyScreen()),
          ),
          GoRoute(
            path: ':id',
            builder: (BuildContext context, GoRouterState state) =>
                AdaptiveWebRoute(
                    child: RepairStatusScreen(
                        repairId: state.pathParameters['id'] ?? '')),
            routes: <RouteBase>[
              GoRoute(
                path: 'quotes',
                builder: (BuildContext context, GoRouterState state) =>
                    AdaptiveWebRoute(
                        child: RepairQuotesScreen(
                            repairId: state.pathParameters['id'] ?? '')),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':offerId',
                    builder: (BuildContext context, GoRouterState state) =>
                        AdaptiveWebRoute(
                            child: RepairShopScreen(
                      repairId: state.pathParameters['id'] ?? '',
                      offerId: state.pathParameters['offerId'] ?? '',
                    )),
                  ),
                ],
              ),
              GoRoute(
                path: 'book/:offerId',
                builder: (BuildContext context, GoRouterState state) =>
                    AdaptiveWebRoute(
                        child: RepairAppointmentTypeScreen(
                  repairId: state.pathParameters['id'] ?? '',
                  offerId: state.pathParameters['offerId'] ?? '',
                )),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'store',
                    builder: (BuildContext context, GoRouterState state) =>
                        AdaptiveWebRoute(
                            child: RepairStoreBookingScreen(
                      repairId: state.pathParameters['id'] ?? '',
                      offerId: state.pathParameters['offerId'] ?? '',
                    )),
                  ),
                  GoRoute(
                    path: 'pickup',
                    builder: (BuildContext context, GoRouterState state) =>
                        AdaptiveWebRoute(
                            child: RepairPickupBookingScreen(
                      repairId: state.pathParameters['id'] ?? '',
                      offerId: state.pathParameters['offerId'] ?? '',
                    )),
                  ),
                ],
              ),
              GoRoute(
                path: 'chat',
                builder: (BuildContext context, GoRouterState state) =>
                    AdaptiveWebRoute(
                        child: RepairChatScreen(
                            repairId: state.pathParameters['id'] ?? '')),
              ),
              GoRoute(
                path: 'pay',
                builder: (BuildContext context, GoRouterState state) =>
                    AdaptiveWebRoute(
                        child: RepairPayScreen(
                            repairId: state.pathParameters['id'] ?? '')),
              ),
              GoRoute(
                path: 'confirmed',
                builder: (BuildContext context, GoRouterState state) =>
                    AdaptiveWebRoute(
                        child: RepairConfirmedScreen(
                            repairId: state.pathParameters['id'] ?? '')),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.auctions,
        builder: (BuildContext context, GoRouterState state) {
          return const AdaptiveWebRoute(child: AuctionsScreen());
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'watching',
            builder: (BuildContext context, GoRouterState state) =>
                const AdaptiveWebRoute(child: AuctionsWatchingScreen()),
          ),
          GoRoute(
            path: ':id/chat',
            builder: (BuildContext context, GoRouterState state) =>
                AdaptiveWebRoute(
                    child: AuctionChatScreen(
                        auctionId: state.pathParameters['id'] ?? '',
                        title: state.extra as String?)),
          ),
          GoRoute(
            path: ':id',
            builder: (BuildContext context, GoRouterState state) =>
                AdaptiveWebRoute(
                    child: AuctionDetailScreen(
                        auctionId: state.pathParameters['id'] ?? '')),
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.locationUnavailable,
        builder: (BuildContext context, GoRouterState state) {
          return const LocationUnavailableScreen();
        },
      ),
      GoRoute(
        path: '/product/:productId/qc',
        builder: (BuildContext context, GoRouterState state) {
          return AdaptiveWebRoute(
              child: ProductQcScreen(
            productId: state.pathParameters['productId'] ?? '',
            name: state.extra is String ? state.extra! as String : null,
          ));
        },
      ),
      GoRoute(
        path: '/product/:productId',
        builder: (BuildContext context, GoRouterState state) {
          return AdaptiveWebRoute(
              child: ProductDetailScreen(
            id: state.pathParameters['productId'] ?? '',
          ));
        },
      ),
      // Matches dealker-customer-web's real product URL shape
      // (/products/:slug, plural, slug-based) so App Links opened from a
      // shared product link resolve here. The backend's GET /products/:id
      // already auto-detects UUID vs slug, so ProductDetailScreen needs no
      // changes — it just receives the slug string as `id`.
      GoRoute(
        path: '/products/:slug',
        builder: (BuildContext context, GoRouterState state) {
          return AdaptiveWebRoute(
              child: ProductDetailScreen(
            id: state.pathParameters['slug'] ?? '',
          ));
        },
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (BuildContext context, GoRouterState state) {
          return const _RoutePlaceholderScreen('OnboardingScreen');
        },
      ),
      // Return flow: root-level so it covers the shell's bottom nav and survives router refreshes.
      GoRoute(
        path: '/returns/policy',
        builder: (BuildContext context, GoRouterState state) {
          return AdaptiveWebRoute(
              child: ReturnPolicyScreen(
            orderId: state.uri.queryParameters['orderId'],
          ));
        },
      ),
      GoRoute(
        path: '/returns/:orderId',
        builder: (BuildContext context, GoRouterState state) {
          return AdaptiveWebRoute(
              child: ReturnTrackingRoute(
            orderId: state.pathParameters['orderId'] ?? '',
          ));
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            builder: (BuildContext context, GoRouterState state) {
              return AdaptiveWebRoute(
                  child: ReturnRequestRoute(
                orderId: state.pathParameters['orderId'] ?? '',
              ));
            },
          ),
          GoRoute(
            path: 'chat',
            builder: (BuildContext context, GoRouterState state) {
              return AdaptiveWebRoute(
                  child: ReturnChatRoute(
                orderId: state.pathParameters['orderId'] ?? '',
              ));
            },
          ),
        ],
      ),
      GoRoute(
        path: '/orders/success/:orderId',
        builder: (BuildContext context, GoRouterState state) {
          return AdaptiveWebRoute(
              child: OrderSuccessScreen(
            orderId: state.pathParameters['orderId'] ?? '',
          ));
        },
      ),
      GoRoute(
        path: RouteNames.cart,
        builder: (BuildContext context, GoRouterState state) {
          return const AdaptiveWebRoute(child: CartScreen());
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'checkout',
            builder: (BuildContext context, GoRouterState state) {
              return const AdaptiveWebRoute(child: CheckoutScreen());
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'payment',
                builder: (BuildContext context, GoRouterState state) {
                  return const _RoutePlaceholderScreen('PaymentScreen');
                },
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return AppShell(
            navigationShell: navigationShell,
            branchNavigatorKeys: <GlobalKey<NavigatorState>>[
              _homeBranchNavigatorKey,
              _ordersBranchNavigatorKey,
              _categoriesBranchNavigatorKey,
              _profileBranchNavigatorKey,
            ],
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _homeBranchNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.home,
                builder: (BuildContext context, GoRouterState state) {
                  return const HomeScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _ordersBranchNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.orders,
                builder: (BuildContext context, GoRouterState state) {
                  return const OrdersScreen();
                },
                routes: <RouteBase>[
                  GoRoute(
                    // Covers the bottom nav so the sticky action button sits at the screen bottom.
                    parentNavigatorKey: _rootNavigatorKey,
                    path: ':orderId',
                    builder: (BuildContext context, GoRouterState state) {
                      return AdaptiveWebRoute(
                          child: OrderDetailScreen(
                        id: state.pathParameters['orderId'] ?? '',
                      ));
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'track',
                        builder: (BuildContext context, GoRouterState state) {
                          return AdaptiveWebRoute(
                              child: OrderTrackingScreen(
                            id: state.pathParameters['orderId'] ?? '',
                          ));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _categoriesBranchNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.categories,
                builder: (BuildContext context, GoRouterState state) {
                  return const CategoriesScreen();
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: ':categoryId/products',
                    builder: (BuildContext context, GoRouterState state) {
                      return CategoryProductsScreen(
                        id: state.pathParameters['categoryId'] ?? '',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileBranchNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profile,
                builder: (BuildContext context, GoRouterState state) {
                  return const ProfileScreen();
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'edit',
                    // Also pushed from Cart (cart_ordering_for.dart), outside
                    // the shell — same reasoning as the addresses routes
                    // above: pin to the root navigator so it always renders
                    // as a plain full-screen page instead of risking the
                    // blank-screen shell/branch entanglement.
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) {
                      return const AdaptiveWebRoute(child: EditProfileScreen());
                    },
                  ),
                  GoRoute(
                    path: 'wallet',
                    builder: (BuildContext context, GoRouterState state) {
                      return const WalletScreen();
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'topup',
                        // Now also pushed from Cart and Checkout (the
                        // wallet stripe's "Add Money" button), outside the
                        // shell — same fix as 'edit' and 'addresses' above:
                        // pin to the root navigator so it always renders as
                        // a plain full-screen page instead of go_router
                        // trying to switch the StatefulShellRoute to the
                        // profile branch mid-push, which produced a blank
                        // white screen. Reported: tapping "Add Money" from
                        // checkout/cart redirected to a blank page instead
                        // of the top-up screen.
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (BuildContext context, GoRouterState state) {
                          // Callers with a known shortfall (e.g. the
                          // checkout/cart wallet stripe's "Add Money"
                          // button) pass it as `extra` so the amount field
                          // arrives pre-filled with exactly what's needed
                          // to cover the order, rather than a blank field.
                          final suggested = state.extra;
                          return AdaptiveWebRoute(
                              child: TopupScreen(
                            initialAmount:
                                suggested is double ? suggested : null,
                          ));
                        },
                      ),
                      GoRoute(
                        path: 'send',
                        builder: (BuildContext context, GoRouterState state) {
                          return const SendMoneyScreen();
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'wishlist',
                    builder: (BuildContext context, GoRouterState state) {
                      return const WishlistScreen();
                    },
                  ),
                  GoRoute(
                    path: 'addresses',
                    // Pushed from screens outside the shell too (Cart's
                    // address header, Checkout, the location-unavailable
                    // screen, the location prompt sheet, notification deep
                    // links) as well as from Profile itself — pinning it to
                    // the root navigator makes it always render as a plain
                    // full-screen page instead of go_router trying to switch
                    // the StatefulShellRoute to the profile branch mid-push,
                    // which produced a blank screen with the bottom nav
                    // stuck showing "Profile" over nothing.
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) {
                      return const AdaptiveWebRoute(child: AddressListScreen());
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'add',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (BuildContext context, GoRouterState state) {
                          return AdaptiveWebRoute(
                              child: AddEditAddressScreen(
                            initialAddress: state.extra as AddressEntity?,
                          ));
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (BuildContext context, GoRouterState state) {
                      return const NotificationsScreen();
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'preferences',
                        builder: (BuildContext context, GoRouterState state) {
                          return const NotificationPreferencesScreen();
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'reviews',
                    builder: (BuildContext context, GoRouterState state) {
                      return const ReviewsScreen();
                    },
                  ),
                  GoRoute(
                    path: 'business-account',
                    builder: (BuildContext context, GoRouterState state) {
                      return const BusinessAccountScreen();
                    },
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (BuildContext context, GoRouterState state) {
                      return const _RoutePlaceholderScreen('SettingsScreen');
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _RoutePlaceholderScreen extends StatelessWidget {
  const _RoutePlaceholderScreen(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(label),
      ),
    );
  }
}
