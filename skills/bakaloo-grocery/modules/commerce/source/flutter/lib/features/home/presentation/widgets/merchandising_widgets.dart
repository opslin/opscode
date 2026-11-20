part of 'merchandising_sections.dart';

double _horizontalSectionExtent(
  int index,
  int itemCount,
  double itemWidth,
  double separatorWidth,
) {
  if (itemCount <= 1 || index == itemCount - 1) {
    return itemWidth;
  }
  return itemWidth + separatorWidth;
}

class _ManifestCategoryRail extends StatelessWidget {
  const _ManifestCategoryRail({
    required this.items,
    required this.onCategory,
    required this.iconSize,
    required this.gap,
    required this.showLabels,
  });

  final List<_CategoryRailItem> items;
  final ValueChanged<String> onCategory;
  final double iconSize;
  final double gap;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final double tileWidth = (iconSize + 18).clamp(82, 120).toDouble();
    final double boxRadius = (iconSize * 0.34).clamp(16, 26).toDouble();
    final double artworkRadius = (boxRadius - 2).clamp(14, 24).toDouble();
    final double railHeight = showLabels ? iconSize + 40 : iconSize + 12;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 2.h),
      child: SizedBox(
        height: railHeight.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemExtentBuilder: (int index, _) =>
              _horizontalSectionExtent(index, items.length, tileWidth.w, gap.w),
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];
            return Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: item.categoryId == null
                    ? null
                    : () => onCategory(item.categoryId!),
                child: SizedBox(
                  width: tileWidth.w,
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: iconSize.w,
                        height: iconSize.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(boxRadius.r),
                          border: Border.all(
                            color: const Color(0xFFF0F0F0),
                            width: 1,
                          ),
                          // PHASE 3D: Replace blurred shadow with a slightly
                          // stronger border. The category icon tiles are
                          // static — no need for blur rasterisation on each
                          // visible tile.
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 0,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(artworkRadius.r),
                          child: switch ((item.imageUrl, item.category)) {
                            (final image?, _) => AppImage(
                              imageUrl: image,
                              memCacheWidth: 160,
                              memCacheHeight: 160,
                            ),
                            (_, final category?) => CategoryArtwork(
                              category: category,
                            ),
                            _ => const Icon(
                              Icons.category_outlined,
                              color: AppColors.orderViolet,
                            ),
                          },
                        ),
                      ),
                      if (showLabels) ...<Widget>[
                        Gap(8.h),
                        Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: const Color(0xFF131313),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ManifestProductGridSection extends StatelessWidget {
  const _ManifestProductGridSection({
    required this.title,
    required this.products,
    required this.onProduct,
    required this.columns,
    this.variant = ProductCardVariant.quickCommerceCompact,
  });

  final String title;
  final List<ProductEntity> products;
  final ValueChanged<ProductEntity> onProduct;
  final int columns;
  final ProductCardVariant variant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
          child: _ManifestSectionHeader(title: title),
        ),
        Gap(10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final gap = 10.w;
              final minItemWidth = 104.w;
              final maxColumnsForWidth =
                  ((constraints.maxWidth + gap) / (minItemWidth + gap))
                      .floor()
                      .clamp(2, columns);
              final effectiveColumns = maxColumnsForWidth;
              final itemWidth =
                  (constraints.maxWidth - (gap * (effectiveColumns - 1))) /
                  effectiveColumns;
              final cardWidth = itemWidth / ScreenUtil().scaleWidth;

              return Wrap(
                spacing: gap,
                runSpacing: 12.h,
                children: products
                    .map(
                      (ProductEntity product) => SizedBox(
                        width: itemWidth,
                        child: ProductCard(
                          product: product,
                          width: cardWidth,
                          style: ProductCardStyle.grid,
                          variant: variant,
                          showWishlist: true,
                          onTap: () => onProduct(product),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ManifestHorizontalProductSection extends StatelessWidget {
  const _ManifestHorizontalProductSection({
    required this.title,
    required this.products,
    required this.onProduct,
    this.accentColor,
    this.variant = ProductCardVariant.quickCommerceCompact,
  });

  final String title;
  final List<ProductEntity> products;
  final ValueChanged<ProductEntity> onProduct;
  final Color? accentColor;
  final ProductCardVariant variant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
          child: _ManifestSectionHeader(title: title, accentColor: accentColor),
        ),
        Gap(10.h),
        SizedBox(
          height: 246.h,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            itemExtentBuilder: (int index, _) =>
                _horizontalSectionExtent(index, products.length, 132.w, 10.w),
            itemBuilder: (BuildContext context, int index) {
              final product = products[index];
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 132.w,
                  child: ProductCard(
                    product: product,
                    width: 132,
                    style: ProductCardStyle.scroll,
                    variant: variant,
                    showWishlist: true,
                    onTap: () => onProduct(product),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ManifestSectionHeader extends StatelessWidget {
  const _ManifestSectionHeader({required this.title, this.accentColor});

  final String title;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    if (accentColor == null) {
      return Text(
        title,
        style: AppTextStyles.h2.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );
    }

    final words = title.split(' ');
    if (words.length < 2) {
      return Text(
        title,
        style: AppTextStyles.h2.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: accentColor,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: AppTextStyles.h2.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        children: <InlineSpan>[
          TextSpan(text: '${words.sublist(0, words.length - 1).join(' ')} '),
          TextSpan(
            text: words.last,
            style: TextStyle(color: accentColor, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ManifestPromoCarousel extends StatefulWidget {
  const _ManifestPromoCarousel({
    required this.items,
    required this.borderRadius,
    required this.aspectRatio,
    required this.autoScroll,
    required this.autoScrollSpeedMs,
  });

  final List<_PromoItem> items;
  final double borderRadius;
  final double aspectRatio;
  final bool autoScroll;
  final int autoScrollSpeedMs;

  @override
  State<_ManifestPromoCarousel> createState() => _ManifestPromoCarouselState();
}

class _ManifestPromoCarouselState extends State<_ManifestPromoCarousel> {
  late final PageController _controller;
  Timer? _timer;
  // PHASE 4D: Replace local _page int (setState per tick) with ValueNotifier.
  // Only the _PromoPageDots widget rebuilds when the page changes — the
  // PageView and its card items are untouched.
  late final ValueNotifier<int> _pageNotifier;

  @override
  void initState() {
    super.initState();
    _pageNotifier = ValueNotifier<int>(0);
    _controller = PageController(viewportFraction: 0.92);
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _ManifestPromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length ||
        oldWidget.autoScroll != widget.autoScroll ||
        oldWidget.autoScrollSpeedMs != widget.autoScrollSpeedMs) {
      _timer?.cancel();
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (!widget.autoScroll || widget.items.length <= 1) {
      return;
    }
    _timer = Timer.periodic(
      Duration(milliseconds: widget.autoScrollSpeedMs.clamp(1500, 10000)),
      (_) {
        if (!mounted || !_controller.hasClients) {
          return;
        }
        final next = (_pageNotifier.value + 1) % widget.items.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height:
              ((MediaQuery.sizeOf(context).width * .92) / widget.aspectRatio)
                  .clamp(96.h, 360.h),
          child: PageView.builder(
            controller: _controller,
            padEnds: true,
            itemCount: widget.items.length,
            onPageChanged: (int value) {
              // PHASE 4D: ValueNotifier update instead of setState — only
              // _PromoPageDots rebuilds, not the full carousel Column.
              _pageNotifier.value = value;
            },
            itemBuilder: (BuildContext context, int index) {
              final item = widget.items[index];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius.r),
                  child: AppImage(
                    imageUrl: item.imageUrl,
                    memCacheWidth: 960,
                    memCacheHeight: 620,
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.items.length > 1) ...<Widget>[
          Gap(6.h),
          // PHASE 4D: Isolated dots widget — only this rebuilds on page change.
          _PromoPageDots(
            count: widget.items.length,
            pageNotifier: _pageNotifier,
          ),
        ],
      ],
    );
  }
}

/// Isolated page indicator for _ManifestPromoCarousel.
/// Listens to the ValueNotifier and rebuilds only the dots row.
class _PromoPageDots extends StatelessWidget {
  const _PromoPageDots({required this.count, required this.pageNotifier});

  final int count;
  final ValueNotifier<int> pageNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: pageNotifier,
      builder: (BuildContext context, int page, Widget? _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(
            count,
            (int index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: index == page ? 16.w : 6.w,
              height: 6.h,
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              decoration: BoxDecoration(
                color: index == page
                    ? AppColors.warmOrangeDark
                    : const Color(0xFFD5D5D5),
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ManifestBankOffersRow extends StatelessWidget {
  const _ManifestBankOffersRow({required this.items});

  final List<_PromoItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 6.h, 0, 2.h),
      child: SizedBox(
        height: 74.h,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemExtentBuilder: (int index, _) =>
              _horizontalSectionExtent(index, items.length, 336.w, 14.w),
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];
            return Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: SizedBox(
                    width: 336.w,
                    height: 74.h,
                    child: AppImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      memCacheWidth: 1440,
                      memCacheHeight: 317,
                      filterQuality: FilterQuality.high,
                      placeholder: const ColoredBox(
                        color: Color(0xFFF2F8FF),
                        child: SizedBox.expand(),
                      ),
                      errorWidget: const ColoredBox(
                        color: Color(0xFFF2F8FF),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PromoItem {
  const _PromoItem({required this.imageUrl});

  final String imageUrl;
}

class _CategoryRailItem {
  const _CategoryRailItem({required this.label, this.category, this.imageUrl});

  final String label;
  final DemoCategory? category;
  final String? imageUrl;
  String? get categoryId => category?.id;
}
