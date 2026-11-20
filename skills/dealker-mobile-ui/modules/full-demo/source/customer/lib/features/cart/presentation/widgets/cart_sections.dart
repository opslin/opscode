import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/features/auctions/data/auction_view.dart' show inr;
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';

/// "Deliver to **Rahul, Kolkata 700001**  Change"
class CartDeliveryStrip extends StatelessWidget {
  const CartDeliveryStrip(
      {required this.who, required this.onChange, super.key});
  final String who;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) {
    final int comma = who.indexOf(',');
    final String lead = comma < 0 ? who : who.substring(0, comma);
    final String rest = comma < 0 ? '' : who.substring(comma);
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
          color: CU.stripBg, borderRadius: BorderRadius.circular(14.r)),
      child: Row(children: <Widget>[
        CartArtImage(CartArt.pin, size: 26.sp, float: true),
        SizedBox(width: 10.w),
        Expanded(
          child: Text.rich(
            TextSpan(children: <InlineSpan>[
              TextSpan(text: 'Deliver to ', style: dm(14.sp, color: AU.muted)),
              TextSpan(
                  text: lead,
                  style: dm(14.sp, color: AU.ink, w: FontWeight.w800)),
              TextSpan(
                  text: rest,
                  style: dm(14.sp, color: AU.ink, w: FontWeight.w800)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
            onTap: onChange,
            child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Text('Change',
                    style: dm(13.5.sp, color: AU.indigo, w: FontWeight.w800)))),
      ]),
    );
  }
}

/// Green "You're saving ₹4,200 on this order" banner.
class CartSavingsBanner extends StatelessWidget {
  const CartSavingsBanner({required this.amount, super.key});
  final num amount;
  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 14.w, 12.h),
        decoration: BoxDecoration(
            color: CU.savingsBg, borderRadius: BorderRadius.circular(14.r)),
        child: Row(children: <Widget>[
          CartArtImage(CartArt.piggy, size: 38.w, float: true),
          SizedBox(width: 12.w),
          Expanded(
            child: Text.rich(TextSpan(children: <InlineSpan>[
              TextSpan(
                  text: "You're saving ",
                  style: dm(15.sp, color: CU.green, w: FontWeight.w600)),
              TextSpan(
                  text: inr(amount), style: jakarta(15.sp, color: CU.green)),
              TextSpan(
                  text: ' on this order',
                  style: dm(15.sp, color: CU.green, w: FontWeight.w600)),
            ])),
          ),
        ]),
      );
}

/// Amber "2 items changed. Review before you order."
class CartChangedBanner extends StatelessWidget {
  const CartChangedBanner(
      {required this.count, required this.onTap, super.key});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
          padding: EdgeInsets.fromLTRB(14.w, 12.h, 12.w, 12.h),
          decoration: BoxDecoration(
              color: CU.amberBg, borderRadius: BorderRadius.circular(14.r)),
          child: Row(children: <Widget>[
            CartArtImage(CartArt.bell, size: 26.sp, float: true),
            SizedBox(width: 12.w),
            Expanded(
              child: Text.rich(TextSpan(children: <InlineSpan>[
                TextSpan(
                    text: '$count item${count == 1 ? '' : 's'} changed. ',
                    style: jakarta(13.5.sp, color: CU.amber)),
                TextSpan(
                    text: 'Review before you order.',
                    style: dm(13.5.sp, color: CU.amber, w: FontWeight.w600)),
              ])),
            ),
            Icon(PhosphorIconsBold.caretRight, size: 16.sp, color: CU.amber),
          ]),
        ),
      );
}

/// Red "This item is out of stock. Remove it to continue." (checkout blocked).
class CartBlockedBanner extends StatelessWidget {
  const CartBlockedBanner({required this.text, super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
            color: CU.redBg, borderRadius: BorderRadius.circular(14.r)),
        child: Row(children: <Widget>[
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
                color: CU.red, borderRadius: BorderRadius.circular(10.r)),
            child: Icon(PhosphorIconsBold.exclamationMark,
                color: Colors.white, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
              child:
                  Text(text, style: jakarta(13.5.sp, color: CU.red, h: 1.35))),
        ]),
      );
}

/// "Sold by **TechNest Retail** ✓ … 2 items" and, when known, the delivery line under it.
class CartSellerHeader extends StatelessWidget {
  const CartSellerHeader(
      {required this.name,
      required this.items,
      this.deliveryText,
      this.deliveryFree = false,
      super.key});
  final String name;
  final int items;
  final String? deliveryText;
  final bool deliveryFree;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 6.h),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Expanded(
                  child: Row(children: <Widget>[
                    Text('Sold by ', style: jakarta(17.sp, w: FontWeight.w500)),
                    Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: jakarta(17.sp))),
                    SizedBox(width: 6.w),
                    const VerifiedBadge(),
                  ]),
                ),
                Text('$items item${items == 1 ? '' : 's'}',
                    style: dm(14.sp, color: AU.muted)),
              ]),
              if (deliveryText != null) ...<Widget>[
                SizedBox(height: 8.h),
                Row(children: <Widget>[
                  CartArtImage(CartArt.van, size: 24.sp),
                  SizedBox(width: 8.w),
                  Flexible(
                      child: Text(deliveryText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dm(13.5.sp, color: AU.muted))),
                  if (deliveryFree)
                    Text(' · Free',
                        style:
                            dm(13.5.sp, color: CU.green, w: FontWeight.w800)),
                ]),
              ],
            ]),
      );
}

/// "Add ₹1,010 more from TechNest Retail for free shipping on next order".
class CartFreeShippingNudge extends StatelessWidget {
  const CartFreeShippingNudge({required this.amount, this.seller, super.key});
  final num amount;
  final String? seller;
  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
            color: CU.stripBg, borderRadius: BorderRadius.circular(14.r)),
        child: Row(children: <Widget>[
          CartArtImage(CartArt.van, size: 36.sp, float: true),
          SizedBox(width: 12.w),
          Expanded(
            child: Text.rich(
                TextSpan(children: <InlineSpan>[
                  TextSpan(
                      text: 'Add ',
                      style: dm(14.sp, color: AU.ink, w: FontWeight.w500)),
                  TextSpan(
                      text: inr(amount),
                      style: dm(14.sp, color: AU.ink, w: FontWeight.w800)),
                  TextSpan(
                      text: seller == null
                          ? ' more for free delivery'
                          : ' more from ',
                      style: dm(14.sp, color: AU.ink, w: FontWeight.w500)),
                  if (seller != null)
                    TextSpan(
                        text: seller,
                        style: dm(14.sp, color: AU.ink, w: FontWeight.w800)),
                  if (seller != null)
                    TextSpan(
                        text: '\nfor free shipping on next order',
                        style: dm(14.sp, color: AU.ink, w: FontWeight.w500)),
                ]),
                style: const TextStyle(height: 1.35)),
          ),
        ]),
      );
}

/// Small suggestion card (photo, round "+" button, name, price, MRP, % off).
class CartMiniProduct extends StatelessWidget {
  const CartMiniProduct(
      {required this.product,
      required this.onTap,
      required this.onAdd,
      this.width,
      super.key});
  final ProductEntity product;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final double? width;
  @override
  Widget build(BuildContext context) {
    final String? url = ApiConstants.resolveMediaUrl(product.thumbnailUrl);
    final bool sale = product.isOnSale;
    final int pct = sale && product.price > 0
        ? (((product.price - product.salePrice!) / product.price) * 100).round()
        : 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: width ?? 132.w,
        padding: EdgeInsets.all(10.w),
        decoration: cartCard(),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(children: <Widget>[
                Container(
                  height: 92.h,
                  width: double.infinity,
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                      color: CU.photoBg,
                      borderRadius: BorderRadius.circular(12.r)),
                  child: url == null
                      ? const SizedBox.shrink()
                      : CachedNetworkImage(
                          imageUrl: webImageSource(url),
                          fit: BoxFit.contain,
                          color: CU.photoBg,
                          colorBlendMode: BlendMode.multiply,
                          errorWidget: (_, __, ___) => const SizedBox.shrink()),
                ),
                Positioned(
                  right: 2.w,
                  top: 2.h,
                  child: InkWell(
                    onTap: onAdd,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 30.w,
                      height: 30.w,
                      decoration: const BoxDecoration(
                          color: AU.indigo, shape: BoxShape.circle),
                      child: Icon(PhosphorIconsBold.plus,
                          color: Colors.white, size: 16.sp),
                    ),
                  ),
                ),
              ]),
              SizedBox(height: 8.h),
              SizedBox(
                  height: 13.sp * 1.3 * 2,
                  child: Text(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: dm(12.sp,
                          color: AU.ink, w: FontWeight.w600, h: 1.3))),
              SizedBox(height: 6.h),
              Text(inr(product.effectivePrice), style: jakarta(16.sp)),
              if (sale)
                Wrap(spacing: 6.w, children: <Widget>[
                  Text(inr(product.price),
                      style: dm(11.5.sp)
                          .copyWith(decoration: TextDecoration.lineThrough)),
                  Text('$pct% off',
                      style: dm(11.5.sp, color: CU.green, w: FontWeight.w800)),
                ]),
            ]),
      ),
    );
  }
}

/// "You may also like" / "From your wishlist" row title with an optional "See all →".
class CartSectionTitle extends StatelessWidget {
  const CartSectionTitle(this.title, {this.onSeeAll, super.key});
  final String title;
  final VoidCallback? onSeeAll;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 10.h),
        child: Row(children: <Widget>[
          Expanded(child: Text(title, style: jakarta(19.sp))),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              child: Row(children: <Widget>[
                Text('See all',
                    style: dm(14.sp, color: AU.indigo, w: FontWeight.w800)),
                SizedBox(width: 4.w),
                Icon(PhosphorIconsBold.arrowRight,
                    size: 14.sp, color: AU.indigo),
              ]),
            ),
        ]),
      );
}
