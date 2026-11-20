import 'dart:math' as math;

import 'package:dealker_app/features/shops/presentation/providers/shop_distance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/core/theme/product_card_tokens.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:dealker_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Splits a catalogue name like `Apple iPhone 15 (128GB, Blue)` into the display
/// name `Apple iPhone 15` and the variant `128GB | Blue`.
///
/// Only a trailing parenthetical that looks like a variant (short, at most
/// three comma / slash / pipe separated parts) is taken. Anything else is left
/// in the name untouched. Used when the product has no option label or
/// attributes of its own.
({String name, String? variant}) splitNameAndVariant(String full) {
  final RegExpMatch? m =
      RegExp(r'^(.*?)\s*\(([^()]{1,40})\)\s*$').firstMatch(full.trim());
  if (m == null) return (name: full.trim(), variant: null);
  final String base = m.group(1)!.trim();
  final List<String> parts = m
      .group(2)!
      .split(RegExp(r'[,/|]'))
      .map((String x) => x.trim())
      .where((String x) => x.isNotEmpty)
      .toList();
  if (base.isEmpty ||
      parts.isEmpty ||
      parts.length > 3 ||
      parts.any((String x) => x.length > 24)) {
    return (name: full.trim(), variant: null);
  }
  return (name: base, variant: parts.join(' | '));
}

/// Row sizes of the card, all proportions of the card width measured from the
/// design (680 px wide there) with readable minimums, so the card looks the same at
/// any width and its height can be computed without laying it out.
class _CardMetrics {
  _CardMetrics(
    this.width, {
    this.nameLines = 2,
    this.showSold = true,
    this.showRating = true,
  }) : u = width / 680;

  final double width;

  /// How many lines the name block reserves (1 or 2).
  final int nameLines;

  /// Whether the "Sold by" and rating rows take space. Rows nobody in a list has
  /// data for can be dropped so the card has no empty gaps.
  final bool showSold;
  final bool showRating;

  /// One design pixel.
  final double u;

  double px(double v, [double min = 0]) => math.max(v * u, min);

  double get padSide => px(33, 10);
  double get padTop => px(26, 9);
  double get padBottom => px(34, 11);

  double get imageZone => width * 0.86;

  double get nameFs => px(40, 12.5);
  double get nameH => nameFs * 1.22 * nameLines;
  double get soldFs => px(30, 10.5);
  double get soldH => soldFs * 1.3;
  double get priceFs => px(62, 16);
  double get mrpFs => px(36, 10.5);
  double get pillH => px(54, 18);
  double get priceH => math.max(priceFs, pillH);
  double get starFs => px(46, 13);
  double get ratingFs => px(34, 11.5);
  double get metaFs => px(27, 9.5);
  double get metaIcon => px(44, 12);
  double get metaH => metaIcon + 2;

  double get gapName => px(16, 7);
  double get gapSold => px(10, 3);
  double get gapPrice => px(14, 6);
  double get gapRating => px(12, 4);
  double get gapMeta => px(18, 8);

  // Add button: bigger than the design on purpose, so it is easy to see and tap.
  double get btnH => px(108, 38);
  double get btnW => math.min(px(250, 90), width * 0.56);
  double get plusW => btnH * 1.15;
  double get stepW => px(270, 104);
  double get btnFs => px(42, 14);
  double get plusIcon => math.max(btnH * 0.62, 22);

  double get textBlock =>
      gapName +
      nameH +
      (showSold ? gapSold + soldH : 0) +
      gapPrice +
      priceH +
      (showRating ? gapRating + starFs : 0) +
      gapMeta +
      metaH;

  double get height => padTop + imageZone + textBlock + padBottom;
}

/// Which optional rows a list of cards needs. Rows no product in the list has data
/// for (rating, seller) are dropped, and the name block is one line when every
/// name fits on one, so cards carry no empty gaps and all share one height.
class DealkerCardSlots {
  const DealkerCardSlots({
    this.nameLines = 2,
    this.showSold = true,
    this.showRating = true,
  });

  factory DealkerCardSlots.forProducts(
    Iterable<ProductEntity> products,
    double width,
  ) {
    final List<ProductEntity> list = products.toList(growable: false);
    if (list.isEmpty) return const DealkerCardSlots();
    return DealkerCardSlots(
      nameLines: list
          .map((ProductEntity p) => DealkerProductCard.lineCountOf(p, width))
          .reduce((int a, int b) => a > b ? a : b),
      showSold: list.any(DealkerProductCard.hasSeller),
      showRating: list.any((ProductEntity p) => p.hasRating),
    );
  }

  final int nameLines;
  final bool showSold;
  final bool showRating;

  double heightFor(double width) => DealkerProductCard.heightFor(
        width,
        nameLines: nameLines,
        showSold: showSold,
        showRating: showRating,
      );
}

/// The one Dealkr product card (design reference: "boAt Rockerz 450" card).
///
///   [NEW]                                   [♡]
///              product image
///                                      [ + Add ]   ← becomes [ − 1 + ] in the cart
///                  ● ○ ○
///   Name (bold, up to two lines)
///   Sold by: Vendor ›
///   ₹1,499  ₹2,999  [50% OFF]
///   ★ 4.9 | (134 reviews)
///   🚚 Fast delivery | ✓ Assured | ● In Stock
///
/// Rows only appear when the product actually has that data (no invented prices,
/// ratings or sellers).
class DealkerProductCard extends ConsumerWidget {
  const DealkerProductCard({
    required this.product,
    required this.width,
    this.onTap,
    this.onOptionsTap,
    this.buttonLabel,
    this.buttonColor,
    this.nameLines = 2,
    this.showSoldRow = true,
    this.showRatingRow = true,
    super.key,
  });

  /// Name lines reserved (see [lineCountOf]); search grids pass the row's max.
  final int nameLines;

  /// Keep the "Sold by" / rating rows even when empty. Lists that know no card
  /// has the data pass false and use the same flags in [heightFor].
  final bool showSoldRow;
  final bool showRatingRow;

  final ProductEntity product;

  /// Replaces "Add" (e.g. "Grab Deal →" in Deal of the Day).
  final String? buttonLabel;

  /// Replaces the default blue of the button.
  final Color? buttonColor;

  /// Card width in logical pixels — everything scales from it.
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onOptionsTap;

  /// Height of a card of the given width.
  static double heightFor(
    double width, {
    int nameLines = 2,
    bool showSold = true,
    bool showRating = true,
  }) =>
      _CardMetrics(
        width,
        nameLines: nameLines,
        showSold: showSold,
        showRating: showRating,
      ).height;

  /// Lines (1 or 2) the product's name needs at this card width.
  static int lineCountOf(ProductEntity product, double width) {
    final _CardMetrics m = _CardMetrics(width);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: product.name,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: m.nameFs,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          height: 1.22,
        ),
      ),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 2 * m.padSide);
    final int lines = tp.computeLineMetrics().length;
    tp.dispose();
    return lines <= 1 ? 1 : 2;
  }

  /// Whether the product has a seller name to show.
  static bool hasSeller(ProductEntity product) =>
      (product.soldBy ?? product.vendorName ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _CardMetrics m = _CardMetrics(
      width,
      nameLines: nameLines,
      showSold: showSoldRow,
      showRating: showRatingRow,
    );
    final double u = m.u;

    final String? badge = _badgeText();
    final String? shopId = product.shopId;
    if (shopId != null && shopId.isNotEmpty) {
      ref.read(shopDistanceProvider.notifier).request(shopId);
    }
    final ShopDistance? distance = (shopId == null || shopId.isEmpty)
        ? null
        : ref.watch(shopDistanceProvider
            .select((Map<String, ShopDistance> m) => m[shopId]));
    final String? seller = product.soldBy?.trim().isNotEmpty == true
        ? product.soldBy!.trim()
        : (product.vendorName?.trim().isNotEmpty == true
            ? product.vendorName!.trim()
            : null);

    final bool onSale = product.isOnSale;
    final int? discount = onSale && product.price > 0
        ? (((product.price - product.salePrice!) / product.price) * 100).round()
        : null;

    final int photoCount =
        product.images.where((String i) => i.trim().isNotEmpty).length;
    final String? imageUrl = product.thumbnailUrl?.isNotEmpty == true
        ? product.thumbnailUrl
        : (product.images.isNotEmpty ? product.images.first : null);

    return GestureDetector(
      onTap: product.isSponsored && (product.adToken ?? '').isNotEmpty
          ? () {
              _reportAdClick(ref);
              onTap?.call();
            }
          : onTap,
      child: Container(
        width: width,
        height: m.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(m.px(40, 14)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ProductCardTokens.shadow.withValues(alpha: 0.08),
              blurRadius: m.px(46, 12),
              offset: Offset(0, m.px(14, 4)),
            ),
          ],
        ),
        padding:
            EdgeInsets.fromLTRB(m.padSide, m.padTop, m.padSide, m.padBottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Image zone (+ NEW badge, wishlist, Add button, photo dots) ──
            SizedBox(
              height: m.imageZone,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        m.px(12),
                        m.px(26),
                        m.px(12),
                        m.btnH * 0.55 + (photoCount > 1 ? 8 : 0),
                      ),
                      child: imageUrl == null
                          ? const SizedBox.shrink()
                          : AppImage(
                              imageUrl: imageUrl,
                              memCacheWidth: 700,
                              memCacheHeight: 700,
                              fit: BoxFit.contain,
                              placeholder: const SizedBox.shrink(),
                              errorWidget: const SizedBox.shrink(),
                            ),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      left: 0,
                      top: m.px(4),
                      child: Container(
                        height: m.px(62, 22),
                        padding: EdgeInsets.symmetric(horizontal: m.px(32, 10)),
                        decoration: BoxDecoration(
                          color: product.isSponsored
                              ? const Color(0xFFF59E0B)
                              : ProductCardTokens.greenBadge,
                          borderRadius: BorderRadius.circular(m.px(31, 11)),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: (product.isSponsored
                                      ? const Color(0xFFF59E0B)
                                      : ProductCardTokens.greenBadge)
                                  .withValues(alpha: 0.30),
                              blurRadius: m.px(16, 5),
                              offset: Offset(0, m.px(6, 2)),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: m.px(33, 10),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _Heart(product: product, size: m.px(84, 32)),
                  ),
                  if (photoCount > 1)
                    Positioned(
                      left: 0,
                      right: m.plusW + m.px(14, 6),
                      bottom: 0,
                      height: m.btnH,
                      child: Center(
                        child: _PhotoDots(count: math.min(photoCount, 3), u: u),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _CartButton(
                      product: product,
                      m: m,
                      onOptionsTap: onOptionsTap,
                      label: buttonLabel,
                      color: buttonColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: m.gapName),

            // ── Name (two lines, always reserved so cards line up) ──────────
            SizedBox(
              height: m.nameH,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: m.nameFs,
                    fontWeight: FontWeight.w800,
                    color: ProductCardTokens.ink,
                    letterSpacing: -0.2,
                    height: 1.22,
                  ),
                ),
              ),
            ),
            if (showSoldRow) ...<Widget>[
              SizedBox(height: m.gapSold),

              // ── Sold by ─────────────────────────────────────────────────────
              SizedBox(
                height: m.soldH,
                child: seller == null
                    ? null
                    : Row(
                        children: <Widget>[
                          Text(
                            'Sold by: ',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: m.soldFs,
                              fontWeight: FontWeight.w500,
                              color: ProductCardTokens.grey,
                              height: 1.1,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              seller,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: m.soldFs,
                                fontWeight: FontWeight.w700,
                                color: ProductCardTokens.blue,
                                height: 1.1,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: m.soldFs * 1.35,
                            color: ProductCardTokens.blue,
                          ),
                          if (distance != null)
                            Text(
                              ' · ${distance.label}',
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: m.soldFs,
                                fontWeight: FontWeight.w600,
                                color: ProductCardTokens.grey,
                                height: 1.1,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
            SizedBox(height: m.gapPrice),

            // ── Price row ───────────────────────────────────────────────────
            SizedBox(
              height: m.priceH,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      _money(product.effectivePrice),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: m.priceFs,
                        fontWeight: FontWeight.w800,
                        color: ProductCardTokens.ink,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                    if (onSale) ...<Widget>[
                      SizedBox(width: m.px(24, 6)),
                      Text(
                        _money(product.price),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: m.mrpFs,
                          fontWeight: FontWeight.w700,
                          color: ProductCardTokens.greyLight,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: ProductCardTokens.greyLight,
                          decorationThickness: 1.6,
                          height: 1,
                        ),
                      ),
                    ],
                    if (discount != null && discount > 0) ...<Widget>[
                      SizedBox(width: m.px(22, 6)),
                      Container(
                        height: m.pillH,
                        padding: EdgeInsets.symmetric(horizontal: m.px(22, 7)),
                        decoration: BoxDecoration(
                          color: ProductCardTokens.pinkSoft,
                          borderRadius: BorderRadius.circular(m.pillH / 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$discount% OFF',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: m.px(28, 9.5),
                            fontWeight: FontWeight.w800,
                            color: ProductCardTokens.pink,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (showRatingRow) ...<Widget>[
              SizedBox(height: m.gapRating),

              // ── Rating ──────────────────────────────────────────────────────
              SizedBox(
                height: m.starFs,
                child: product.hasRating
                    ? Row(
                        children: <Widget>[
                          Icon(Icons.star_rounded,
                              size: m.starFs, color: ProductCardTokens.star),
                          SizedBox(width: m.px(8, 2)),
                          Text(
                            product.avgRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: m.ratingFs,
                              fontWeight: FontWeight.w800,
                              color: ProductCardTokens.ink,
                              height: 1,
                            ),
                          ),
                          if (product.ratingCount > 10) ...<Widget>[
                            SizedBox(width: m.px(18, 6)),
                            Container(
                              width: math.max(2 * u, 1),
                              height: m.starFs * 0.7,
                              color: ProductCardTokens.divider,
                            ),
                            SizedBox(width: m.px(18, 6)),
                            Flexible(
                              child: Text(
                                '(${_compact(product.ratingCount)} reviews)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: m.soldFs,
                                  fontWeight: FontWeight.w500,
                                  color: ProductCardTokens.grey,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : null,
              ),
            ],
            SizedBox(height: m.gapMeta),

            // ── Delivery · Assured · Stock ──────────────────────────────────
            SizedBox(
              height: m.metaH,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: c.maxWidth),
                    child: _MetaRow(product: product, m: m),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bills the advertiser for this tap. Fire-and-forget: shopping must never wait on it.
  void _reportAdClick(WidgetRef ref) {
    ref
        .read(dioClientProvider)
        .post<dynamic>('/ads/click', data: <String, dynamic>{'token': product.adToken})
        .then<void>((_) {}, onError: (Object _) {});
  }

  String? _badgeText() {
    if (product.isSponsored) return 'AD';
    if (product.customBadges.isNotEmpty) {
      final String b = product.customBadges.first.trim();
      if (b.isNotEmpty) return b.toUpperCase();
    }
    return product.isNewArrival ? 'NEW' : null;
  }

  /// ₹1,19,999 — Indian digit grouping (last three digits, then pairs).
  static String _money(double v) {
    final String s = v.round().toString();
    if (s.length <= 3) return '₹$s';
    String rest = s.substring(0, s.length - 3);
    final List<String> groups = <String>[s.substring(s.length - 3)];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '₹${groups.join(',')}';
  }

  static String _compact(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.product, required this.m});

  final ProductEntity product;
  final _CardMetrics m;

  @override
  Widget build(BuildContext context) {
    final double u = m.u;
    final double f = m.metaFs;
    final TextStyle label = TextStyle(
      fontFamily: 'DMSans',
      fontSize: f,
      fontWeight: FontWeight.w500,
      color: ProductCardTokens.metaLabel,
      height: 1,
    );
    Widget sep() => Container(
          width: 2.5 * u,
          height: m.metaIcon * 0.8,
          color: ProductCardTokens.divider,
        );

    final bool inStock = product.inStock;
    final List<Widget> groups = <Widget>[
      if (inStock)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.truckFill,
              size: m.metaIcon,
              color: ProductCardTokens.teal,
            ),
            SizedBox(width: 14 * u),
            Text('Fast delivery', style: label),
          ],
        ),
      if (product.isAuthentic)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.sealCheckFill,
              size: m.metaIcon,
              color: ProductCardTokens.green,
            ),
            SizedBox(width: 12 * u),
            Text('Assured', style: label),
          ],
        ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 28 * u,
            height: 28 * u,
            decoration: BoxDecoration(
              color:
                  inStock ? ProductCardTokens.green : ProductCardTokens.danger,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 14 * u),
          Text(
            inStock ? 'In Stock' : 'Out of stock',
            style: label.copyWith(
              fontWeight: FontWeight.w700,
              color:
                  inStock ? ProductCardTokens.green : ProductCardTokens.danger,
            ),
          ),
        ],
      ),
    ];

    // Groups spread across the full width with thin dividers between them.
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < groups.length; i++) {
      if (i > 0) {
        children.add(SizedBox(width: 30 * u));
        children.add(sep());
        children.add(SizedBox(width: 30 * u));
      }
      children.add(groups[i]);
    }
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
  }
}

class _Heart extends ConsumerWidget {
  const _Heart({required this.product, required this.size});

  final ProductEntity product;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool wishlisted = ref.watch(
      wishlistProvider.select(
        (async) => switch (async) {
          AsyncData(:final value) =>
            value.items.any((item) => item.productId == product.id),
          _ => false,
        },
      ),
    );
    return Material(
      color: Colors.white,
      shape: CircleBorder(
          side: BorderSide(
              color: ProductCardTokens.heartBorder, width: size * 0.014 + 0.6)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          final AuthGateController gate = ref.read(authGateControllerProvider);
          final bool allowed = await gate.protectWishlist(context, product);
          if (!allowed || !context.mounted) return;
          final result =
              await ref.read(wishlistProvider.notifier).toggleWishlist(product);
          if (!context.mounted || result.isSuccess) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(result.failure!.message)));
        },
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: PhosphorIcon(
              wishlisted ? PhosphorIcons.heartFill : PhosphorIcons.heart,
              size: size * 0.5,
              color: wishlisted
                  ? ProductCardTokens.heartOn
                  : ProductCardTokens.heartOff,
            ),
          ),
        ),
      ),
    );
  }
}

/// Photo-count dots under the image (first one active).
class _PhotoDots extends StatelessWidget {
  const _PhotoDots({required this.count, required this.u});

  final int count;
  final double u;

  @override
  Widget build(BuildContext context) {
    final double d = math.max(18 * u, 6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          Container(
            width: d,
            height: d,
            margin: EdgeInsets.symmetric(horizontal: d * 0.6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == 0 ? ProductCardTokens.ink : ProductCardTokens.divider,
            ),
          ),
      ],
    );
  }
}

/// "+ Add" button floating on the image's bottom-right corner. Once the product is in
/// the cart it becomes a "− 1 +" stepper. Deliberately larger than the design.
class _CartButton extends ConsumerWidget {
  const _CartButton({
    required this.product,
    required this.m,
    this.onOptionsTap,
    this.label,
    this.color,
  });

  final ProductEntity product;
  final _CardMetrics m;
  final VoidCallback? onOptionsTap;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int quantity = product.hasMultipleOptions
        ? 0
        : ref.watch(cartItemQuantityProvider(product.id));
    final Color accent = product.inStock
        ? (color ?? ProductCardTokens.blue)
        : ProductCardTokens.buttonDisabled;
    final double radius = m.px(26, 11);
    final BorderRadius br = BorderRadius.circular(radius);

    Widget shell({
      required Widget child,
      required double minWidth,
      required Color fill,
      required Color border,
      VoidCallback? onTap,
    }) =>
        Container(
          decoration: BoxDecoration(
            borderRadius: br,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.07),
                blurRadius: m.px(14, 5),
                offset: Offset(0, m.px(4, 1.5)),
              ),
            ],
          ),
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              borderRadius: br,
              side: BorderSide(color: border, width: math.max(3 * m.u, 1.4)),
            ),
            child: InkWell(
              borderRadius: br,
              onTap: onTap,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minWidth: minWidth, minHeight: m.btnH),
                child: SizedBox(
                  height: m.btnH,
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        );

    if (quantity > 0) {
      Widget step(IconData icon, VoidCallback onTap) => InkWell(
            borderRadius: br,
            onTap: onTap,
            child: SizedBox(
              width: m.stepW / 3,
              height: m.btnH,
              child: Center(
                  child: Icon(icon, size: m.btnFs * 1.45, color: accent)),
            ),
          );
      return shell(
        minWidth: m.stepW,
        fill: Color.alphaBlend(accent.withValues(alpha: 0.08), Colors.white),
        border: accent.withValues(alpha: 0.35),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            step(Icons.remove_rounded, () async {
              final cart = ref.read(cartProvider.notifier);
              final result = quantity <= 1
                  ? await cart.removeItem(product.id,
                      shopProductId: product.shopProductId)
                  : await cart.updateItem(product.id, quantity - 1,
                      shopProductId: product.shopProductId);
              if (context.mounted && !result.isSuccess) {
                showCartSnackBar(context, result.failure!.message);
              }
            }),
            SizedBox(
              width: m.stepW / 3,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: m.btnFs * 1.15,
                  fontWeight: FontWeight.w800,
                  color: ProductCardTokens.ink,
                  height: 1,
                ),
              ),
            ),
            step(Icons.add_rounded, () async {
              final status = ref.read(purchaseLimitStatusProvider(product.id));
              if (status?.isAtLimit ?? false) {
                AppToast.show(context, 'Maximum product order complete');
                return;
              }
              final result = await ref.read(cartProvider.notifier).updateItem(
                  product.id, quantity + 1,
                  shopProductId: product.shopProductId);
              if (context.mounted && !result.isSuccess) {
                showCartSnackBar(context, result.failure!.message);
              }
            }),
          ],
        ),
      );
    }

    final bool plusOnly = label == null && product.inStock;
    return shell(
      minWidth: plusOnly ? m.plusW : m.btnW,
      fill: Colors.white,
      border: accent,
      child: plusOnly
          ? Icon(Icons.add_rounded, size: m.plusIcon, color: accent)
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: m.px(22, 8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (product.inStock && label == null) ...<Widget>[
                    Icon(Icons.add_rounded, size: m.btnFs * 1.5, color: accent),
                    SizedBox(width: m.px(12, 3)),
                  ],
                  Text(
                    product.inStock ? (label ?? 'Add') : 'Sold out',
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: m.btnFs,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
      onTap: product.inStock
          ? () async {
              if (product.hasMultipleOptions && onOptionsTap != null) {
                onOptionsTap!.call();
                return;
              }
              final status = ref.read(purchaseLimitStatusProvider(product.id));
              if (status?.isAtLimit ?? false) {
                AppToast.show(context, 'Maximum product order complete');
                return;
              }
              final AuthGateController gate =
                  ref.read(authGateControllerProvider);
              final bool allowed =
                  await gate.protectAddToCart(context, product);
              if (!allowed || !context.mounted) return;
              final result = await ref.read(cartProvider.notifier).addItem(
                    product.id,
                    1,
                    product: product,
                    shopProductId: product.shopProductId,
                  );
              if (context.mounted && !result.isSuccess) {
                showCartSnackBar(context, result.failure!.message);
              }
            }
          : null,
    );
  }
}
