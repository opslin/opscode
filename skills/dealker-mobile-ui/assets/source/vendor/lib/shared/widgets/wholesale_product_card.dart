import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/features/wholesale/data/wholesale_models.dart';

/// Colours copied from the customer app's `ProductCardTokens`.
class _Tok {
  static const ink = Color(0xFF101114);
  static const grey = Color(0xFF6C6E78);
  static const greyLight = Color(0xFF8C8E98);
  static const divider = Color(0xFFD7D9E0);
  static const blue = Color(0xFF1B5BF2);
  static const green = Color(0xFF14A241);
  static const pink = Color(0xFFE5224F);
  static const pinkSoft = Color(0xFFFDE3E9);
  static const danger = Color(0xFFD93025);
  static const amber = Color(0xFFD97706);
  static const shadow = Color(0xFF1B2540);
}

String _money(num v) {
  final s = v.round().toString();
  if (s.length <= 3) return '₹$s';
  var rest = s.substring(0, s.length - 3);
  final groups = <String>[s.substring(s.length - 3)];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '₹${groups.join(',')}';
}

/// Row sizes as proportions of the card width (measured from the customer
/// card's 680 px design), so the box matches the customer app's.
class _M {
  _M(this.width) : u = width / 680;
  final double width;
  final double u;
  double px(double v, [double min = 0]) => math.max(v * u, min);

  double get padSide => px(33, 10);
  double get padTop => px(26, 9);
  double get padBottom => px(34, 11);
  double get imageZone => width * 0.86;
  double get nameFs => px(40, 12.5);
  double get nameH => nameFs * 1.22 * 2;
  double get soldFs => px(30, 10.5);
  double get soldH => soldFs * 1.3;
  double get priceFs => px(62, 16);
  double get mrpFs => px(36, 10.5);
  double get pillH => px(54, 18);
  double get priceH => math.max(priceFs, pillH);
  double get metaFs => px(27, 9.5);
  double get gapName => px(16, 7);
  double get gapSold => px(10, 3);
  double get gapPrice => px(14, 6);
  double get gapMeta => px(18, 8);
  double get metaH => metaFs + 6;
  double get btnH => px(108, 32);
  double get btnW => math.min(px(250, 76), width * 0.46);

  double get height =>
      padTop +
      imageZone +
      gapName +
      nameH +
      gapSold +
      soldH +
      gapPrice +
      priceH +
      gapMeta +
      metaH +
      padBottom;
}

/// The marketplace's product box — the customer app's card, showing another
/// vendor's wholesale listing: seller (name · city), price per unit, retail
/// price struck through, discount, MOQ and stock.
class WholesaleProductCard extends StatelessWidget {
  const WholesaleProductCard({
    super.key,
    required this.item,
    required this.width,
    this.qty = 0,
    this.onTap,
    this.onAdd,
    this.onInc,
    this.onDec,
  });

  final WholesaleItem item;
  final double width;

  /// Units in the cart (0 = not added yet → shows "Add").
  final int qty;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onInc;
  final VoidCallback? onDec;

  static double heightFor(double width) => _M(width).height;

  @override
  Widget build(BuildContext context) {
    final m = _M(width);
    final retail = item.retailPrice;
    final off = item.discountPct != null && item.discountPct! > 0
        ? item.discountPct!.round()
        : (retail != null && retail > item.price
            ? (((retail - item.price) / retail) * 100).round()
            : null);
    final showRetail = retail != null && retail > item.price;

    final inStock = item.stock >= item.moq;
    final low = inStock && item.stock <= 10;
    final stockColor = !inStock
        ? _Tok.danger
        : low
            ? _Tok.amber
            : _Tok.green;
    final stockText = !inStock
        ? 'Out of stock'
        : low
            ? 'Only ${item.stock} left'
            : '${item.stock} in stock';
    final seller = item.seller.city == null
        ? item.seller.name
        : '${item.seller.name}, ${item.seller.city}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: m.height,
        padding:
            EdgeInsets.fromLTRB(m.padSide, m.padTop, m.padSide, m.padBottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(m.px(40, 14)),
          boxShadow: [
            BoxShadow(
                color: _Tok.shadow.withValues(alpha: 0.08),
                blurRadius: m.px(46, 12),
                offset: Offset(0, m.px(14, 4))),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: m.imageZone,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          m.px(12), m.px(26), m.px(12), m.btnH * 0.55),
                      child: AnyImage(item.thumbnail,
                          fit: BoxFit.contain, radius: 0),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: m.px(4),
                    child: Container(
                      height: m.px(62, 22),
                      padding: EdgeInsets.symmetric(horizontal: m.px(32, 10)),
                      decoration: BoxDecoration(
                        color: switch (conditionTier(item.condition)) {
                          ConditionTier.brandNew =>
                            item.condition == 'OPEN_BOX' ? const Color(0xFF0E9F9F) : _Tok.green,
                          ConditionTier.refurbished => _Tok.blue,
                          ConditionTier.used => _Tok.amber,
                        },
                        borderRadius: BorderRadius.circular(m.px(31, 11)),
                      ),
                      alignment: Alignment.center,
                      child: Text(conditionBadge(item.condition),
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: m.px(33, 10),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                              height: 1)),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: qty > 0
                        ? _Stepper(
                            qty: qty,
                            width: m.btnW + 8,
                            height: m.btnH,
                            fontSize: m.px(40, 12),
                            canInc: qty < item.stock,
                            onInc: onInc,
                            onDec: onDec)
                        : GestureDetector(
                            onTap: inStock ? onAdd : null,
                            child: Container(
                              width: m.btnW,
                              height: m.btnH,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: inStock
                                    ? _Tok.blue
                                    : const Color(0xFFB9BDC9),
                                borderRadius: BorderRadius.circular(m.btnH / 2),
                              ),
                              child: Text('Add',
                                  style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: m.px(42, 12),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            SizedBox(height: m.gapName),
            SizedBox(
              height: m.nameH,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: m.nameFs,
                        fontWeight: FontWeight.w800,
                        color: _Tok.ink,
                        letterSpacing: -0.2,
                        height: 1.22)),
              ),
            ),
            SizedBox(height: m.gapSold),
            SizedBox(
              height: m.soldH,
              child: Row(
                children: [
                  Text('Sold by: ',
                      style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: m.soldFs,
                          fontWeight: FontWeight.w500,
                          color: _Tok.grey,
                          height: 1.1)),
                  Flexible(
                    child: Text(seller,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: m.soldFs,
                            fontWeight: FontWeight.w700,
                            color: _Tok.blue,
                            height: 1.1)),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: m.soldFs * 1.35, color: _Tok.blue),
                ],
              ),
            ),
            SizedBox(height: m.gapPrice),
            SizedBox(
              height: m.priceH,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(_money(item.price),
                        style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: m.priceFs,
                            fontWeight: FontWeight.w800,
                            color: _Tok.ink,
                            letterSpacing: -0.5,
                            height: 1)),
                    Padding(
                      padding: EdgeInsets.only(left: m.px(12, 3)),
                      child: Text('/ unit',
                          style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: m.mrpFs,
                              fontWeight: FontWeight.w600,
                              color: _Tok.grey,
                              height: 1)),
                    ),
                    if (showRetail) ...[
                      SizedBox(width: m.px(20, 5)),
                      Text(_money(retail),
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: m.mrpFs,
                              fontWeight: FontWeight.w700,
                              color: _Tok.greyLight,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: _Tok.greyLight,
                              decorationThickness: 1.6,
                              height: 1)),
                    ],
                    if (off != null && off > 0) ...[
                      SizedBox(width: m.px(20, 5)),
                      Container(
                        height: m.pillH,
                        padding: EdgeInsets.symmetric(horizontal: m.px(22, 7)),
                        decoration: BoxDecoration(
                            color: _Tok.pinkSoft,
                            borderRadius: BorderRadius.circular(m.pillH / 2)),
                        alignment: Alignment.center,
                        child: Text('$off% OFF',
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: m.px(28, 9.5),
                                fontWeight: FontWeight.w800,
                                color: _Tok.pink,
                                height: 1)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: m.gapMeta),
            SizedBox(
              height: m.metaH,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(
                        width: 28 * m.u,
                        height: 28 * m.u,
                        decoration: BoxDecoration(
                            color: stockColor, shape: BoxShape.circle)),
                    SizedBox(width: 14 * m.u),
                    Text(stockText,
                        style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: m.metaFs,
                            fontWeight: FontWeight.w700,
                            color: stockColor,
                            height: 1)),
                    SizedBox(width: 24 * m.u),
                    Container(
                        width: 2.5 * m.u,
                        height: m.metaFs,
                        color: _Tok.divider),
                    SizedBox(width: 24 * m.u),
                    Text('MOQ ${item.moq}',
                        style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: m.metaFs,
                            fontWeight: FontWeight.w600,
                            color: _Tok.grey,
                            height: 1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// − qty +  : minus at the minimum order removes the item (the caller offers Undo).
class _Stepper extends StatelessWidget {
  const _Stepper(
      {required this.qty,
      required this.width,
      required this.height,
      required this.fontSize,
      required this.canInc,
      this.onInc,
      this.onDec});
  final int qty;
  final double width;
  final double height;
  final double fontSize;
  final bool canInc;
  final VoidCallback? onInc;
  final VoidCallback? onDec;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback? tap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: SizedBox(
            width: height * 0.9,
            height: height,
            child: Icon(icon,
                size: height * 0.5,
                color: tap == null ? const Color(0xFFB9BDC9) : _Tok.blue),
          ),
        );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: _Tok.blue, width: 1.4),
      ),
      child: Row(children: [
        btn(Icons.remove_rounded, onDec),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$qty',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: _Tok.ink)),
          ),
        ),
        btn(Icons.add_rounded, canInc ? onInc : null),
      ]),
    );
  }
}
