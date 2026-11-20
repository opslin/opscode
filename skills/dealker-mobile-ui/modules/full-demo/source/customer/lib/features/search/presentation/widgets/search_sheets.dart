import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/search_tokens.dart';
import 'package:dealker_app/core/utils/extensions/double_extensions.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/search/domain/search_filters.dart';

const String _font = 'PlusJakartaSans';

/// Price bands under the slider — plain filter ranges, not data.
const List<PriceBand> kPriceBands = <PriceBand>[
  PriceBand('Under ₹20K', null, 20000),
  PriceBand('₹20K - ₹50K', 20000, 50000),
  PriceBand('₹50K - ₹1L', 50000, 100000),
  PriceBand('Above ₹1L', 100000, null),
];

Future<SearchFilters?> showSearchFilterSheet(
  BuildContext context, {
  required SearchFilters initial,
  required List<ProductEntity> products,
  required int totalOnServer,
}) {
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: SearchTokens.scrim,
    builder: (BuildContext ctx) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _FilterSheet(
        initial: initial,
        products: products,
        totalOnServer: totalOnServer,
      ),
    ),
  );
}

Future<SearchSort?> showSearchSortSheet(
  BuildContext context, {
  required SearchSort current,
}) {
  return showModalBottomSheet<SearchSort>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: SearchTokens.scrim,
    builder: (BuildContext ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _Handle(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sort by',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: SearchTokens.ink,
                    ),
                  ),
                ),
              ),
              for (final SearchSort s in SearchSort.values)
                InkWell(
                  onTap: () => Navigator.of(ctx).pop(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            s.label,
                            style: TextStyle(
                              fontFamily: _font,
                              fontSize: 15,
                              fontWeight: s == current
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: s == current
                                  ? SearchTokens.accent
                                  : SearchTokens.ink,
                            ),
                          ),
                        ),
                        if (s == current)
                          const PhosphorIcon(
                            PhosphorIconsBold.check,
                            size: 19,
                            color: SearchTokens.accent,
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    },
  );
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 9, bottom: 10),
      width: 42,
      height: 4.5,
      decoration: BoxDecoration(
        color: const Color(0xFFD3D6DE),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.products,
    required this.totalOnServer,
  });

  final SearchFilters initial;
  final List<ProductEntity> products;
  final int totalOnServer;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters _f = widget.initial;
  final TextEditingController _brandSearch = TextEditingController();
  bool _showAllBrands = false;

  late final List<BrandFacet> _brands = brandFacets(widget.products);
  late final double _lo = _priceBound(floor: true);
  late final double _hi = _priceBound(floor: false);

  double _priceBound({required bool floor}) {
    if (widget.products.isEmpty) return floor ? 0 : 1;
    final Iterable<double> prices =
        widget.products.map((ProductEntity p) => p.effectivePrice);
    final double v = floor ? prices.reduce(math.min) : prices.reduce(math.max);
    // Round to a neat step so the slider labels read ₹10,000 / ₹1,50,000.
    final double step = (_stepFor(prices.reduce(math.max))).toDouble();
    return floor
        ? (v / step).floor() * step
        : math.max((v / step).ceil() * step, step);
  }

  num _stepFor(double max) {
    if (max <= 1000) return 100;
    if (max <= 10000) return 500;
    if (max <= 100000) return 5000;
    return 10000;
  }

  @override
  void dispose() {
    _brandSearch.dispose();
    super.dispose();
  }

  int get _count => applySearch(
        widget.products,
        _f,
        SearchSort.relevance,
      ).length;

  RangeValues get _range => RangeValues(
        (_f.minPrice ?? _lo).clamp(_lo, _hi),
        (_f.maxPrice ?? _hi).clamp(_lo, _hi),
      );

  void _setRange(RangeValues v) {
    setState(() {
      _f = _f.copyWith(
        minPrice: v.start <= _lo ? null : v.start.roundToDouble(),
        maxPrice: v.end >= _hi ? null : v.end.roundToDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final String q = _brandSearch.text.trim().toLowerCase();
    final List<BrandFacet> matching = _brands
        .where((BrandFacet b) => q.isEmpty || b.name.toLowerCase().contains(q))
        .toList();
    final List<BrandFacet> shownBrands =
        (_showAllBrands || q.isNotEmpty) ? matching : matching.take(5).toList();
    final int count = _count;
    final bool priceSliderUseful = _hi > _lo;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          const Center(child: _Handle()),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 18, 6),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.x,
                    size: 24,
                    color: SearchTokens.ink,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Filters',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: SearchTokens.ink,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _f = const SearchFilters();
                    _brandSearch.clear();
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 10,
                    ),
                    child: Text(
                      'Clear all',
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _f.isDefault
                            ? SearchTokens.greyLight
                            : SearchTokens.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: SearchTokens.divider),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: <Widget>[
                if (_brands.isNotEmpty) ...<Widget>[
                  const _Title('Brand'),
                  const SizedBox(height: 12),
                  if (_brands.length > 5) ...<Widget>[
                    _BrandSearchField(
                      controller: _brandSearch,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 6),
                  ],
                  for (final BrandFacet b in shownBrands)
                    _BrandRow(
                      facet: b,
                      selected: _f.brands.any(
                        (String s) => s.toLowerCase() == b.name.toLowerCase(),
                      ),
                      onTap: () {
                        final Set<String> next = <String>{..._f.brands};
                        final String? existing = next
                            .where(
                              (String s) =>
                                  s.toLowerCase() == b.name.toLowerCase(),
                            )
                            .firstOrNull;
                        if (existing != null) {
                          next.remove(existing);
                        } else {
                          next.add(b.name);
                        }
                        setState(() => _f = _f.copyWith(brands: next));
                      },
                    ),
                  if (matching.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'No brand matches your search',
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 13,
                          color: SearchTokens.grey,
                        ),
                      ),
                    ),
                  if (q.isEmpty && matching.length > 5)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _showAllBrands = !_showAllBrands),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 2),
                        child: Row(
                          children: <Widget>[
                            Text(
                              _showAllBrands ? 'Show less' : 'Show more',
                              style: const TextStyle(
                                fontFamily: _font,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: SearchTokens.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            PhosphorIcon(
                              _showAllBrands
                                  ? PhosphorIconsBold.caretUp
                                  : PhosphorIconsBold.caretDown,
                              size: 14,
                              color: SearchTokens.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                ],
                if (priceSliderUseful) ...<Widget>[
                  const _Title('Price range'),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: SearchTokens.accent,
                      inactiveTrackColor: const Color(0xFFD8DCEB),
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 11,
                        elevation: 2,
                      ),
                      thumbColor: Colors.white,
                      overlayColor: SearchTokens.accent.withValues(alpha: 0.12),
                      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                    ),
                    child: RangeSlider(
                      values: _range,
                      min: _lo,
                      max: _hi,
                      onChanged: _setRange,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          (_f.minPrice ?? _lo).round().toInrCurrency,
                          style: _small,
                        ),
                        Text(
                          (_f.maxPrice ?? _hi).round().toInrCurrency,
                          style: _small,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ChipRow(
                    children: <Widget>[
                      for (final PriceBand band in kPriceBands)
                        if (_bandHasRoom(band))
                          _OptionChip(
                            label: band.label,
                            compact: true,
                            fontSize: 11.5,
                            selected: _f.minPrice == band.min &&
                                _f.maxPrice == band.max,
                            onTap: () {
                              final bool on = _f.minPrice == band.min &&
                                  _f.maxPrice == band.max;
                              setState(() {
                                _f = _f.copyWith(
                                  minPrice: on ? null : band.min,
                                  maxPrice: on ? null : band.max,
                                );
                              });
                            },
                          ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                const _Title('Ratings'),
                const SizedBox(height: 12),
                _ChipRow(
                  gap: 10,
                  children: <Widget>[
                    for (final double r in const <double>[4, 3, 2])
                      _OptionChip(
                        label: '${r.round()}',
                        star: true,
                        suffix: '& above',
                        compact: true,
                        selected: _f.minRating == r,
                        onTap: () => setState(
                          () => _f = _f.copyWith(
                            minRating: _f.minRating == r ? null : r,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const _Title('Availability'),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'In stock only',
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: SearchTokens.ink,
                        ),
                      ),
                    ),
                    Switch(
                      value: _f.inStockOnly,
                      activeTrackColor: SearchTokens.accent,
                      inactiveTrackColor: const Color(0xFFD8DCEB),
                      inactiveThumbColor: Colors.white,
                      trackOutlineColor: const WidgetStatePropertyAll<Color>(
                        Colors.transparent,
                      ),
                      onChanged: (bool v) =>
                          setState(() => _f = _f.copyWith(inStockOnly: v)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: SearchTokens.divider)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed:
                      count == 0 ? null : () => Navigator.of(context).pop(_f),
                  style: FilledButton.styleFrom(
                    backgroundColor: SearchTokens.accent,
                    disabledBackgroundColor: const Color(0xFFB9BDC9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    count == 0
                        ? 'No results'
                        : 'Show $count result${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A band is offered only when some loaded product falls inside it.
  bool _bandHasRoom(PriceBand b) {
    return widget.products.any((ProductEntity p) {
      final double v = p.effectivePrice;
      return (b.min == null || v >= b.min!) && (b.max == null || v <= b.max!);
    });
  }

  static const TextStyle _small = TextStyle(
    fontFamily: _font,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: SearchTokens.grey,
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: _font,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: SearchTokens.ink,
      ),
    );
  }
}

class _BrandSearchField extends StatelessWidget {
  const _BrandSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: SearchTokens.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          const PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 19,
            color: SearchTokens.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: SearchTokens.accent,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 14.5,
                color: SearchTokens.ink,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search brands',
                hintStyle: TextStyle(
                  fontFamily: _font,
                  fontSize: 14.5,
                  color: SearchTokens.greyLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.facet,
    required this.selected,
    required this.onTap,
  });

  final BrandFacet facet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 46,
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? SearchTokens.accent : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      selected ? SearchTokens.accent : const Color(0xFFB4B9C8),
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const PhosphorIcon(
                      PhosphorIconsBold.check,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: facet.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: SearchTokens.ink,
                      ),
                    ),
                    TextSpan(
                      text: '  (${facet.count})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: SearchTokens.grey,
                      ),
                    ),
                  ],
                  style: const TextStyle(fontFamily: _font, fontSize: 15),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chips sharing one line equally (the design keeps price bands / ratings in a row).
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children, this.gap = 8});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.star = false,
    this.suffix,
    this.compact = false,
    this.fontSize = 14,
  });

  final double fontSize;

  /// Fills the width it is given and shrinks its text to fit (used in a [_ChipRow]).
  final bool compact;

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool star;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? SearchTokens.accent : SearchTokens.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: compact ? 40 : 42,
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 14),
        alignment: compact ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected ? SearchTokens.accentSoft : Colors.white,
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          border: Border.all(
            color: selected ? SearchTokens.accent : SearchTokens.chipBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: fg,
                ),
              ),
              if (star) ...<Widget>[
                const SizedBox(width: 3),
                const PhosphorIcon(
                  PhosphorIconsFill.star,
                  size: 14,
                  color: SearchTokens.star,
                ),
              ],
              if (suffix != null) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  suffix!,
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? SearchTokens.accent : SearchTokens.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
