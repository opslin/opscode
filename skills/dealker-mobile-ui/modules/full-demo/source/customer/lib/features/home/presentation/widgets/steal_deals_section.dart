import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/features/products/data/models/product_model.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Defaults of the `steal_deals` section; every key is editable in the
/// dashboard theme builder (section config).
const Map<String, dynamic> kStealDealsDefaults = <String, dynamic>{
  'title': 'Steal Deals',
  'subtitle': 'Add Any 10 Items',
  'all_label': 'ALL',
  'empty_text': 'No deals here yet',
  'bg_color': '#FFFFFF',
  'accent_color': '#E8175D',
  'accent_soft_color': '#FDE9F0',
  'text_color': '#111111',
  'muted_color': '#6F6F6F',
  'title_image_url': '',
  'see_all_label': 'See All',
};

class _StealProduct {
  _StealProduct(this.product, this.categoryIds);
  final ProductEntity product;
  final List<String> categoryIds;
}

class _StealChip {
  const _StealChip(this.label, this.imageUrl, this.categoryId);
  final String label;
  final String imageUrl;
  final String categoryId;
}

class _StealTab {
  const _StealTab({
    required this.label,
    required this.subLabel,
    required this.iconUrl,
    required this.chips,
    required this.products,
  });
  final String label;
  final String subLabel;
  final String iconUrl;
  final List<_StealChip> chips;
  final List<_StealProduct> products;
}

List<_StealTab> _parseTabs(Map<String, dynamic> config) {
  final Object? raw = config['tabs'];
  if (raw is! List) return const <_StealTab>[];
  final List<_StealTab> out = <_StealTab>[];
  for (final Object? t in raw) {
    if (t is! Map) continue;
    final Map<String, dynamic> tab = Map<String, dynamic>.from(t);
    final List<_StealChip> chips = <_StealChip>[];
    final Object? rawChips = tab['chips'];
    if (rawChips is List) {
      for (final Object? c in rawChips) {
        if (c is! Map) continue;
        final String id = '${c['category_id'] ?? ''}';
        final String label = '${c['label'] ?? ''}'.trim();
        if (id.isEmpty || label.isEmpty) continue;
        chips.add(_StealChip(label, '${c['image_url'] ?? ''}', id));
      }
    }
    final List<_StealProduct> products = <_StealProduct>[];
    final Object? rawProducts = tab['products'];
    if (rawProducts is List) {
      for (final Object? p in rawProducts) {
        if (p is! Map) continue;
        try {
          final Map<String, dynamic> json = Map<String, dynamic>.from(p);
          final Object? ids = json['deal_category_ids'];
          products.add(
            _StealProduct(
              ProductModel.fromJson(json).toEntity(),
              ids is List
                  ? ids.map((Object? e) => '$e').toList()
                  : const <String>[],
            ),
          );
        } catch (_) {
          // One unparseable product must not blank the tab.
        }
      }
    }
    final String label = '${tab['label'] ?? ''}'.trim();
    if (label.isEmpty) continue;
    out.add(
      _StealTab(
        label: label,
        subLabel: '${tab['sub_label'] ?? ''}'.trim(),
        iconUrl: '${tab['icon_url'] ?? ''}'.trim(),
        chips: chips,
        products: products,
      ),
    );
  }
  return out;
}

/// "Steal Deals": price tabs (Trending / ₹99 Store …) → category chips →
/// horizontally scrolling product rail with a `+` button on each photo.
class StealDealsSection extends StatefulWidget {
  const StealDealsSection({required this.config, super.key});

  final Map<String, dynamic> config;

  @override
  State<StealDealsSection> createState() => _StealDealsSectionState();
}

class _StealDealsSectionState extends State<StealDealsSection> {
  int _tab = 0;
  int _chip = -1; // -1 = ALL

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> cfg = widget.config;
    final List<_StealTab> tabs = _parseTabs(cfg);
    if (tabs.isEmpty) return const SizedBox.shrink();
    final int tabIndex = _tab.clamp(0, tabs.length - 1);
    final _StealTab tab = tabs[tabIndex];
    final int chipIndex = _chip < tab.chips.length ? _chip : -1;

    final Color bg = colorFrom(cfg, 'bg_color', Colors.white);
    final Color accent = colorFrom(
      cfg,
      'accent_color',
      const Color(0xFFE8175D),
    );
    final Color soft = colorFrom(
      cfg,
      'accent_soft_color',
      const Color(0xFFFDE9F0),
    );
    final Color text = colorFrom(cfg, 'text_color', const Color(0xFF111111));
    final Color muted = colorFrom(cfg, 'muted_color', const Color(0xFF6F6F6F));

    final List<_StealProduct> shown = chipIndex < 0
        ? tab.products
        : tab.products
            .where(
              (_StealProduct p) =>
                  p.categoryIds.contains(tab.chips[chipIndex].categoryId) ||
                  p.product.categoryId == tab.chips[chipIndex].categoryId,
            )
            .toList(growable: false);

    final String? seeAllCategory = chipIndex >= 0
        ? tab.chips[chipIndex].categoryId
        : (tab.chips.isEmpty ? null : tab.chips.first.categoryId);
    final String title = stringFrom(cfg, 'title', 'Steal Deals');
    final String subtitle = stringFrom(cfg, 'subtitle', '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TabbedSectionHeader(
            title: title,
            titleImageUrl: stringFrom(cfg, 'title_image_url', ''),
            subtitle: subtitle,
            titleColor: text,
            subtitleColor: muted,
          ),
          const SizedBox(height: 14),
          _TabStrip(
            tabs: tabs,
            selected: tabIndex,
            accent: accent,
            soft: soft,
            text: text,
            muted: muted,
            onSelect: (int i) => setState(() {
              _tab = i;
              _chip = -1;
            }),
          ),
          const SizedBox(height: 12),
          _ChipRow(
            allLabel: stringFrom(cfg, 'all_label', 'ALL'),
            chips: tab.chips,
            selected: chipIndex,
            accent: accent,
            soft: soft,
            text: text,
            onSelect: (int i) => setState(() => _chip = i),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
              child: Center(
                child: Text(
                  stringFrom(cfg, 'empty_text', 'No deals here yet'),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
            )
          else
            DealerProductRail(
              key: ValueKey<String>('rail-$tabIndex-$chipIndex'),
              products: shown
                  .map((_StealProduct p) => p.product)
                  .toList(growable: false),
              seeAllLabel: stringFrom(cfg, 'see_all_label', 'See All'),
              seeAllRoute: seeAllCategory == null
                  ? null
                  : '/categories/$seeAllCategory/products',
            ),
        ],
      ),
    );
  }
}

// ── Tab strip ───────────────────────────────────────────────────────────────

const double _kTabW = 92;
const double _kTabH = 60;
const double _kTabLead = 14;

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.selected,
    required this.accent,
    required this.soft,
    required this.text,
    required this.muted,
    required this.onSelect,
  });

  final List<_StealTab> tabs;
  final int selected;
  final Color accent;
  final Color soft;
  final Color text;
  final Color muted;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double contentW = _kTabLead * 2 + tabs.length * _kTabW;
        final double w = contentW < box.maxWidth ? box.maxWidth : contentW;
        return SizedBox(
          height: _kTabH,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: w,
              height: _kTabH,
              child: CustomPaint(
                painter: TabStripPainter(
                  left: _kTabLead + selected * _kTabW,
                  width: _kTabW,
                  accent: accent,
                  soft: soft,
                ),
                child: Stack(
                  children: <Widget>[
                    for (int i = 0; i < tabs.length; i++) ...<Widget>[
                      Positioned(
                        left: _kTabLead + i * _kTabW,
                        top: 0,
                        width: _kTabW,
                        height: _kTabH,
                        child: _TabCell(
                          tab: tabs[i],
                          active: i == selected,
                          accent: accent,
                          text: text,
                          muted: muted,
                          onTap: () => onSelect(i),
                        ),
                      ),
                      // Thin divider between two idle tabs.
                      if (i < tabs.length - 1 &&
                          i != selected &&
                          i + 1 != selected)
                        Positioned(
                          left: _kTabLead + (i + 1) * _kTabW - 0.5,
                          top: 14,
                          height: _kTabH - 28,
                          width: 1,
                          child: ColoredBox(
                            color: muted.withValues(alpha: 0.25),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.tab,
    required this.active,
    required this.accent,
    required this.text,
    required this.muted,
    required this.onTap,
  });

  final _StealTab tab;
  final bool active;
  final Color accent;
  final Color text;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool iconTab = tab.iconUrl.isNotEmpty || tab.subLabel.isEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: iconTab
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: tab.iconUrl.isEmpty
                        ? Icon(
                            PhosphorIconsFill.fire,
                            size: 26,
                            color: active ? accent : muted,
                          )
                        : AppImage(
                            imageUrl: tab.iconUrl,
                            memCacheWidth: 120,
                            memCacheHeight: 120,
                            fit: BoxFit.contain,
                            placeholder: const SizedBox.shrink(),
                            errorWidget: const SizedBox.shrink(),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: active ? accent : text,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: active ? accent : text,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tab.subLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? accent : muted,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Category chips ──────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.allLabel,
    required this.chips,
    required this.selected,
    required this.accent,
    required this.soft,
    required this.text,
    required this.onSelect,
  });

  final String allLabel;
  final List<_StealChip> chips;
  final int selected;
  final Color accent;
  final Color soft;
  final Color text;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const double h = 40;
    final BorderRadius br = BorderRadius.circular(13);
    Widget shell({
      required bool active,
      required VoidCallback onTap,
      required Widget child,
    }) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: h,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: active ? soft : Colors.white,
              borderRadius: br,
              border: Border.all(
                color: active ? accent : const Color(0xFFE2E2E2),
                width: active ? 1.4 : 1,
              ),
            ),
            child: child,
          ),
        );

    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (BuildContext context, int i) {
          if (i == 0) {
            return shell(
              active: selected < 0,
              onTap: () => onSelect(-1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      PhosphorIconsRegular.squaresFour,
                      size: 22,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      allLabel,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final _StealChip chip = chips[i - 1];
          return shell(
            active: selected == i - 1,
            onTap: () => onSelect(i - 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: chip.imageUrl.isEmpty
                        ? ColoredBox(color: soft)
                        : AppImage(
                            imageUrl: chip.imageUrl,
                            memCacheWidth: 120,
                            memCacheHeight: 120,
                            fit: BoxFit.cover,
                            placeholder: ColoredBox(color: soft),
                            errorWidget: ColoredBox(color: soft),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: Text(
                    chip.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: text,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}
