import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/features/auctions/data/auction_view.dart' show inr;
import 'package:dealker_app/features/cart/presentation/widgets/cart_sections.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';

/// The sticky bottom bar: total + "View bill" on the left, one big action on the right.
class CartPlaceBar extends StatelessWidget {
  const CartPlaceBar({
    required this.total,
    required this.label,
    required this.onPressed,
    required this.onViewBill,
    this.busy = false,
    this.loadingTotal = false,
    this.note,
    super.key,
  });

  final double total;
  final String label;

  /// Null = disabled (grey).
  final VoidCallback? onPressed;
  final VoidCallback onViewBill;
  final bool busy;
  final bool loadingTotal;

  /// Reason the button is disabled, shown above the bar (e.g. "We don't deliver to your area yet").
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AU.border)),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: Colors.black.withValues(alpha: .06),
                blurRadius: 14,
                offset: const Offset(0, -4))
          ],
        ),
        padding: EdgeInsets.fromLTRB(
            16.w, 10.h, 16.w, 10.h + MediaQuery.paddingOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          if (note != null)
            Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Text(note!,
                    textAlign: TextAlign.center,
                    style: dm(12.5.sp, color: CU.red, w: FontWeight.w600))),
          Row(children: <Widget>[
            InkWell(
              onTap: onViewBill,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    loadingTotal
                        ? Bone(width: 90.w, height: 22.h)
                        : Text(inr(total), style: jakarta(22.sp)),
                    SizedBox(height: 2.h),
                    Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                      Text('View bill',
                          style:
                              dm(13.sp, color: AU.muted, w: FontWeight.w600)),
                      SizedBox(width: 4.w),
                      Icon(PhosphorIconsBold.caretUp,
                          size: 12.sp, color: AU.muted),
                    ]),
                  ]),
            ),
            SizedBox(width: 18.w),
            Expanded(
              child: SizedBox(
                height: 54.h,
                child: FilledButton(
                  onPressed: busy ? null : onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AU.indigo,
                    disabledBackgroundColor: busy ? AU.indigo : CU.disabled,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: busy
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label,
                              style: jakarta(17.sp, color: Colors.white))),
                ),
              ),
            ),
          ]),
        ]),
      );
}

/// Grey skeleton shaped like the cart (3 item rows, a bill block, a thin bar).
class CartSkeleton extends StatelessWidget {
  const CartSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget row() => Container(
          margin: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
          padding: EdgeInsets.all(14.w),
          decoration: cartCard(),
          child: Row(children: <Widget>[
            Bone(width: 84.w, height: 84.w, radius: 14),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Bone(height: 13.h),
                    SizedBox(height: 10.h),
                    Bone(height: 13.h),
                    SizedBox(height: 10.h),
                    Bone(width: 90.w, height: 22.h, radius: 10),
                  ]),
            ),
          ]),
        );
    return ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 6.h),
        children: <Widget>[
          row(),
          row(),
          row(),
          Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
              child: Bone(height: 120.h, radius: 16)),
          Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
              child: Bone(height: 46.h, radius: 14)),
        ]);
  }
}

/// "Your cart is empty" + Start shopping + the customer's wishlist.
class CartEmptyView extends StatelessWidget {
  const CartEmptyView(
      {required this.onShop,
      required this.wishlist,
      required this.onOpenProduct,
      required this.onAdd,
      required this.onSeeAllWishlist,
      super.key});
  final VoidCallback onShop;
  final List<ProductEntity> wishlist;
  final ValueChanged<ProductEntity> onOpenProduct;
  final ValueChanged<ProductEntity> onAdd;
  final VoidCallback onSeeAllWishlist;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: EdgeInsets.only(bottom: 24.h), children: <Widget>[
        SizedBox(height: 40.h),
        Center(child: CartArtImage(CartArt.emptyCart, size: 230.w, float: true)),
        SizedBox(height: 22.h),
        Text('Your cart is empty',
            textAlign: TextAlign.center, style: jakarta(22.sp)),
        SizedBox(height: 8.h),
        Text('Discover great tech & place\nyour next order.',
            textAlign: TextAlign.center,
            style: dm(15.sp, color: AU.muted, h: 1.4)),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
          child: SizedBox(
            height: 54.h,
            child: FilledButton(
              onPressed: onShop,
              style: FilledButton.styleFrom(
                  backgroundColor: AU.indigo,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r))),
              child: Text('Start shopping',
                  style: jakarta(17.sp, color: Colors.white)),
            ),
          ),
        ),
        if (wishlist.isNotEmpty) ...<Widget>[
          Container(
              height: 8.h, margin: EdgeInsets.only(top: 24.h), color: AU.band),
          CartSectionTitle('From your wishlist', onSeeAll: onSeeAllWishlist),
          SizedBox(
            height: 214.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: wishlist.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (_, int i) => CartMiniProduct(
                  product: wishlist[i],
                  onTap: () => onOpenProduct(wishlist[i]),
                  onAdd: () => onAdd(wishlist[i])),
            ),
          ),
        ],
      ]);
}

/// "Couldn't load your cart" / "You're offline" with one button.
class CartProblemView extends StatelessWidget {
  const CartProblemView(
      {required this.offline, required this.onRetry, super.key});
  final bool offline;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => StateView(
        art: offline ? const CloudSlashArt() : const CloudArt(offline: false),
        title: offline ? "You're offline" : "Couldn't load your cart",
        body: offline
            ? 'Check your internet connection\nand try again.'
            : 'Something went wrong.\nPlease try again.',
        button:
            StateButton(label: offline ? 'Try again' : 'Retry', onTap: onRetry),
      );
}

/// A guest has no cart: ask them to log in.
class CartGuestView extends StatelessWidget {
  const CartGuestView({required this.onLogin, super.key});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) => StateView(
        art: const EmptyBoxArt(),
        title: 'Log in to see your cart',
        body: 'Log in to sync your cart\nand get the best experience.',
        button: StateButton(label: 'Login to continue', onTap: onLogin),
      );
}
