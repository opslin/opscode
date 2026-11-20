// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_loading_screen.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/addresses/domain/entities/address_entity.dart';
import 'package:dealker_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:dealker_app/features/addresses/presentation/screens/add_edit_address_screen.dart';
import 'package:dealker_app/features/auctions/data/auction_view.dart' show inr;
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_state.dart';
import 'package:dealker_app/features/business_account/presentation/providers/business_account_provider.dart';
import 'package:dealker_app/features/business_account/presentation/providers/price_mode_provider.dart';
import 'package:dealker_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:dealker_app/features/cart/domain/entities/cart_entity.dart';
import 'package:dealker_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:dealker_app/features/cart/domain/entities/savings_breakdown_entity.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_points_provider.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_bar_and_states.dart';
import 'package:dealker_app/features/cart/presentation/widgets/web_cart_columns.dart';
import 'package:dealker_app/features/cart/presentation/widgets/web_purchase_bar.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_bill_card.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_item_tile.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_offer_cards.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_sections.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';
import 'package:dealker_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_coupon_sheet.dart';
import 'package:dealker_app/features/location/presentation/providers/non_serviceable_location_provider.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:dealker_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:dealker_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:dealker_app/features/wishlist/presentation/providers/wishlist_ids_provider.dart';
import 'package:dealker_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:dealker_app/routing/route_names.dart';

/// My Cart: items grouped by seller, coupons, Dealkr Points, Wallet, the bill and one "Place order" action.
/// Every number is the server's (cart, bill summary, points preview, wallet); points and wallet are only taken
/// off the server's total, in the same order the order API applies them.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _billKey = GlobalKey();
  final GlobalKey _firstProblemKey = GlobalKey();
  final Set<String> _busy = <String>{};
  // True from the moment an order/payment is tapped until it hands off, so
  // the branded loader is on screen for the whole wait (not just the API call).
  bool _processing = false;
  PaymentMethod _processingMethod = PaymentMethod.cod;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentOffersProvider);
      // A line can go out of stock (another customer buying the last unit) while this cart sits there.
      ref.read(cartProvider.notifier).refresh();
      // A balance change made outside this app (refund, cashback, admin credit) never invalidates the wallet on its own.
      unawaited(ref.read(walletProvider.notifier).refreshWallet());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final BuildContext? c = key.currentContext;
    if (c != null) {
      Scrollable.ensureVisible(c,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: .1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool signedIn = ref.watch(authStateProvider) is AuthAuthenticated;
    final AsyncValue<CartEntity> cartAsync = ref.watch(cartProvider);
    final CartEntity cart = cartAsync.asData?.value ?? CartEntity.empty();
    final AddressEntity? address = ref.watch(cartSelectedAddressProvider);
    final bool hasAddress = address != null;
    final bool notServiceable =
        !hasAddress && ref.watch(nonServiceableLocationProvider);
    final bool hasCompleteAddress =
        hasAddress && (address.addressLine2 ?? '').trim().isNotEmpty;

    final AsyncValue<BillSummaryEntity> billAsync =
        ref.watch(billSummaryProvider);
    final BillSummaryEntity? known = billAsync.value;
    final BillSummaryEntity summary =
        known ?? _displayBillSummary(cart: cart, remoteSummary: null);
    // The backend total is the only real number; until the first one arrives the bar shows a placeholder, never a guess.
    final double serverPayable = known?.payable ?? summary.payable;

    final double couponOff = ref.watch(
        checkoutProvider.select((s) => s.appliedCoupon?.discountAmount ?? 0));
    final CartPointsInfo? pointsInfo =
        ref.watch(cartPointsInfoProvider(couponOff)).asData?.value;
    final PointsSelection pointsSel = ref.watch(cartPointsSelectionProvider);
    final int pointsUsed = ref.watch(cartPointsAppliedProvider(couponOff));
    final double pointsOff = pointsUsed * (pointsInfo?.pointValue ?? 1);
    final double afterPoints =
        (serverPayable - pointsOff).clamp(0.0, double.infinity);

    final double walletBalance = ref.watch(walletProvider).value?.balance ?? 0;
    final bool b2bCredit = (known?.paymentMethods.ledger.enabled ?? false) &&
        (ref.watch(myBusinessAccountProvider).asData?.value?.isApproved ??
            false) &&
        (ref.watch(myBusinessAccountProvider).asData?.value?.b2bEnabled ??
            false);
    final bool walletEnabled = (known?.paymentMethods.wallet.enabled ??
            summary.paymentMethods.wallet.enabled) &&
        !b2bCredit;
    final bool useWallet =
        ref.watch(checkoutProvider.select((s) => s.useWallet));
    final double walletUsed = (useWallet && walletEnabled && walletBalance > 0)
        ? (walletBalance < afterPoints ? walletBalance : afterPoints)
        : 0;
    final double toPay = (afterPoints - walletUsed).clamp(0.0, double.infinity);
    final bool placing =
        ref.watch(checkoutProvider.select((s) => s.isPlacingOrder));
    final bool blocking = cart.items.any((i) => CartLineView(i).blocking);

    final Widget body = !signedIn
        ? CartGuestView(onLogin: _login)
        : cartAsync.when(
            skipLoadingOnReload: true,
            loading: () => const CartSkeleton(),
            // A failed refresh keeps showing a cart that has items; an empty one has nothing worth keeping, so it shows the error.
            error: (Object e, _) => (cartAsync.hasValue &&
                    !(cartAsync.value?.isEmpty ?? true))
                ? _content(
                    cart,
                    summary,
                    hasAddress,
                    address,
                    toPay,
                    pointsInfo,
                    pointsSel,
                    pointsUsed,
                    pointsOff,
                    walletBalance,
                    walletEnabled,
                    useWallet,
                    walletUsed,
                    afterPoints,
                    blocking)
                : CartProblemView(
                    offline: e is CartOfflineError,
                    onRetry: () => ref.read(cartProvider.notifier).refresh()),
            data: (CartEntity c) => c.isEmpty
                ? _empty()
                : _content(
                    c,
                    summary,
                    hasAddress,
                    address,
                    toPay,
                    pointsInfo,
                    pointsSel,
                    pointsUsed,
                    pointsOff,
                    walletBalance,
                    walletEnabled,
                    useWallet,
                    walletUsed,
                    afterPoints,
                    blocking),
          );

    final bool showBar = signedIn && !cart.isEmpty && cartAsync.hasValue;
    final PaymentMethod placingMethod = _processing
        ? _processingMethod
        : ref.watch(checkoutProvider.select((s) => s.paymentMethod));
    final Widget scaffold = Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(signedIn ? cart.itemCount : 0,
          showHeart: signedIn && !cart.isEmpty),
      body: body,
      bottomNavigationBar: showBar
          ? WebPurchaseBar(
              child: _bar(
              toPay: toPay,
              known: known != null,
              placing: placing,
              hasAddress: hasAddress,
              hasCompleteAddress: hasCompleteAddress,
              notServiceable: notServiceable,
              blocking: blocking,
              b2bCredit: b2bCredit,
              address: address,
              codEnabled: known?.paymentMethods.cod.enabled ?? true,
              onlineEnabled: known?.paymentMethods.razorpay.enabled ?? true,
            ))
          : null,
    );

    // Creative blocking loader while the order / payment is being placed:
    // online gets the card + coins loader, COD / credit the parcel loader.
    if (!(placing || _processing)) {
      return scaffold;
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(child: scaffold),
        Positioned.fill(
          child: DealkerProcessingOverlay(
            kind: placingMethod == PaymentMethod.online
                ? DealkerLoadingKind.payment
                : DealkerLoadingKind.order,
          ),
        ),
      ],
    );
  }

  // ── app bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _appBar(int count, {required bool showHeart}) => AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon:
              Icon(PhosphorIconsRegular.arrowLeft, color: AU.ink, size: 24.sp),
          // A notification deep link lands here with `.go()`, which can leave Cart as the only route: fall back to Home.
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go(RouteNames.home),
        ),
        title: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('My Cart', style: jakarta(20.sp)),
              if (count > 0) ...<Widget>[
                SizedBox(width: 8.w),
                Text('$count item${count == 1 ? '' : 's'}',
                    style: dm(13.5.sp, color: AU.muted))
              ],
            ]),
        actions: <Widget>[
          if (showHeart)
            IconButton(
                icon: Icon(PhosphorIconsRegular.heart,
                    color: AU.ink, size: 26.sp),
                onPressed: () => context.push(RouteNames.wishlist)),
          SizedBox(width: 4.w),
        ],
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AU.border)),
      );

  // ── body ─────────────────────────────────────────────────────────────────

  Widget _empty() {
    final List<ProductEntity> saved = ref
            .watch(wishlistProvider)
            .asData
            ?.value
            .items
            .map((e) => e.product)
            .take(10)
            .toList() ??
        const <ProductEntity>[];
    return CartEmptyView(
      onShop: () => context.go(RouteNames.home),
      wishlist: saved,
      onOpenProduct: (ProductEntity p) => context.push('/product/${p.id}'),
      onAdd: _addSuggestion,
      onSeeAllWishlist: () => context.push(RouteNames.wishlist),
    );
  }

  Widget _content(
    CartEntity cart,
    BillSummaryEntity summary,
    bool hasAddress,
    AddressEntity? address,
    double toPay,
    CartPointsInfo? pointsInfo,
    PointsSelection pointsSel,
    int pointsUsed,
    double pointsOff,
    double walletBalance,
    bool walletEnabled,
    bool useWallet,
    double walletUsed,
    double afterPoints,
    bool blocking,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(purchaseLimitsNotifierProvider.notifier)
          .ensureLoaded(cart.items.map((i) => i.productId).toList());
    });
    final CheckoutState checkout = ref.watch(checkoutProvider);
    final coupon = checkout.appliedCoupon;
    final Set<String> wishlistIds = ref.watch(wishlistIdsProvider);

    // Group the lines by seller, keeping the order the server gave.
    final Map<String, List<CartItemEntity>> groups =
        <String, List<CartItemEntity>>{};
    for (final CartItemEntity i in cart.items) {
      groups
          .putIfAbsent(i.shopId ?? i.shopName ?? '', () => <CartItemEntity>[])
          .add(i);
    }
    final bool single = groups.length == 1;
    final int problems =
        cart.items.where((i) => CartLineView(i).blocking).length;
    bool markedFirst = false;

    final num couponSaves = coupon?.discountAmount ?? 0;
    final double saved =
        summary.savings.total + (coupon != null ? couponSaves : 0) + pointsOff;
    final FreeDeliveryInfo free = summary.freeDelivery;

    final List<Widget> children = <Widget>[
      if (hasAddress && address != null)
        CartDeliveryStrip(
            who:
                '${address.name.isEmpty ? address.label : address.name}, ${address.city} ${address.pincode}',
            onChange: () => _openAddressList(context))
      else
        CartDeliveryStrip(
            who: 'a delivery address', onChange: _ensureAddressAndProceedVoid),
      if (saved > 0) CartSavingsBanner(amount: saved),
      if (problems > 0)
        CartChangedBanner(
            count: problems, onTap: () => _scrollTo(_firstProblemKey)),
    ];

    for (final MapEntry<String, List<CartItemEntity>> g in groups.entries) {
      final String seller = g.value.first.shopName ?? 'Seller';
      children.add(CartSellerHeader(
        name: seller,
        items:
            g.value.fold<int>(0, (int a, CartItemEntity i) => a + i.quantity),
        deliveryText: single
            ? (summary.deliveryFee.isFree
                ? 'Delivery'
                : (summary.deliveryFee.amount > 0
                    ? 'Delivery ${inr(summary.deliveryFee.amount)}'
                    : null))
            : null,
        deliveryFree: single && summary.deliveryFee.isFree,
      ));
      for (final CartItemEntity item in g.value) {
        final CartLineView line = CartLineView(item);
        final bool first = line.blocking && !markedFirst;
        if (first) markedFirst = true;
        final limit = ref.watch(purchaseLimitStatusProvider(item.productId));
        children.add(KeyedSubtree(
          key: first
              ? _firstProblemKey
              : ValueKey<String>('${item.productId}:${item.shopProductId}'),
          child: Column(children: <Widget>[
            CartItemTile(
              line: line,
              saved: wishlistIds.contains(item.productId),
              busy: _busy.contains(item.productId),
              atLimit: (limit?.isAtLimit ?? false) || !item.hasEnoughStock,
              onOpen: () => context.push('/product/${item.productId}'),
              onIncrease: () => _increase(item),
              onDecrease: () => _decrease(item),
              onRemove: () => _removeItem(context, item),
              onSave: () =>
                  _saveForLater(item, wishlistIds.contains(item.productId)),
            ),
            if (line.blocking)
              CartBlockedBanner(
                  text: line.outOfStock
                      ? 'This item is out of stock.\nRemove it to continue.'
                      : 'Only ${item.stockQuantity} left.\nReduce the quantity to continue.'),
          ]),
        ));
      }
    }
    if (free.enabled && !free.unlocked && free.amountToUnlock > 0) {
      children.add(CartFreeShippingNudge(
          amount: free.amountToUnlock,
          seller: single ? groups.values.first.first.shopName : null));
    }

    children.add(_suggestions());
    final int summaryStart = children.length;

    // coupons · points · wallet
    children.add(CartCouponCard(
      onTap: () => showCartCouponSheet(context),
      appliedCode: coupon?.code,
      saves: couponSaves,
      freeDelivery: coupon?.freeDelivery ?? false,
      onRemove: () => ref.read(checkoutProvider.notifier).removeCoupon(),
    ));
    if (pointsInfo != null) {
      children.add(CartPointsCard(
        info: pointsInfo,
        selection: pointsSel,
        onTurnOn: () => ref.read(cartPointsSelectionProvider.notifier).turnOn(
            (pointsInfo.maxPoints / 2).round().clamp(
                pointsInfo.minRedeemable.clamp(0, pointsInfo.maxPoints),
                pointsInfo.maxPoints)),
        onTurnOff: () =>
            ref.read(cartPointsSelectionProvider.notifier).turnOff(),
        onPoints: (int v) =>
            ref.read(cartPointsSelectionProvider.notifier).setPoints(v),
      ));
    }
    if (walletEnabled) {
      children.add(CartWalletCard(
        balance: walletBalance,
        on: useWallet && walletBalance > 0,
        onChanged: (bool v) =>
            ref.read(checkoutProvider.notifier).setUseWallet(v),
        applied: walletUsed,
        remaining: toPay,
        onAddMoney: () => _goToTopup(context,
            suggestedAmount: afterPoints - walletBalance > 0
                ? afterPoints - walletBalance
                : null),
      ));
    }

    children.add(KeyedSubtree(
      key: _billKey,
      child: CartBillCard(
        summary: summary,
        itemCount: cart.itemCount,
        toPay: toPay,
        pointsOff: pointsOff,
        pointsUsed: pointsUsed,
        walletUsed: walletUsed,
        saved: saved,
        couponCode: coupon?.code,
      ),
    ));
    children.add(const CartTrustRow());
    children.add(Padding(
      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 24.h),
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(PhosphorIconsRegular.info, size: 16.sp, color: AU.muted),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'Orders cannot be cancelled after they are packed for delivery. If there is an unexpected delay, any applicable refund will be processed.',
            style: dm(12.sp, h: 1.4),
          ),
        ),
      ]),
    ));

    return RefreshIndicator(
      color: AU.indigo,
      onRefresh: () async {
        ref.read(cartProvider.notifier).refresh();
        ref.invalidate(billSummaryProvider);
        await ref.read(cartProvider.future);
      },
      child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 16.h),
          children: kIsWeb && MediaQuery.sizeOf(context).width >= 900
              ? <Widget>[
                  WebCartColumns(
                    items: children.take(summaryStart).toList(),
                    summary: children.skip(summaryStart).toList(),
                  )
                ]
              : children),
    );
  }

  Widget _suggestions() {
    final List<ProductEntity> list =
        ref.watch(cartQuickAddProductsProvider).asData?.value ??
            const <ProductEntity>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CartSectionTitle('You may also like',
              onSeeAll:
                  list.length > 3 ? () => _seeAllSuggestions(list) : null),
          SizedBox(
            height: 214.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: list.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (_, int i) => CartMiniProduct(
                  product: list[i],
                  onTap: () => context.push('/product/${list[i].id}'),
                  onAdd: () => _addSuggestion(list[i])),
            ),
          ),
          SizedBox(height: 6.h),
        ]);
  }

  void _seeAllSuggestions(List<ProductEntity> list) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r))),
      builder: (BuildContext c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        builder: (_, ScrollController sc) => ListView(
            controller: sc,
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
            children: <Widget>[
              Text('You may also like', style: jakarta(19.sp)),
              SizedBox(height: 12.h),
              Wrap(spacing: 12.w, runSpacing: 12.h, children: <Widget>[
                for (final ProductEntity p in list)
                  CartMiniProduct(
                      width: (MediaQuery.sizeOf(c).width - 32.w - 12.w) / 2,
                      product: p,
                      onTap: () {
                        Navigator.pop(c);
                        context.push('/product/${p.id}');
                      },
                      onAdd: () => _addSuggestion(p)),
              ]),
            ]),
      ),
    );
  }

  // ── bar ──────────────────────────────────────────────────────────────────

  Widget _bar({
    required double toPay,
    required bool known,
    required bool placing,
    required bool hasAddress,
    required bool hasCompleteAddress,
    required bool notServiceable,
    required bool blocking,
    required bool b2bCredit,
    required AddressEntity? address,
    required bool codEnabled,
    required bool onlineEnabled,
  }) {
    String label = b2bCredit ? 'Place order request' : 'Place order';
    VoidCallback? action = () => _placeOrderTapped(
        toPay: toPay,
        b2bCredit: b2bCredit,
        codEnabled: codEnabled,
        onlineEnabled: onlineEnabled);
    String? note;
    if (blocking) {
      action = null;
      note = 'Remove or fix the item above to place your order.';
    } else if (!hasAddress) {
      if (notServiceable) {
        action = null;
        note = "Your area isn't serviceable yet. We'll be there soon!";
      } else {
        label = 'Add address to continue';
        action = _ensureAddressAndProceedVoid;
      }
    } else if (!hasCompleteAddress) {
      label = 'Complete address';
      action = () => _completeAddress(context, address!);
    } else if (!known) {
      action = null;
    }
    return CartPlaceBar(
      total: toPay,
      loadingTotal: !known,
      label: label,
      onPressed: action,
      onViewBill: () => _scrollTo(_billKey),
      busy: placing,
      note: note,
    );
  }

  /// "Place order": a B2B credit order goes straight through; an order already covered by points + wallet needs no
  /// payment choice; otherwise the customer picks how to pay.
  Future<void> _placeOrderTapped(
      {required double toPay,
      required bool b2bCredit,
      required bool codEnabled,
      required bool onlineEnabled}) async {
    if (b2bCredit) return _handlePlaceOrderOnCredit(context);
    if (toPay <= 0) return _placeCovered(codEnabled: codEnabled);
    if (onlineEnabled && !codEnabled) return _handlePayOnline(context);
    if (codEnabled && !onlineEnabled) return _handleCod(context);
    final String? pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r))),
      builder: (BuildContext c) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 12.h),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('How would you like to pay?', style: jakarta(19.sp)),
                SizedBox(height: 4.h),
                Text('To pay ${inr(toPay)}', style: dm(14.sp)),
                SizedBox(height: 14.h),
                _payTile(c, 'online', PhosphorIconsRegular.creditCard,
                    'Pay online', 'UPI, cards, net banking'),
                SizedBox(height: 10.h),
                _payTile(c, 'cod', PhosphorIconsRegular.money,
                    'Cash on delivery', 'Pay when your order arrives'),
              ]),
        ),
      ),
    );
    if (!mounted || pick == null) return;
    if (pick == 'online') return _handlePayOnline(context);
    return _handleCod(context);
  }

  Widget _payTile(BuildContext c, String value, IconData icon, String title,
          String sub) =>
      InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () => Navigator.pop(c, value),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AU.border)),
          child: Row(children: <Widget>[
            CartIconTile(icon: icon, bg: AU.indigoSoft, fg: AU.indigo),
            SizedBox(width: 14.w),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                  Text(title, style: jakarta(15.5.sp)),
                  SizedBox(height: 2.h),
                  Text(sub, style: dm(13.sp))
                ])),
            Icon(PhosphorIconsBold.caretRight, size: 16.sp, color: AU.muted),
          ]),
        ),
      );

  /// Points and/or wallet cover the whole bill: no payment gateway step is left.
  Future<void> _placeCovered({required bool codEnabled}) async {
    if (ref.read(checkoutProvider).isPlacingOrder) return;
    final AddressEntity? address = await _validateForPayment(context);
    if (address == null || !mounted) return;
    ref.read(checkoutProvider.notifier).selectAddress(address);
    await _placeOrder(
        context, codEnabled ? PaymentMethod.cod : PaymentMethod.online);
  }

  // ── cart actions ─────────────────────────────────────────────────────────

  Future<void> _login() async {
    await ref.read(authGateControllerProvider).protectRoute(context,
        route: RouteNames.cart,
        title: 'Log in to see your cart',
        message: 'Please log in to view your cart.');
  }

  void _ensureAddressAndProceedVoid() =>
      unawaited(_ensureAddressAndProceed(context));

  Future<void> _increase(CartItemEntity item) async {
    final status = ref.read(purchaseLimitStatusProvider(item.productId));
    if (status?.isAtLimit ?? false) {
      AppToast.show(context, 'Maximum product order complete');
      return;
    }
    if (!item.hasEnoughStock) {
      AppToast.show(
          context,
          item.stockQuantity <= 0
              ? 'This item is out of stock'
              : 'Only ${item.stockQuantity} left in stock');
      return;
    }
    if (item.hasBulkMaximum && item.quantity >= item.bulkMaxQuantity!) {
      AppToast.show(
          context, 'Maximum bulk order quantity is ${item.bulkMaxQuantity}');
      return;
    }
    await _setQty(item, item.quantity + 1);
  }

  Future<void> _decrease(CartItemEntity item) async {
    // A wholesale line can't step below its bulk minimum: removing it is the only smaller choice, same as a plain line at 1.
    final int floor = item.hasBulkMinimum ? item.bulkMinQuantity! : 1;
    if (item.quantity <= floor) return _removeItem(context, item);
    await _setQty(item, item.quantity - 1);
  }

  Future<void> _setQty(CartItemEntity item, int qty) async {
    setState(() => _busy.add(item.productId));
    try {
      await _updateItemQuantity(context, item.productId, qty,
          shopProductId: item.shopProductId);
    } finally {
      if (mounted) setState(() => _busy.remove(item.productId));
    }
  }

  /// Remove with an Undo that puts the same quantity back.
  Future<void> _removeItem(BuildContext context, CartItemEntity item) async {
    final result = await ref
        .read(cartProvider.notifier)
        .removeItem(item.productId, shopProductId: item.shopProductId);
    if (!context.mounted) return;
    if (!result.isSuccess) {
      showCartSnackBar(context, result.failure!.message);
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Removed ${CartLineView(item).title}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(ref.read(cartProvider.notifier).addItem(
              item.productId, item.quantity,
              shopProductId: item.shopProductId)),
        ),
      ));
  }

  /// "Save for later" keeps the product in the wishlist and takes it out of the cart.
  Future<void> _saveForLater(CartItemEntity item, bool alreadySaved) async {
    if (!alreadySaved) {
      final r = await ref
          .read(wishlistProvider.notifier)
          .addToWishlistById(item.productId);
      if (!mounted) return;
      if (!r.isSuccess) {
        showCartSnackBar(context, r.failure!.message);
        return;
      }
    }
    final result = await ref
        .read(cartProvider.notifier)
        .removeItem(item.productId, shopProductId: item.shopProductId);
    if (!mounted) return;
    if (!result.isSuccess) {
      showCartSnackBar(context, result.failure!.message);
      return;
    }
    AppToast.show(context, 'Saved to your wishlist');
  }

  Future<void> _addSuggestion(ProductEntity product) async {
    if (!product.inStock) {
      showCartSnackBar(context, 'This product is currently unavailable.');
      return;
    }
    // A multi-option product has no inline unit selector here: the picker sheet decides which variant.
    if (product.hasMultipleOptions) {
      showProductOptionsSheet(context, product);
      return;
    }
    final bool wholesale = ref.read(isWholesalePricingActiveProvider);
    final int start =
        wholesale && product.hasBulkMinimum ? product.bulkMinQuantity! : 1;
    final result = await ref.read(cartProvider.notifier).addItem(
        product.id, start,
        product: product, shopProductId: product.shopProductId);
    if (!mounted) return;
    if (!result.isSuccess) showCartSnackBar(context, result.failure!.message);
  }

  Future<bool> _openAddAddress(BuildContext context) async {
    final changed = await context.push<bool>(RouteNames.addAddress);
    if (!context.mounted || changed != true) {
      return false;
    }

    ref.read(addressProvider.notifier).refresh();
    try {
      await ref.read(addressProvider.future);
    } catch (_) {}
    return true;
  }

  /// "Complete Your Address" button — opens the same forced completion
  /// screen home_screen.dart used to push automatically on every app open
  /// (see _maybeShowLocationPrompt there for why that was removed); this is
  /// the checkout-time equivalent, only reached when the customer actually
  /// tries to order with House No./Building still missing.
  Future<void> _completeAddress(
    BuildContext context,
    AddressEntity address,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddEditAddressScreen(
          initialAddress: address,
          forceCompletion: true,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    ref.read(addressProvider.notifier).refresh();
    try {
      await ref.read(addressProvider.future);
    } catch (_) {}
  }

  /// "Add Address to Proceed" button — just adds the address. No further
  /// auto-proceed step needed: once it's saved, `hasAddress` flips true and
  /// the bottom bar re-renders into the Pay Online / Cash-Wallet buttons on
  /// its own for the customer to tap.
  Future<void> _ensureAddressAndProceed(BuildContext context) async {
    await _openAddAddress(context);
  }

  Future<void> _openAddressList(BuildContext context) async {
    await context.push(RouteNames.addresses);
    if (!mounted) {
      return;
    }

    ref.read(addressProvider.notifier).refresh();
  }

  Future<void> _updateItemQuantity(
    BuildContext context,
    String productId,
    int quantity, {
    String? shopProductId,
  }) async {
    final result = await ref.read(cartProvider.notifier).updateItem(
          productId,
          quantity,
          shopProductId: shopProductId,
        );
    if (!result.isSuccess && context.mounted) {
      showCartSnackBar(context, result.failure!.message);
    }
  }

  /// Shared pre-flight for both payment buttons: resolves the selected
  /// address (prompting for one if missing, or completing it if it's still
  /// missing House No./Building — see CartBottomBar's hasCompleteAddress)
  /// and re-validates the cart against the live backend (stock/pricing may
  /// have moved since this screen opened) — the same two checks
  /// `_proceedToCheckout` used to run before handing off to the separate
  /// checkout page. Returns the address to place the order against, or null
  /// if the caller should stop (an error was already surfaced, or the user
  /// backed out of adding/completing one). Defense-in-depth alongside the
  /// bottom bar's own gating — the buttons this guards are only ever
  /// reachable once the bar shows them at all, but this makes the guarantee
  /// hold regardless of how that ever changes.
  Future<AddressEntity?> _validateForPayment(BuildContext context) async {
    var selectedAddress = ref.read(cartSelectedAddressProvider);
    if (selectedAddress == null) {
      final added = await _openAddAddress(context);
      if (!context.mounted || !added) {
        return null;
      }
      selectedAddress = ref.read(cartSelectedAddressProvider);
      if (selectedAddress == null) {
        return null;
      }
    }

    if ((selectedAddress.addressLine2 ?? '').trim().isEmpty) {
      await _completeAddress(context, selectedAddress);
      if (!context.mounted) {
        return null;
      }
      final completedAddress = ref.read(cartSelectedAddressProvider);
      if (completedAddress == null ||
          (completedAddress.addressLine2 ?? '').trim().isEmpty) {
        return null;
      }
      selectedAddress = completedAddress;
    }

    final validation =
        await ref.read(cartProvider.notifier).validateAndProceed();
    if (!context.mounted) {
      return null;
    }
    if (validation.hasFailure) {
      showCartSnackBar(context, validation.failure!.message);
      return null;
    }
    if (!validation.valid) {
      showCartSnackBar(context, validation.warnings.join('\n'));
      return null;
    }

    return selectedAddress;
  }

  /// Places the order for [method] and surfaces any failure. Success needs
  /// no handling here: COD navigates to the order-success screen and
  /// online/wallet hand off to their own payment flow, all already inside
  /// CheckoutNotifier.placeOrder().
  Future<void> _placeOrder(BuildContext context, PaymentMethod method) async {
    final checkoutNotifier = ref.read(checkoutProvider.notifier);
    final double couponOff =
        ref.read(checkoutProvider).appliedCoupon?.discountAmount ?? 0;
    checkoutNotifier
        .setPointsToRedeem(ref.read(cartPointsAppliedProvider(couponOff)));
    checkoutNotifier.selectPaymentMethod(method);

    setState(() {
      _processing = true;
      _processingMethod = method;
    });
    try {
      // Let the loader animation start before the (often very fast) request.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final result = await checkoutNotifier.placeOrder();

      if (!context.mounted) {
        return;
      }
      if (result.errorMessage != null) {
        showCartSnackBar(context, result.errorMessage!);
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _handlePayOnline(BuildContext context) async {
    if (ref.read(checkoutProvider).isPlacingOrder) {
      return;
    }
    final address = await _validateForPayment(context);
    if (address == null || !context.mounted) {
      return;
    }
    ref.read(checkoutProvider.notifier).selectAddress(address);
    await _placeOrder(context, PaymentMethod.online);
  }

  /// "Cash on Delivery" — wallet is no longer a separate exclusive method
  /// here; it's the orthogonal toggle in [CartBottomBar] (see
  /// `useWallet`/`onToggleWallet` wiring in `build()`), which offsets the
  /// total regardless of which button is tapped. This handler just places
  /// the order as COD — whatever the toggle is currently set to travels
  /// with it via `checkoutProvider`'s own state.
  Future<void> _handleCod(BuildContext context) async {
    if (ref.read(checkoutProvider).isPlacingOrder) {
      return;
    }
    final address = await _validateForPayment(context);
    if (address == null || !context.mounted) {
      return;
    }
    ref.read(checkoutProvider.notifier).selectAddress(address);
    await _placeOrder(context, PaymentMethod.cod);
  }

  /// "Place Order" — B2B-exclusive credit method (payment_method
  /// B2B_CREDIT), replacing Cash on Delivery's slot entirely. There is no
  /// credit limit — an approved, b2b_enabled business account can order any
  /// amount. This is a genuine exclusive method, not an offset on top of
  /// COD/Online: it sets the order PENDING admin approval directly.
  /// `setUseWallet(false)` is defensive: the backend never applies a wallet
  /// overlay to a B2B_CREDIT order, but a stale `true` left over from
  /// earlier in this session shouldn't travel with this request.
  Future<void> _handlePlaceOrderOnCredit(BuildContext context) async {
    if (ref.read(checkoutProvider).isPlacingOrder) {
      return;
    }
    final address = await _validateForPayment(context);
    if (address == null || !context.mounted) {
      return;
    }
    ref.read(checkoutProvider.notifier)
      ..selectAddress(address)
      ..setUseWallet(false);
    await _placeOrder(context, PaymentMethod.b2bCredit);
  }

  /// Opens wallet top-up from the cart's "Add Money" button — pre-filled
  /// with the shortfall so the customer doesn't have to work out how much
  /// more they need — and refreshes the balance on return. The customer may
  /// have topped up even if they didn't pop with `true`, so always refresh
  /// rather than trusting the pop result.
  Future<void> _goToTopup(
    BuildContext context, {
    double? suggestedAmount,
  }) async {
    await context.push<bool>(
      RouteNames.topup,
      extra: suggestedAmount,
    );
    if (!context.mounted) {
      return;
    }
    ref.invalidate(walletProvider);
  }

  BillSummaryEntity _displayBillSummary({
    required CartEntity cart,
    required BillSummaryEntity? remoteSummary,
  }) {
    // The backend TotalsEngine is the single source of truth — when its
    // summary is available we render it verbatim (dynamic delivery fee,
    // handling/platform fees, distance, free-delivery progress, total).
    if (remoteSummary != null) {
      return remoteSummary;
    }

    // Fallback shown only while the backend summary is still loading: show the
    // item subtotal without fabricating any fees (no hardcoded ₹25/₹5 math).
    final mrpSavings = cart.totalSavings;
    return BillSummaryEntity(
      itemTotal: ItemTotal(
        original: cart.subtotal + mrpSavings,
        discounted: cart.subtotal,
      ),
      deliveryFee: const DeliveryFeeInfo(),
      handlingFee: const FeeInfo(),
      lateNightFee: const LateNightFeeInfo(),
      toPay: BillToPay(
        original: cart.subtotal + mrpSavings,
        finalAmount: cart.subtotal,
      ),
      savings: SavingsBreakdownEntity(
        total: mrpSavings,
        items: <SavingsLineItem>[
          if (mrpSavings > 0)
            SavingsLineItem(
              type: 'mrp_discount',
              label: 'Discount on MRP',
              amount: mrpSavings,
            ),
        ],
      ),
      deliveryEstimate: const DeliveryEstimate(),
      totalPayable: cart.subtotal,
      tipAmount: cart.tipAmount,
      itemCount: cart.itemCount,
    );
  }
}
