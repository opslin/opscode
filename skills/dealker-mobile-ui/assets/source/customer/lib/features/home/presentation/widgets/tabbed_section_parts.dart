import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';

import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';

/// Helpers shared by the tabbed home sections (Steal Deals, Collection Showcase).
Color colorFrom(Map<String, dynamic> c, String k, Color d) {
  final Object? v = c[k];
  if (v is! String) return d;
  String h = v.replaceAll('#', '').trim();
  if (h.length == 3) h = h.split('').map((String e) => '$e$e').join();
  if (h.length == 6) h = 'FF$h';
  final int? n = int.tryParse(h, radix: 16);
  return n == null ? d : Color(n);
}

String stringFrom(Map<String, dynamic> c, String k, String d) {
  final Object? v = c[k];
  return v is String && v.trim().isNotEmpty ? v : d;
}

const double kTabFlare = 14;

/// ₹ with Indian digit grouping (₹1,24,999), no decimals when whole.
String formatRupees(double v) {
  final bool whole = v.truncateToDouble() == v;
  final List<String> parts =
      (whole ? v.toStringAsFixed(0) : v.toStringAsFixed(2)).split('.');
  String digits = parts[0];
  if (digits.length > 3) {
    final String last3 = digits.substring(digits.length - 3);
    String rest = digits.substring(0, digits.length - 3);
    final List<String> groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    digits = '${groups.join(',')},$last3';
  }
  return '₹$digits${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// Thin dashed rule (Brand Spotlight divider).
class DashedDivider extends StatelessWidget {
  const DashedDivider({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedPainter(color),
        size: const Size.fromHeight(1),
      );
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + 4).clamp(0, size.width), 0), p);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}

/// Title (artwork image when uploaded, text otherwise) + sub-title with a hairline.
class TabbedSectionHeader extends StatelessWidget {
  const TabbedSectionHeader({
    required this.title,
    required this.titleImageUrl,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    this.titleSize = 16.5,
    super.key,
  });

  final String title;
  final String titleImageUrl;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: titleImageUrl.isNotEmpty
              ? SizedBox(
                  height: 44,
                  child: AppImage(
                    imageUrl: titleImageUrl,
                    memCacheWidth: 900,
                    memCacheHeight: 200,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    placeholder: const SizedBox.shrink(),
                    errorWidget: const SizedBox.shrink(),
                  ),
                )
              : Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    height: 1.1,
                  ),
                ),
        ),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 1.2,
                    color: subtitleColor.withValues(alpha: 0.22),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Horizontal rail of the one Dealkr product card (the same box as the
/// product carousels), with the tab's "See All" button underneath.
class DealerProductRail extends StatelessWidget {
  const DealerProductRail({
    required this.products,
    required this.seeAllLabel,
    required this.seeAllRoute,
    this.horizontalPadding = 14,
    super.key,
  });

  final double horizontalPadding;
  final List<ProductEntity> products;
  final String seeAllLabel;

  /// Null hides the button (no category to open).
  final String? seeAllRoute;

  @override
  Widget build(BuildContext context) {
    final double cardW = (MediaQuery.sizeOf(context).width * 0.44).clamp(
      150.0,
      190.0,
    );
    final DealkerCardSlots slots = DealkerCardSlots.forProducts(
      products,
      cardW,
    );
    return Column(
      children: <Widget>[
        SizedBox(
          height: slots.heightFor(cardW) + 6,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int i) {
              final ProductEntity p = products[i];
              return DealkerProductCard(
                product: p,
                width: cardW,
                nameLines: slots.nameLines,
                showSoldRow: slots.showSold,
                showRatingRow: slots.showRating,
                onTap: () => context.push('/product/${p.id}'),
                onOptionsTap: p.hasMultipleOptions
                    ? () => showProductOptionsSheet(context, p)
                    : null,
              );
            },
          ),
        ),
        if (seeAllRoute != null && seeAllLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Material(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push(seeAllRoute!),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E4E8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        seeAllLabel,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_right_rounded,
                        size: 22,
                        color: Color(0xFF111111),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws the accent baseline with the selected tab lifted out of it: rounded
/// top corners, concave flares at the bottom, soft accent fill.
class TabStripPainter extends CustomPainter {
  TabStripPainter({
    required this.left,
    required this.width,
    required this.accent,
    required this.soft,
  });

  final double left;
  final double width;
  final Color accent;
  final Color soft;

  @override
  void paint(Canvas canvas, Size size) {
    const double r = 16; // top corner radius
    const double f = kTabFlare; // flare radius
    const double sw = 1.6;
    final double h = size.height - sw / 2;
    final double l = left;
    final double rr = left + width;
    const double top = sw / 2;

    final Path outline = Path()
      ..moveTo(0, h)
      ..lineTo(l - f, h)
      ..arcToPoint(
        Offset(l, h - f),
        radius: const Radius.circular(f),
        clockwise: false,
      )
      ..lineTo(l, top + r)
      ..arcToPoint(Offset(l + r, top), radius: const Radius.circular(r))
      ..lineTo(rr - r, top)
      ..arcToPoint(Offset(rr, top + r), radius: const Radius.circular(r))
      ..lineTo(rr, h - f)
      ..arcToPoint(
        Offset(rr + f, h),
        radius: const Radius.circular(f),
        clockwise: false,
      )
      ..lineTo(size.width, h);

    final Path tabFill = Path()
      ..moveTo(l - f, h)
      ..arcToPoint(
        Offset(l, h - f),
        radius: const Radius.circular(f),
        clockwise: false,
      )
      ..lineTo(l, top + r)
      ..arcToPoint(Offset(l + r, top), radius: const Radius.circular(r))
      ..lineTo(rr - r, top)
      ..arcToPoint(Offset(rr, top + r), radius: const Radius.circular(r))
      ..lineTo(rr, h - f)
      ..arcToPoint(
        Offset(rr + f, h),
        radius: const Radius.circular(f),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(
      tabFill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[soft, soft.withValues(alpha: 0.35)],
        ).createShader(Rect.fromLTWH(l, 0, width, size.height)),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(TabStripPainter old) =>
      old.left != left ||
      old.width != width ||
      old.accent != accent ||
      old.soft != soft;
}

/// Outlined ADD button that becomes a − n + stepper once the product is in the cart.
class AddPill extends ConsumerWidget {
  const AddPill({
    required this.product,
    required this.accent,
    required this.label,
  });

  final ProductEntity product;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int qty = product.hasMultipleOptions
        ? 0
        : ref.watch(cartItemQuantityProvider(product.id));
    final Color c = product.inStock ? accent : const Color(0xFFB8B8B8);
    final BorderRadius br = BorderRadius.circular(10);

    Widget shell(Widget child, {VoidCallback? onTap}) => Container(
          height: 38,
          constraints: const BoxConstraints(minWidth: 78),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: br,
            border: Border.all(color: c, width: 1.5),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.withValues(alpha: 0.3),
                offset: const Offset(1.5, 2.5),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: br,
              onTap: onTap,
              child: Center(child: child),
            ),
          ),
        );

    if (qty > 0) {
      Future<void> change(int next) async {
        final cart = ref.read(cartProvider.notifier);
        final result = next <= 0
            ? await cart.removeItem(
                product.id,
                shopProductId: product.shopProductId,
              )
            : await cart.updateItem(
                product.id,
                next,
                shopProductId: product.shopProductId,
              );
        if (context.mounted && !result.isSuccess) {
          showCartSnackBar(context, result.failure!.message);
        }
      }

      return shell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: () => change(qty - 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.remove_rounded, size: 18, color: c),
              ),
            ),
            Text(
              '$qty',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
            InkWell(
              onTap: () {
                final status = ref.read(
                  purchaseLimitStatusProvider(product.id),
                );
                if (status?.isAtLimit ?? false) {
                  AppToast.show(context, 'Maximum product order complete');
                  return;
                }
                change(qty + 1);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.add_rounded, size: 18, color: c),
              ),
            ),
          ],
        ),
      );
    }

    return shell(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          product.inStock ? label : 'Sold out',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: c,
          ),
        ),
      ),
      onTap: product.inStock
          ? () async {
              if (product.hasMultipleOptions) {
                showProductOptionsSheet(context, product);
                return;
              }
              final status = ref.read(purchaseLimitStatusProvider(product.id));
              if (status?.isAtLimit ?? false) {
                AppToast.show(context, 'Maximum product order complete');
                return;
              }
              final bool allowed = await ref
                  .read(authGateControllerProvider)
                  .protectAddToCart(context, product);
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
