import 'package:dealker_app/shared/widgets/fullscreen_image_viewer.dart';
import 'package:dealker_app/shared/widgets/loading/dealker_loading_button.dart';
import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/exchange/data/exchange_models.dart';
import 'package:dealker_app/features/products/presentation/widgets/product_exchange_card.dart';
import 'package:dealker_app/features/exchange/presentation/exchange_providers.dart';
import 'package:dealker_app/features/products/data/condition/product_condition.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/presentation/widgets/product_condition_blocks.dart';
import 'package:dealker_app/features/products/presentation/providers/product_store_info_provider.dart';
import 'package:dealker_app/features/wishlist/presentation/providers/wishlist_ids_provider.dart';
import 'package:dealker_app/shared/widgets/marketplace_product_box.dart';

const Color _indigo = Color(0xFF1D4ED8);
const Color _ink = Color(0xFF14142B);
const Color _muted = Color(0xFF6B6F85);
const Color _line = Color(0xFFE4E6F2);
const Color _green = Color(0xFF1FA463);

String _inr(num v) => MarketplaceProductBox.inr(v);

/// "Apple iPhone 15 Pro (256GB, Natural Titanium)" → title + "Natural Titanium | 256GB".
({String title, String? chip}) splitProductName(String name) {
  final RegExpMatch? m = RegExp(r'^(.*?)\s*\(([^)]*)\)\s*$').firstMatch(name);
  if (m == null) return (title: name, chip: null);
  final List<String> parts = m
      .group(2)!
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList();
  final RegExp storage = RegExp(r'\d+\s*(GB|TB)', caseSensitive: false);
  final List<String> mem = parts.where(storage.hasMatch).toList();
  final List<String> rest =
      parts.where((String p) => !storage.hasMatch(p)).toList();
  return (title: m.group(1)!, chip: <String>[...rest, ...mem].join(' | '));
}

/// Everything above the fold of the product page (design "2. Product Detail Page").
class PdpHead extends ConsumerStatefulWidget {
  const PdpHead({
    required this.product,
    required this.onBack,
    required this.onWishlist,
    required this.onCart,
    required this.onExchange,
    this.condition,
    super.key,
  });

  final ProductEntity product;
  final VoidCallback onBack;
  final VoidCallback onWishlist;
  final VoidCallback onCart;
  final ValueChanged<String?> onExchange;
  final ProductCondition? condition;

  @override
  ConsumerState<PdpHead> createState() => _PdpHeadState();
}

class _PdpHeadState extends ConsumerState<PdpHead> {
  final PageController _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  List<String> get _images {
    final List<String> list =
        widget.product.images.where((String s) => s.isNotEmpty).toList();
    if (list.isEmpty && (widget.product.thumbnailUrl ?? '').isNotEmpty) {
      list.add(widget.product.thumbnailUrl!);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ProductEntity p = widget.product;
    final ({String title, String? chip}) name = splitProductName(p.name);
    final List<String> imgs = _images;
    final bool wished = ref.watch(
      wishlistIdsProvider.select((Set<String> ids) => ids.contains(p.id)),
    );
    final int cartCount = ref.watch(cartCountProvider);
    final ProductStoreInfo? store =
        ref.watch(productStoreInfoProvider(p.id)).asData?.value;
    final String? seller = (p.soldBy?.trim().isNotEmpty ?? false)
        ? p.soldBy!.trim()
        : (store?.hasStore ?? false)
            ? store!.shopName
            : null;
    final double mrp = p.price;
    final double price = p.effectivePrice;
    final int off = p.isOnSale ? (((mrp - price) / mrp) * 100).round() : 0;
    final ExchangeOffer exchange =
        ref.watch(exchangeForProductProvider(p.id)).asData?.value ??
            ExchangeOffer.none;

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // top bar
            Padding(
              padding: EdgeInsets.fromLTRB(6.w, 4.h, 6.w, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                    onPressed: widget.onBack,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      wished ? Icons.favorite : Icons.favorite_border_rounded,
                      color: wished ? const Color(0xFFE5254B) : _ink,
                    ),
                    onPressed: widget.onWishlist,
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          color: _ink,
                        ),
                        onPressed: widget.onCart,
                      ),
                      if (cartCount > 0)
                        Positioned(
                          right: 4.w,
                          top: 4.h,
                          child: Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE5254B),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$cartCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // image carousel
            SizedBox(
              height: 290.h,
              child: Stack(
                children: <Widget>[
                  PageView.builder(
                    controller: _pc,
                    itemCount: imgs.isEmpty ? 1 : imgs.length,
                    onPageChanged: (int i) => setState(() => _i = i),
                    itemBuilder: (BuildContext c, int i) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: imgs.isEmpty
                          ? null
                          : () => FullscreenImageViewer.open(
                                c,
                                images: imgs
                                    .map<String>(
                                      (dynamic u) => webImageSource('$u'),
                                    )
                                    .toList(),
                                initialIndex: i,
                              ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 36.w, vertical: 6.h),
                        child: imgs.isEmpty
                            ? const Icon(
                                Icons.image_not_supported_outlined,
                                color: _muted,
                                size: 48,
                              )
                            : Image.network(
                                webImageSource(imgs[i]),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: _muted,
                                  size: 48,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (widget.condition != null)
                    Positioned(
                      left: 16.w,
                      top: 6.h,
                      child: ConditionTag(condition: widget.condition!),
                    ),
                  if (imgs.length > 1)
                    Positioned(
                      right: 20.w,
                      bottom: 8.h,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A8D9B),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Text(
                          '${_i + 1}/${imgs.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (imgs.length > 1)
              SizedBox(
                height: 62.h,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  scrollDirection: Axis.horizontal,
                  itemCount: imgs.length,
                  separatorBuilder: (_, __) => SizedBox(width: 10.w),
                  itemBuilder: (BuildContext c, int i) => GestureDetector(
                    onTap: () => _pc.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                    child: Container(
                      width: 62.h,
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: i == _i ? _indigo : _line,
                          width: i == _i ? 2 : 1,
                        ),
                      ),
                      child: Image.network(
                        webImageSource(imgs[i]),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (widget.condition != null) ...<Widget>[
                    TrustChips(condition: widget.condition!),
                    SizedBox(height: 8.h),
                  ],
                  Text(
                    name.title,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.15,
                    ),
                  ),
                  if (name.chip != null && name.chip!.isNotEmpty) ...<Widget>[
                    SizedBox(height: 6.h),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE6C7),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        name.chip!,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 10.h),
                  Row(
                    children: <Widget>[
                      if (p.hasRating) ...<Widget>[
                        const Icon(Icons.star_rounded, color: _green, size: 20),
                        SizedBox(width: 3.w),
                        Text(
                          p.avgRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          '(${_count(p.ratingCount)} Reviews)',
                          style: TextStyle(fontSize: 12.sp, color: _muted),
                        ),
                        SizedBox(width: 10.w),
                      ],
                      if (p.isAuthentic)
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F6EC),
                              borderRadius: BorderRadius.circular(18.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.check_circle,
                                  color: _green,
                                  size: 15,
                                ),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    'Verified Seller',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (seller != null) ...<Widget>[
                    SizedBox(height: 6.h),
                    Text.rich(
                      TextSpan(
                        text: 'Sold by ',
                        style: TextStyle(fontSize: 12.sp, color: _muted),
                        children: <InlineSpan>[
                          TextSpan(
                            text: seller,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 12.h),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10.w,
                    children: <Widget>[
                      Text(
                        _inr(price),
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      if (p.isOnSale)
                        Text(
                          _inr(mrp),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: _muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      if (off > 0)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9F5E6),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            '$off% OFF',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: _green,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _facts(p),
                  if (exchange.eligible) ...<Widget>[
                    SizedBox(height: 14.h),
                    ProductExchangeCard(
                      key: ValueKey(p.id),
                      product: p,
                      offer: exchange,
                      onCheckValue: widget.onExchange,
                    ),
                  ],
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _count(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  /// Warranty / delivery / replacement strip — only the facts the backend really has.
  Widget _facts(ProductEntity p) {
    final List<(IconData, String, String)> items =
        <(IconData, String, String)>[];
    String? warranty;
    for (final Map<String, dynamic> a
        in p.attributes ?? <Map<String, dynamic>>[]) {
      final String label = '${a['label'] ?? a['name'] ?? ''}'.toLowerCase();
      if (label.contains('warranty')) warranty = '${a['value'] ?? ''}';
    }
    if (warranty != null && warranty.isNotEmpty) {
      items
          .add((Icons.verified_user_outlined, 'Brand Warranty', '($warranty)'));
    }
    if (p.hasDeliveryTime) {
      items.add(
        (
          Icons.local_shipping_outlined,
          'Free Delivery',
          '(${p.displayDeliveryMinutes} mins)'
        ),
      );
    }
    final RegExpMatch? days = RegExp(r'(\d+)').firstMatch(p.returnPolicy);
    if (days != null) {
      items.add(
        (Icons.autorenew_rounded, '${days.group(1)} Days', 'Replacement'),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _line),
      ),
      child: Wrap(
        runSpacing: 10.h,
        children: <Widget>[
          for (final (IconData, String, String) it in items)
            FractionallySizedBox(
              widthFactor: 0.5,
              child: Row(
                children: <Widget>[
                  Icon(it.$1, color: _ink, size: 24.sp),
                  SizedBox(width: 10.w),
                  Flexible(
                    child: Text(
                      '${it.$2}\n${it.$3}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: _muted,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


}

/// Add to Cart (outlined) + Buy Now (filled) — design bottom bar.
///
/// Each button shows bouncing dots while its (possibly async) action runs, so
/// a tap always gives visible feedback and can't be double-fired.
class PdpBottomBar extends StatefulWidget {
  const PdpBottomBar({
    required this.inStock,
    required this.onAdd,
    required this.onBuy,
    super.key,
  });
  final bool inStock;
  final VoidCallback onAdd;
  final VoidCallback onBuy;

  @override
  State<PdpBottomBar> createState() => _PdpBottomBarState();
}

class _PdpBottomBarState extends State<PdpBottomBar> {
  String? _busy; // 'add' | 'buy'

  Future<void> _run(String key, VoidCallback action) async {
    if (_busy != null) {
      return;
    }
    setState(() => _busy = key);
    try {
      final dynamic result = (action as dynamic)();
      await Future.wait<void>(<Future<void>>[
        if (result is Future) result.then<void>((_) {}),
        // Keep the feedback visible long enough to be noticed.
        Future<void>.delayed(const Duration(milliseconds: 700)),
      ]);
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool idle = _busy == null;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        10.h,
        16.w,
        MediaQuery.of(context).padding.bottom + 10.h,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SizedBox(
              height: 50.h,
              child: OutlinedButton(
                onPressed: widget.inStock && idle
                    ? () => _run('add', widget.onAdd)
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandNavy,
                  side:
                      const BorderSide(color: AppColors.brandNavy, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: _busy == 'add'
                    ? const DealkerBounceDots(color: AppColors.brandNavy)
                    : Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: SizedBox(
              height: 50.h,
              child: ElevatedButton(
                onPressed: widget.inStock && idle
                    ? () => _run('buy', widget.onBuy)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandNavy,
                  disabledBackgroundColor:
                      AppColors.brandNavy.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: _busy == 'buy'
                    ? const DealkerBounceDots(color: Colors.white)
                    : Text(
                        widget.inStock ? 'Buy Now' : 'Out of stock',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
