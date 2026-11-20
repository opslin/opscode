import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/theme/remote_theme_model.dart';
import 'package:dealker_app/core/theme/remote_theme_provider.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Marketplace product box of `05-home-below-fold.jpg` (New Stock / Clearance
/// / Top Deals rows): badge + heart over the picture, then name, variant line,
/// price with struck-through MRP, rating and stock. Every figure comes from
/// the product payload; colours come from [HomeLookTheme] so they are
/// editable in the dashboard. Wired in as `ProductCardVariant
/// .dealkerMarketplaceBox` (config `DEALKER_MARKETPLACE_BOX`).
class MarketplaceProductBox extends ConsumerWidget {
  const MarketplaceProductBox({
    required this.product,
    required this.width,
    this.heart,
    super.key,
  });

  final ProductEntity product;
  final double width;

  /// The shared wishlist button, supplied by ProductCard.
  final Widget? heart;

  static String inr(num value) {
    final String digits = value.round().toString();
    if (digits.length <= 3) return '₹$digits';
    final String last3 = digits.substring(digits.length - 3);
    String rest = digits.substring(0, digits.length - 3);
    final List<String> groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '₹${groups.join(',')},$last3';
  }

  static String _count(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeLookTheme look = ref.watch(
      activeTabThemeProvider.select((RemoteTheme t) => t.sections.homeLook),
    );
    final String? imageUrl = product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);
    final OptimizedMediaAsset media = ApiConstants.optimizedMedia(
      imageUrl,
      profile: CustomerImageProfile.listProduct,
    );
    final String? badge =
        product.customBadges.isNotEmpty ? product.customBadges.first : null;
    final String variantLine =
        (product.netQuantity ?? product.optionLabel ?? product.brand ?? '')
            .trim();
    final double price = product.salePrice ?? product.price;
    final bool onSale =
        product.salePrice != null && product.salePrice! < product.price;
    final Color text = look.productTextColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: look.productBoxColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: look.productBoxBorderColor, width: 0.8),
      ),
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: width * 0.62,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: media.url == null
                        ? const SizedBox.shrink()
                        : AppImage(
                            imageUrl: media.url!,
                            memCacheWidth: media.memCacheWidth,
                            memCacheHeight: media.memCacheHeight,
                            fit: BoxFit.contain,
                            placeholder: const SizedBox.shrink(),
                            errorWidget: const SizedBox.shrink(),
                          ),
                  ),
                  if (badge != null && badge.isNotEmpty)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: look.productBadgeColor,
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        child: Text(
                          badge.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (heart != null)
                    Positioned(top: 0, right: 0, child: heart!),
                ],
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (variantLine.isNotEmpty)
              Text(
                variantLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text.withValues(alpha: 0.55),
                  fontSize: 10.sp,
                ),
              ),
            SizedBox(height: 3.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  inr(price),
                  style: TextStyle(
                    color: text,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (onSale) ...<Widget>[
                  SizedBox(width: 5.w),
                  Flexible(
                    child: Text(
                      inr(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text.withValues(alpha: 0.4),
                        fontSize: 10.sp,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 3.h),
            Row(
              children: <Widget>[
                if (product.avgRating > 0) ...<Widget>[
                  PhosphorIcon(
                    PhosphorIcons.starFill,
                    size: 11.w,
                    color: const Color(0xFFF5A623),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    product.avgRating.toStringAsFixed(1),
                    style: TextStyle(
                      color: text,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (product.ratingCount > 0)
                    Text(
                      ' (${_count(product.ratingCount)})',
                      style: TextStyle(
                        color: text.withValues(alpha: 0.5),
                        fontSize: 9.sp,
                      ),
                    ),
                ],
                const Spacer(),
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: product.inStock
                        ? look.productStockColor
                        : const Color(0xFFD93025),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 3.w),
                Text(
                  !product.inStock
                      ? 'Out of stock'
                      : product.lowStock
                          ? 'Only ${product.stockQuantity} left'
                          : 'In Stock',
                  style: TextStyle(
                    color: product.inStock && !product.lowStock
                        ? look.productStockColor
                        : const Color(0xFFD93025),
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
