// Bakaloo home_screen.dart carousel, section heading and product grid, adapted for local fixtures.
part of 'home_screen.dart';

/// Logical (design-unit) width for a card in the 3-column home grid.
///
/// The grid uses 16w horizontal padding on each side and two 10w gaps between
/// the three columns. [ProductCard] multiplies its `width` by `.w` internally,
/// so we return the design-unit width (raw px ÷ current width scale) to avoid
/// double-scaling.
double _threeColumnCardWidth(BuildContext context) {
  final double screenWidth = MediaQuery.sizeOf(context).width;
  final double horizontalPadding = 16.w * 2;
  final double totalGap = 10.w * 2;
  final double columnPx = (screenWidth - horizontalPadding - totalGap) / 3;
  final double scale = ScreenUtil().scaleWidth;
  return scale > 0 ? columnPx / scale : columnPx;
}

class _HeroPromoCarousel extends StatefulWidget {
  const _HeroPromoCarousel({required this.cards, required this.onCategory});

  final ValueChanged<String> onCategory;

  final List<DemoPromo> cards;

  @override
  State<_HeroPromoCarousel> createState() => _HeroPromoCarouselState();
}

class _HeroPromoCarouselState extends State<_HeroPromoCarousel> {
  static const int _loopSeedMultiplier = 1000;

  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _virtualPage = 0;

  @override
  void initState() {
    super.initState();
    _virtualPage = _startingVirtualPage(widget.cards.length);
    _pageController = PageController(
      viewportFraction: 0.88,
      initialPage: _virtualPage,
    );
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _HeroPromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards.length != widget.cards.length) {
      _autoPlayTimer?.cancel();
      _virtualPage = _startingVirtualPage(widget.cards.length);
      _jumpToVirtualPage(_virtualPage);
      _startAutoPlay();
    }
  }

  int _startingVirtualPage(int length) {
    if (length <= 1) {
      return 0;
    }
    return length * _loopSeedMultiplier;
  }

  int _effectiveIndex(int page) {
    final length = widget.cards.length;
    if (length == 0) {
      return 0;
    }
    final remainder = page % length;
    return remainder < 0 ? remainder + length : remainder;
  }

  void _jumpToVirtualPage(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.jumpToPage(page);
    });
  }

  void _startAutoPlay() {
    if (widget.cards.length <= 1) {
      return;
    }
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      final nextPage = _virtualPage + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: SizedBox(
            height: 198.h,
            child: PageView.builder(
              controller: _pageController,
              padEnds: true,
              clipBehavior: Clip.none,
              itemCount: widget.cards.length <= 1 ? widget.cards.length : null,
              onPageChanged: (value) {
                _virtualPage = value;
              },
              itemBuilder: (context, index) {
                final card = widget.cards[_effectiveIndex(index)];
                return Padding(
                  padding: EdgeInsets.fromLTRB(6.w, 4.h, 6.w, 6.h),
                  child: _HeroPromoCard(
                    card: card,
                    onTap: () => widget.onCategory(card.category),
                  ),
                );
              },
            ),
          ),
        ),
        Gap(2.h),
      ],
    );
  }
}

class _HeroPromoCard extends StatelessWidget {
  const _HeroPromoCard({required this.card, required this.onTap});

  final VoidCallback onTap;

  final DemoPromo card;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        // PHASE 3D: Reduced blur radius 12→4 and lower alpha (0x0C→0x09).
        // The card is inside a PageView with ClipRRect so heavy shadow blur
        // is invisible anyway; a tight 4px shadow preserves the lifted look.
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Semantics(
              label: card.label,
              image: true,
              child: SizedBox.expand(
                child: AppImage(
                  imageUrl: card.image,
                  fit: BoxFit.cover,
                  memCacheWidth: 900,
                  memCacheHeight: 550,
                  placeholder: const _FallbackHeroArt(),
                  errorWidget: const _FallbackHeroArt(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackHeroArt extends StatelessWidget {
  const _FallbackHeroArt();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3FBD7),
      child: Center(
        child: PhosphorIcon(
          PhosphorIcons.imageSquareDuotone,
          size: 40.sp,
          color: const Color(0xFF9BA56A),
        ),
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h2.copyWith(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Category Product Section — 3×2 grid ─────────────────

class _CategoryProductSection extends StatelessWidget {
  const _CategoryProductSection({
    required this.title,
    required this.onProductTap,
    required this.products,
  });

  final String title;
  final ValueChanged<ProductEntity> onProductTap;
  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: _HomeSectionHeader(title: title),
        ),
        Gap(10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: RepaintBoundary(
            child: _ThreeColumnProductGrid<ProductEntity>(
              items: products.take(6).toList(growable: false),
              itemBuilder: (product) => ProductCard(
                product: product,
                width: _threeColumnCardWidth(context),
                style: ProductCardStyle.grid,
                showWishlist: true,
                onTap: () => onProductTap(product),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreeColumnProductGrid<T> extends StatelessWidget {
  const _ThreeColumnProductGrid({
    required this.items,
    required this.itemBuilder,
  });

  final List<T> items;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <List<T>>[];
    for (var index = 0; index < items.length; index += 3) {
      final nextIndex = index + 3 < items.length ? index + 3 : items.length;
      rows.add(items.sublist(index, nextIndex));
    }

    return Column(
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          if (rowIndex > 0) Gap(12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var columnIndex = 0; columnIndex < 3; columnIndex++) ...[
                Expanded(
                  child: columnIndex < rows[rowIndex].length
                      ? RepaintBoundary(
                          child: itemBuilder(rows[rowIndex][columnIndex]),
                        )
                      : const SizedBox.shrink(),
                ),
                if (columnIndex < 2) Gap(10.w),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
