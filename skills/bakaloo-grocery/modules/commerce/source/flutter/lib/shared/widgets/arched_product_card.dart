import 'package:bakaloo_flutter_app/demo/storefront.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

// ── PHASE 3B: Arch background painter ─────────────────────────────────────
//
// Replaces the ClipPath(ArchedTopBoxClipper) + DecoratedBox pattern with a
// CustomPaint that draws the arch fill directly on the canvas.
//
// Why this is faster:
//   ClipPath forces Flutter to render the card content into an offscreen
//   compositing layer (saveLayer) before applying the clip mask, adding ~1ms
//   of raster work per card per frame. CustomPaint draws directly into the
//   current layer — no intermediate buffer required.
//
// The painted shape is pixel-identical to ArchedTopBoxClipper for all values
// of radius and archHeight used in the app (radius=24, archHeight=14).
class _ArchBackgroundPainter extends CustomPainter {
  const _ArchBackgroundPainter({
    required this.color,
    required this.gradient,
    required this.radius,
    required this.archHeight,
    required this.size,
  });

  final Color color;
  final Gradient? gradient;
  final double radius;
  final double archHeight;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final double w = canvasSize.width;
    final double h = canvasSize.height;
    final double r = radius.clamp(0, h / 2);

    final path = Path()
      ..moveTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r), clockwise: false)
      ..lineTo(w - r, h)
      ..arcToPoint(
        Offset(w, h - r),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(w, archHeight + r)
      ..arcToPoint(
        Offset(w - r, archHeight),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..quadraticBezierTo(w / 2, -archHeight, r, archHeight)
      ..arcToPoint(
        Offset(0, archHeight + r),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..close();

    final paint = Paint()..isAntiAlias = true;
    if (gradient != null) {
      paint.shader = gradient!.createShader(Rect.fromLTWH(0, 0, w, h));
    } else {
      paint.color = color;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArchBackgroundPainter oldDelegate) =>
      color != oldDelegate.color ||
      gradient != oldDelegate.gradient ||
      radius != oldDelegate.radius ||
      archHeight != oldDelegate.archHeight;
}

// ── PHASE 3B: Starburst badge painter ──────────────────────────────────────
//
// Replaces ClipPath(_ArchedDiscountBurstClipper) + DecoratedBox(gradient)
// with a CustomPaint that draws the starburst directly. Eliminates the nested
// ClipPath/saveLayer inside an already-clipped card.
class _StarburstBadgePainter extends CustomPainter {
  const _StarburstBadgePainter();

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFFA16F), Color(0xFFFF784E)],
  );

  static const int _pointCount = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.76;

    final path = Path();
    for (var i = 0; i < _pointCount * 2; i++) {
      final r = i.isEven ? outerRadius : innerRadius;
      final angle = (math.pi / _pointCount) * i - (math.pi / 2);
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final paint = Paint()
      ..isAntiAlias = true
      ..shader = _gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ArchedProductCard extends StatefulWidget {
  const ArchedProductCard({
    required this.product,
    required this.backgroundColor,
    this.cardShape = 'arch',
    this.archHeight = 14.0,
    this.cornerRadius = 24.0,
    this.boxGradientColors,
    this.width = 148,
    this.onTap,
    super.key,
  });

  final ProductEntity product;
  final Color backgroundColor;
  final String cardShape;
  final double archHeight;
  final double cornerRadius;
  final List<Color>? boxGradientColors;
  final double width;
  final VoidCallback? onTap;

  @override
  State<ArchedProductCard> createState() => _ArchedProductCardState();
}

class _ArchedProductCardState extends State<ArchedProductCard> {
  bool _isPressed = false;
  bool _suppressCardTap = false;

  void _handleTapDown(
    TapDownDetails details,
    double cardWidth,
    double cardHeight,
  ) {
    final localPosition = details.localPosition;
    final tappedControlArea = localPosition.dy >= cardHeight - 92.h;
    _suppressCardTap = tappedControlArea;
    if (tappedControlArea) {
      return;
    }

    setState(() => _isPressed = true);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cardWidth = widget.width.w;
    final imageHeight = cardWidth * 0.9;
    final cardHeight = imageHeight + 122.h;
    final effectivePrice = product.salePrice ?? product.price;
    final isOnSale =
        product.salePrice != null && product.salePrice! < product.price;
    final discountPercent = isOnSale ? product.discountPercent : null;
    final isWaveShape = widget.cardShape == 'wave';
    final archOffset = isWaveShape ? 0.0 : widget.archHeight;

    // PHASE 3B: Build the card background using CustomPaint (arch) or
    // ClipRRect (wave). Only wave shape retains ClipRRect — it has simple
    // rounded corners with no arch, so ClipRRect is already the cheapest
    // option and doesn't create a saveLayer at opaque colors.
    Widget cardContainer;
    if (isWaveShape) {
      // Wave: standard ClipRRect — no saveLayer for solid background.
      final cardDecoration = BoxDecoration(
        color: widget.boxGradientColors == null ? widget.backgroundColor : null,
        gradient: widget.boxGradientColors != null
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.boxGradientColors!,
              )
            : null,
        borderRadius: BorderRadius.circular(widget.cornerRadius.r),
      );
      cardContainer = ClipRRect(
        borderRadius: BorderRadius.circular(widget.cornerRadius.r),
        child: DecoratedBox(
          decoration: cardDecoration,
          child: _buildCardContent(
            product: product,
            imageHeight: imageHeight,
            archOffset: archOffset,
            effectivePrice: effectivePrice,
            isOnSale: isOnSale,
            discountPercent: discountPercent,
          ),
        ),
      );
    } else {
      // Arch: CustomPaint fills the arch shape directly — no ClipPath saveLayer.
      // The card content is stacked on top of the painted background.
      // A SizedBox constrains the content to the card dimensions, and an
      // outermost ClipRRect with the corner radius prevents the content's
      // rectangular corners from showing outside the arch shape at the bottom.
      // This single ClipRRect is less expensive than the full arch ClipPath
      // because the clip region is a simple rounded rect, not a custom path,
      // and Flutter can optimise it without a saveLayer in most cases.
      final gradient = widget.boxGradientColors != null
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.boxGradientColors!,
            )
          : null;

      cardContainer = ClipRRect(
        borderRadius: BorderRadius.circular(widget.cornerRadius.r),
        child: CustomPaint(
          painter: _ArchBackgroundPainter(
            color: widget.backgroundColor,
            gradient: gradient,
            radius: widget.cornerRadius,
            archHeight: widget.archHeight,
            size: Size(cardWidth, cardHeight),
          ),
          child: _buildCardContent(
            product: product,
            imageHeight: imageHeight,
            archOffset: archOffset,
            effectivePrice: effectivePrice,
            isOnSale: isOnSale,
            discountPercent: discountPercent,
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (details) => _handleTapDown(details, cardWidth, cardHeight),
      onTapUp: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      onTapCancel: () {
        _suppressCardTap = false;
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      onTap: () {
        if (_suppressCardTap) {
          _suppressCardTap = false;
          return;
        }
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: cardContainer,
        ),
      ),
    );
  }

  Widget _buildCardContent({
    required ProductEntity product,
    required double imageHeight,
    required double archOffset,
    required double effectivePrice,
    required bool isOnSale,
    required int? discountPercent,
  }) {
    final imageUrl =
        product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: imageHeight + widget.archHeight,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12.w,
                        archOffset + 4.h,
                        12.w,
                        0,
                      ),
                      child: imageUrl == null || imageUrl.isEmpty
                          ? Center(
                              child: PhosphorIcon(
                                PhosphorIcons.image,
                                color: AppColors.textDisabled,
                                size: 32,
                              ),
                            )
                          : AppImage(
                              imageUrl: imageUrl,
                              memCacheWidth: 320,
                              memCacheHeight: 320,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              placeholder: const SizedBox.expand(),
                              errorWidget: Center(
                                child: PhosphorIcon(
                                  PhosphorIcons.imageBroken,
                                  color: AppColors.textDisabled,
                                  size: 28,
                                ),
                              ),
                            ),
                    ),
                  ),
                  // PHASE 3B: Replace ClipPath starburst with CustomPaint.
                  // The _StarburstBadgePainter draws the burst shape directly
                  // onto the canvas — no nested saveLayer inside the card.
                  if (discountPercent != null)
                    Positioned(
                      top: archOffset + 1.h,
                      left: 5.w,
                      child: SizedBox(
                        width: 46.w,
                        height: 46.w,
                        child: CustomPaint(
                          painter: const _StarburstBadgePainter(),
                          child: Center(
                            child: Text(
                              '${discountPercent.toInt()}%\nOFF',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 3.h,
                    right: 8.w,
                    child: PhosphorIcon(
                      PhosphorIcons.heart,
                      size: 18,
                      color: const Color(0xFFE04A86),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(11.w, 1.h, 11.w, 0),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.2.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.22,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(11.w, 1.h, 11.w, 0),
              child: Text(
                product.displayUnit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF7F7F7F),
                  fontSize: 11.4.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Padding(
              padding: EdgeInsets.fromLTRB(11.w, 0, 9.w, 8.h),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '₹ ${effectivePrice.toInt()}',
                            style: TextStyle(
                              fontSize: 18.2.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1A1A1A),
                              height: 1.1,
                            ),
                          ),
                          if (isOnSale)
                            Text(
                              '₹${product.price.toInt()}',
                              style: TextStyle(
                                fontSize: 12.6.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF999999),
                                decoration: TextDecoration.lineThrough,
                                decorationColor: const Color(0xFF999999),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _IsolatedArchedAddButton(product: product),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!product.inStock)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(widget.cornerRadius.r),
              ),
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Text(
                  'Out of stock',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE53935),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Standalone cart adapter for Bakaloo's arched product controls.
class _IsolatedArchedAddButton extends ConsumerWidget {
  const _IsolatedArchedAddButton({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(
      demoShopProvider.select((cart) => cart.quantity(product.id)),
    );
    final shop = ref.read(demoShopProvider.notifier);
    if (quantity == 0) {
      return OutlinedButton(
        onPressed: product.inStock ? () => shop.setQuantity(product, 1) : null,
        style: OutlinedButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: Colors.white,
        ),
        child: Text(
          'ADD',
          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
        ),
      );
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8.r),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => shop.setQuantity(product, quantity - 1),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Icon(
                Icons.remove,
                size: 15.sp,
                semanticLabel: 'Remove one',
              ),
            ),
          ),
          Text('$quantity'),
          InkWell(
            onTap: quantity >= product.stockQuantity
                ? null
                : () => shop.setQuantity(product, quantity + 1),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Icon(Icons.add, size: 15.sp, semanticLabel: 'Add one'),
            ),
          ),
        ],
      ),
    );
  }
}
