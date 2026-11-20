import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/features/auctions/data/auction_view.dart' show inr;
import 'package:dealker_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart'
    show splitNameAndVariant;

/// How a cart line is described to the customer (derived only from the server's cart line).
class CartLineView {
  CartLineView(this.item) {
    final ({String name, String? variant}) split =
        splitNameAndVariant(item.name);
    final String? option = item.optionLabel?.trim();
    title = (option != null && option.isNotEmpty) ? item.name : split.name;
    final String? raw =
        (option != null && option.isNotEmpty) ? option : split.variant;
    variant = raw?.replaceAll(RegExp(r'\s*[|/,]\s*'), ' · ');
  }

  final CartItemEntity item;
  late final String title;
  late final String? variant;

  double get unit => item.effectivePrice;
  bool get onSale =>
      item.salePrice != null &&
      item.salePrice! > 0 &&
      item.salePrice! < item.price;
  int get percentOff => onSale
      ? (((item.price - item.salePrice!) / item.price) * 100).round()
      : 0;
  bool get outOfStock => !item.isAvailable || item.stockQuantity <= 0;

  /// Only N left — shown when the cart holds more than is in stock, or stock is nearly gone.
  int? get lowStock => outOfStock
      ? null
      : (item.stockQuantity < item.quantity || item.stockQuantity <= 5
          ? item.stockQuantity
          : null);

  /// A line the customer must fix before ordering.
  bool get blocking => outOfStock || item.stockQuantity < item.quantity;
}

/// One product line of the cart (photo, title, variant, stock chip, price, stepper, save/remove).
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    required this.line,
    required this.onOpen,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onSave,
    required this.saved,
    this.busy = false,
    this.atLimit = false,
    super.key,
  });

  final CartLineView line;
  final VoidCallback onOpen;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final VoidCallback onSave;
  final bool saved;
  final bool busy;
  final bool atLimit;

  @override
  Widget build(BuildContext context) {
    final CartItemEntity item = line.item;
    final String? url = ApiConstants.resolveMediaUrl(item.thumbnailUrl);
    final bool out = line.outOfStock;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.all(14.w),
      decoration: cartCard(),
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        InkWell(
          onTap: onOpen,
          child: Opacity(
            opacity: out ? .45 : 1,
            child: Container(
              width: 96.w,
              height: 96.w,
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFF7F9FE), Color(0xFFEAEFFA)],
                ),
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: url == null
                  ? Icon(PhosphorIconsRegular.image,
                      color: AU.chipBorder, size: 32.sp)
                  : CachedNetworkImage(
                      imageUrl: webImageSource(url),
                      fit: BoxFit.contain,
                      // product photos have a white background: multiply blends it into the tile
                      color: CU.photoBg,
                      colorBlendMode: BlendMode.multiply,
                      errorWidget: (_, __, ___) => Icon(
                          PhosphorIconsRegular.image,
                          color: AU.chipBorder,
                          size: 32.sp),
                    ),
            ),
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  onTap: onOpen,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(line.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: jakarta(15.sp, w: FontWeight.w700, h: 1.25)),
                        if (line.variant != null) ...<Widget>[
                          SizedBox(height: 3.h),
                          Text(line.variant!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: dm(13.sp)),
                        ],
                        if (out) ...<Widget>[
                          SizedBox(height: 8.h),
                          _chip('Out of stock')
                        ] else if (line.lowStock != null) ...<Widget>[
                          SizedBox(height: 8.h),
                          _chip('Only ${line.lowStock} left')
                        ],
                        if (!out) ...<Widget>[
                          SizedBox(height: 8.h),
                          Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8.w,
                              children: <Widget>[
                                Text(inr(line.unit), style: jakarta(20.sp)),
                                if (line.onSale)
                                  Text(inr(item.price),
                                      style: dm(13.sp).copyWith(
                                          decoration:
                                              TextDecoration.lineThrough)),
                                if (line.onSale)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 7.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: CU.savingsBg,
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text('${line.percentOff}% OFF',
                                        style: dm(11.5.sp,
                                            color: CU.green,
                                            w: FontWeight.w800)),
                                  ),
                              ]),
                        ],
                      ]),
                ),
                if (!out) ...<Widget>[
                  SizedBox(height: 12.h),
                  Row(children: <Widget>[
                    _stepper(),
                    SizedBox(width: 8.w),
                    if (item.quantity > 1)
                      Expanded(
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(inr(item.total),
                                      style: jakarta(15.sp))))),
                  ]),
                ],
                SizedBox(height: 10.h),
                Row(children: <Widget>[
                  Flexible(
                      flex: 3,
                      child: _link(
                          CartArtImage(CartArt.heart, size: 20.sp),
                          out ? 'Move to wishlist' : 'Save for later',
                          onSave,
                          dim: !saved,
                          color: saved ? AU.indigo : AU.muted)),
                  Container(
                      width: 1,
                      height: 18.h,
                      margin: EdgeInsets.symmetric(horizontal: 8.w),
                      color: AU.border),
                  Flexible(
                      flex: 2,
                      child: _link(CartArtImage(CartArt.trash, size: 20.sp),
                          'Remove', onRemove,
                          dim: true)),
                ]),
              ]),
        ),
      ]),
    );
  }

  Widget _chip(String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
            color: CU.chipRedBg, borderRadius: BorderRadius.circular(8.r)),
        child: Text(text, style: jakarta(12.5.sp, color: CU.red)),
      );

  Widget _link(Widget icon, String label, VoidCallback onTap,
          {Color color = AU.muted, bool dim = false}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Opacity(opacity: dim ? .75 : 1, child: icon),
            SizedBox(width: 5.w),
            Flexible(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label,
                        maxLines: 1,
                        style: dm(12.5.sp, color: color, w: FontWeight.w600)))),
          ]),
        ),
      );

  Widget _stepper() {
    Widget btn(IconData icon, Color fg, Color bg, VoidCallback? onTap) =>
        GestureDetector(
          onTap: busy ? null : onTap,
          child: Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 18.sp, color: fg),
          ),
        );
    return Container(
      height: 46.h,
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: BoxDecoration(
        color: AU.indigoSoft,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        btn(PhosphorIconsBold.minus, AU.ink, Colors.white, onDecrease),
        SizedBox(
          width: 38.w,
          child: busy
              ? Center(
                  child: SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: AU.indigo)))
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim, child: FadeTransition(opacity: anim, child: child)),
                  child: Text('${line.item.quantity}',
                      key: ValueKey<int>(line.item.quantity),
                      textAlign: TextAlign.center,
                      style: jakarta(17.sp)),
                ),
        ),
        btn(PhosphorIconsBold.plus, Colors.white,
            atLimit ? AU.chipBorder : AU.indigo, onIncrease),
      ]),
    );
  }
}
