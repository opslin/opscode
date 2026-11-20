import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/constants/app_constants.dart';
import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/core/theme/app_text_styles.dart';
import 'package:dealker_app/core/utils/extensions/double_extensions.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/checkout/presentation/providers/coupon_provider.dart';
import 'package:dealker_app/features/checkout/presentation/screens/coupons_screen.dart';
import 'package:dealker_app/features/notifications/presentation/providers/unread_count_provider.dart';
import 'package:dealker_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:dealker_app/features/nav_button/domain/entities/nav_button_entity.dart';
import 'package:dealker_app/features/nav_button/nav_button_icons.dart';
import 'package:dealker_app/features/nav_button/presentation/providers/nav_button_provider.dart';
import 'package:dealker_app/features/nav_button/presentation/screens/nav_button_webview_screen.dart';
import 'package:dealker_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:dealker_app/features/profile/presentation/widgets/b2b_mode_card.dart';
import 'package:dealker_app/features/profile/presentation/widgets/birthday_banner.dart';
import 'package:dealker_app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:dealker_app/features/profile/presentation/widgets/logout_sheet.dart';
import 'package:dealker_app/features/profile/presentation/widgets/about_sheet.dart';
import 'package:dealker_app/features/profile/presentation/widgets/account_widgets.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart'
    show AU, CartArt, dm;
import 'package:dealker_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:dealker_app/features/spin_wheel/presentation/widgets/spin_win_dialog.dart';
import 'package:dealker_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:dealker_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:dealker_app/routing/app_router.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/web_storefront_footer.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final InAppReview _inAppReview = InAppReview.instance;

  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    unawaited(_loadAppVersion());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(profileProvider.notifier).fetchProfile());
      ref.invalidate(userStatsProvider);
      // Wallet balance can change server-side (admin credit, refund,
      // cashback) without this app ever knowing — refetch every time the
      // profile screen (which shows the wallet balance) opens.
      unawaited(ref.read(walletProvider.notifier).refreshWallet());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileProvider, (previous, next) {
      if (!mounted || !next.hasError || next.isLoading) {
        return;
      }
      final previousError = previous?.error;
      if (previousError != next.error) {
        final message = next.error.toString().replaceFirst('Bad state: ', '');
        AppToast.show(context, message);
      }
    });

    final profileAsync = ref.watch(profileProvider);
    final currentUser = ref.watch(currentUserProvider);
    // FIX: Use walletProvider (WalletNotifier, keepAlive) instead of
    // walletBalanceProvider (auto-dispose) so the balance persists across
    // rebuilds and always shows the correct fetched value.
    final walletAsync = ref.watch(walletProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final profileMenuButtons =
        ref.watch(navButtonProfileMenuProvider).asData?.value ??
            const <NavButtonEntity>[];
    final profileData = profileAsync.asData?.value;
    final user = profileData?.user ?? currentUser;
    final birthday = profileData?.birthday;

    if (user == null && profileAsync.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: const DealkerPageLoader(),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Unable to load your profile.',
                style: AppTextStyles.bodyMedium,
              ),
              Gap(10.h),
              FilledButton(
                onPressed: () {
                  unawaited(ref.read(profileProvider.notifier).fetchProfile());
                },
                child: Text('Retry', style: AppTextStyles.buttonMedium),
              ),
            ],
          ),
        ),
      );
    }

    final stats = statsAsync.asData?.value;
    final wishlistTotal = ref.watch(wishlistProvider).asData?.value.total;
    final couponCount =
        ref.watch(availableCouponsProvider).asData?.value.length ?? 0;
    final cartItems = ref.watch(cartCountProvider);
    final unread = ref.watch(unreadCountProvider);
    final walletLabel = _walletLabel(walletAsync);

    return Scaffold(
      backgroundColor: AU.band,
      body: Column(
        children: <Widget>[
          AccountTopBar(
            onSearch: () => context.push(RouteNames.search),
            onNotifications: () =>
                context.push('${RouteNames.profile}/notifications'),
            onCart: () => context.push(RouteNames.cart),
            unreadNotifications: unread,
            cartCount: cartItems,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 28.h),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: kIsWeb && MediaQuery.sizeOf(context).width >= 700
                        ? 920
                        : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ProfileHeader(
                        name: user.name,
                        phone: user.phone,
                        avatarUrl: user.avatarUrl,
                        onEditTap: _openEditProfile,
                      ),
                      Gap(16.h),
                      QuickActionsRow(
                        actions: <QuickActionData>[
                          QuickActionData(
                            art: CartArt.parcels,
                            label: 'My Orders',
                            subtitle: (stats?.totalOrders ?? 0) > 0
                                ? '${stats!.totalOrders} delivered'
                                : null,
                            onTap: () => context.push(RouteNames.orders),
                          ),
                          QuickActionData(
                            art: CartArt.heart,
                            label: 'Wishlist',
                            subtitle: (wishlistTotal ?? 0) > 0
                                ? '$wishlistTotal ${wishlistTotal == 1 ? 'item' : 'items'}'
                                : null,
                            onTap: () => context.push(RouteNames.wishlist),
                          ),
                        ],
                      ),
                      const B2BModeCard(),
                      Gap(10.h),
                      BirthdayBanner(
                        birthday: birthday,
                        onSelectBirthday: _updateBirthday,
                      ),
                      Gap(10.h),
                      AccountSection(
                        title: 'Shopping',
                        children: <Widget>[
                          AccountRow(
                            art: CartArt.cart,
                            title: 'My Cart',
                            subtitle: cartItems > 0
                                ? '$cartItems ${cartItems == 1 ? 'item' : 'items'}'
                                : 'Your cart is empty',
                            badge: cartItems,
                            onTap: () => context.push(RouteNames.cart),
                          ),
                          AccountRow(
                            art: CartArt.gavel,
                            title: 'Auction Bids',
                            subtitle: 'Live auctions, your bids and watchlist',
                            onTap: () => context.push(RouteNames.auctions),
                          ),
                          AccountRow(
                            art: CartArt.sellPhone,
                            title: 'Sell your phone',
                            subtitle: 'Get offers from verified vendors',
                            onTap: () => context.push('/sell'),
                          ),
                          AccountRow(
                            art: CartArt.repair,
                            title: 'Repair a phone',
                            subtitle: 'Find repair shops near you',
                            onTap: () => context.push('/repair'),
                          ),
                        ],
                      ),
                      Gap(20.h),
                      AccountSection(
                        title: 'Money & Rewards',
                        children: <Widget>[
                          AccountRow(
                            art: CartArt.wallet,
                            title: 'Wallet',
                            subtitle: 'Balance: $walletLabel',
                            onTap: () =>
                                context.push('${RouteNames.profile}/wallet'),
                          ),
                          AccountRow(
                            art: CartArt.coupon,
                            title: 'Coupons',
                            subtitle: couponCount > 0
                                ? '$couponCount ${couponCount == 1 ? 'offer' : 'offers'} available'
                                : 'Offers and discount codes',
                            badge: couponCount,
                            onTap: _openCoupons,
                          ),
                          // Dashboard-configured buttons (Business Transaction,
                          // Games, and any others an admin adds) — see
                          // NavButtonDialog's "Profile screen menu list"
                          // placement. Rendered in sort_order so the admin
                          // controls how many there are and what each opens
                          // without an app release.
                          for (final button in profileMenuButtons)
                            AccountRow(
                              icon: navButtonIcons[button.iconKey] ??
                                  PhosphorIcons.linkLight,
                              // A CUSTOM-icon row renders its uploaded image
                              // instead — CachedNetworkImage directly, not
                              // AppImage: AppImage's ScrollAwareImageProvider
                              // defers loading indefinitely outside an active
                              // scroll context.
                              iconWidget: button.iconType ==
                                          NavButtonIconType.custom &&
                                      (button.customIconActiveUrl ?? '')
                                          .isNotEmpty
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: appImageSource(
                                            button.customIconActiveUrl!,
                                            isWeb: kIsWeb),
                                        width: 22.w,
                                        height: 22.w,
                                        memCacheWidth: 100,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            PhosphorIcon(
                                          PhosphorIcons.linkLight,
                                          size: 22.sp,
                                          color: AppColors.textPrimary,
                                        ),
                                        errorWidget: (context, url, error) =>
                                            PhosphorIcon(
                                          PhosphorIcons.linkLight,
                                          size: 22.sp,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    )
                                  : null,
                              title: button.label,
                              onTap: () => _handleProfileMenuButtonTap(
                                context,
                                button,
                              ),
                            ),
                        ],
                      ),
                      Gap(20.h),
                      AccountSection(
                        title: 'Account',
                        children: <Widget>[
                          AccountRow(
                            art: CartArt.pin,
                            title: 'Addresses',
                            subtitle: 'Manage your delivery addresses',
                            onTap: () =>
                                context.push('${RouteNames.profile}/addresses'),
                          ),
                          AccountRow(
                            art: CartArt.bell,
                            title: 'Notification preferences',
                            subtitle: 'Choose the alerts you receive',
                            onTap: () => context.push(
                              '${RouteNames.profile}/notifications/preferences',
                            ),
                          ),
                          AccountRow(
                            art: CartArt.lock,
                            title: 'Privacy',
                            // inAppWebView, not externalApplication: this app is
                            // a verified App Links handler for dealker.in, so an
                            // external-mode launch of a dealker.in URL gets
                            // handed straight back to this same app by the OS
                            // instead of a browser, and go_router has no /privacy
                            // route (it's web-only) — inAppWebView renders the
                            // URL directly, skipping OS link resolution.
                            onTap: () => launchUrl(
                              Uri.parse('${ApiConstants.webBaseUrl}/privacy'),
                              mode: LaunchMode.inAppWebView,
                            ),
                          ),
                          AccountRow(
                            art: CartArt.document,
                            title: 'Terms & Conditions',
                            onTap: () => launchUrl(
                              Uri.parse('${ApiConstants.webBaseUrl}/terms'),
                              mode: LaunchMode.inAppWebView,
                            ),
                          ),
                        ],
                      ),
                      Gap(20.h),
                      AccountSection(
                        title: 'About',
                        children: <Widget>[
                          AccountRow(
                            art: CartArt.share,
                            title: 'Share the app',
                            onTap: () {
                              Share.share(
                                'Shop mobiles and electronics on Dealkr: ${ApiConstants.webBaseUrl}',
                              );
                            },
                          ),
                          AccountRow(
                            art: CartArt.star,
                            title: 'Rate us',
                            onTap: _rateApp,
                          ),
                          AccountRow(
                            art: CartArt.info,
                            title: 'About us',
                            onTap: _showAbout,
                          ),
                        ],
                      ),
                      Gap(20.h),
                      SupportCard(
                        onChat: () => context.push(RouteNames.supportChat),
                        onCall: () => _launchOrToast(
                          Uri.parse('tel:${AppConstants.supportPhoneDialable}'),
                          'Calling is not available on this device.',
                        ),
                        onEmail: () => _launchOrToast(
                          Uri.parse('mailto:${AppConstants.supportEmail}'),
                          'No email app found. Write to ${AppConstants.supportEmail}.',
                        ),
                      ),
                      Gap(16.h),
                      LogoutButton(onTap: () => LogoutSheet.show(context)),
                      Gap(4.h),
                      TextButton(
                        onPressed: _deleteAccount,
                        style: TextButton.styleFrom(
                          minimumSize: Size.fromHeight(44.h),
                        ),
                        child: Text(
                          'Delete account',
                          style: dm(13.sp, color: AU.grey),
                        ),
                      ),
                      _buildFooter(),
                      if (kIsWeb && MediaQuery.sizeOf(context).width >= 700)
                        WebStorefrontFooter(onNavigate: context.go),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens [uri] and tells the customer when the device cannot handle it
  /// (no phone app, no mail app) instead of failing silently.
  Future<void> _launchOrToast(Uri uri, String failMessage) async {
    var ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      AppToast.show(context, failMessage, type: ToastType.warning);
    }
  }

  Future<void> _openCoupons() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CouponsScreen()),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 4.h),
      child: Center(
        child: Text(
          'Dealkr  •  Version $_appVersion',
          style: dm(12.sp, color: AU.grey),
        ),
      ),
    );
  }

  /// Same destination-type handling as app_bottom_nav.dart's 5th nav
  /// button (WEBVIEW pushed full-screen on the ROOT navigator, so this
  /// Scaffold's own bottom nav bar doesn't linger underneath; APP_ROUTE's
  /// 'spin_wheel' sentinel opens the existing dialog directly rather than
  /// as a route) — a PROFILE_MENU button is the same nav_buttons row
  /// shape, just rendered as a menu list entry instead of a 5th tab.
  void _handleProfileMenuButtonTap(
    BuildContext context,
    NavButtonEntity button,
  ) {
    switch (button.destinationType) {
      case NavButtonDestinationType.appRoute:
        if (button.destinationValue == 'spin_wheel') {
          unawaited(showSpinWinDialog(context));
          return;
        }
        context.push(button.destinationValue);
      case NavButtonDestinationType.category:
        context.push('/categories/${button.destinationValue}/products');
      case NavButtonDestinationType.product:
        context.push('/product/${button.destinationValue}');
      case NavButtonDestinationType.webview:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => NavButtonWebviewScreen(
              url: button.destinationValue,
              passIdentity: button.passIdentity,
            ),
          ),
        );
    }
  }

  Future<void> _updateBirthday(DateTime date) async {
    final result = await ref.read(profileProvider.notifier).updateProfile(
          birthday: date,
        );
    if (!mounted || result.isSuccess) {
      return;
    }
    AppToast.show(context, result.failure!.message);
  }

  Future<void> _openEditProfile() async {
    final changed = await context.push<bool>('${RouteNames.profile}/edit');
    if (!mounted || changed != true) {
      return;
    }
    await ref.read(profileProvider.notifier).fetchProfile();
    ref.invalidate(userStatsProvider);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await DeleteAccountDialog.show(context);
    if (!mounted || confirmed != true) {
      return;
    }

    final authenticated = await _authenticateForDelete();
    if (!mounted || !authenticated) {
      return;
    }

    final result = await ref.read(profileProvider.notifier).deleteAccount();
    if (!mounted) {
      return;
    }

    if (!result.isSuccess && result.failure != null) {
      AppToast.show(context, result.failure!.message);
      return;
    }
    context.go(RouteNames.phone);
  }

  Future<bool> _authenticateForDelete() async {
    try {
      final canUseBiometric = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      if (!canUseBiometric || !deviceSupported) {
        return true;
      }
      return await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to delete account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  void _showAbout() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AboutSheet(version: _appVersion),
    );
  }

  Future<void> _rateApp() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        return;
      }
    } catch (_) {
      // Fall through and show feedback.
    }
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      '⚠️ Rating is not available right now.',
      type: ToastType.warning,
    );
  }

  // FIX: Now receives AsyncValue<WalletEntity> from walletProvider instead of
  // AsyncValue<double> from the auto-dispose walletBalanceProvider.
  //
  // Reads `.value` (not `.when`'s `loading:`/`data:` branches) so a reload —
  // e.g. the invalidate this screen's own initState triggers, or one fired
  // after a wallet-funded order — keeps showing the last known balance
  // instead of flashing back to '...' (`.when`'s `loading:` branch fires on
  // every AsyncLoading state regardless of whether it's carrying a previous
  // value forward).
  String _walletLabel(AsyncValue<dynamic> walletAsync) {
    final wallet = walletAsync.value;
    // walletProvider returns WalletEntity with .balance field.
    if (wallet is WalletEntity) {
      return wallet.balance.toInrCurrency;
    }
    // Fallback: if somehow a double slips through.
    if (wallet is double) {
      return wallet.toInrCurrency;
    }
    return walletAsync.hasError ? '--' : '...';
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() => _appVersion = info.version);
  }
}
