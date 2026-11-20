import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/features/home/presentation/widgets/tabbed_section_parts.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

/// Defaults of the `category_hub` section: text tabs; each tab has a row of
/// tile cards and a category grid. Everything is editable in the dashboard.
const Map<String, dynamic> kCategoryHubDefaults = <String, dynamic>{
  'bg_color': '#FFFFFF',
  'text_color': '#1B1740',
  'muted_color': '#6B7280',
  'indicator_color': '#1B1740',
  'tile_color': '#F4F4F6',
  'tile_border_color': '#DADAE6',
  'accent_color': '#0E7C66',
  'see_all_label': 'See All',
};

class _Tile {
  const _Tile(this.title, this.imageUrl, this.categoryId, this.query);
  final String title;
  final String imageUrl;
  final String categoryId;

  /// Used when there is no category: opens a search for this text.
  final String query;
}

class _Hub {
  const _Hub(this.label, this.tiles, this.gridTitle, this.grid);
  final String label;
  final List<_Tile> tiles;
  final String gridTitle;
  final List<_Tile> grid;
}

List<_Tile> _tiles(Object? raw, String titleKey) {
  if (raw is! List) return const <_Tile>[];
  final List<_Tile> out = <_Tile>[];
  for (final Object? t in raw) {
    if (t is! Map) continue;
    final String title = '${t[titleKey] ?? ''}'.trim();
    if (title.isEmpty) continue;
    out.add(
      _Tile(
        title,
        '${t['image_url'] ?? ''}',
        '${t['category_id'] ?? ''}',
        '${t['search_query'] ?? ''}'.trim(),
      ),
    );
  }
  return out;
}

List<_Hub> _parse(Map<String, dynamic> config) {
  final Object? raw = config['tabs'];
  if (raw is! List) return const <_Hub>[];
  final List<_Hub> out = <_Hub>[];
  for (final Object? t in raw) {
    if (t is! Map) continue;
    final String label = '${t['label'] ?? ''}'.trim();
    if (label.isEmpty) continue;
    out.add(
      _Hub(
        label,
        _tiles(t['tiles'], 'title'),
        '${t['grid_title'] ?? ''}'.trim(),
        _tiles(t['grid'], 'label'),
      ),
    );
  }
  return out;
}

void _open(BuildContext context, String categoryId, [String query = '']) {
  if (categoryId.isEmpty && query.isNotEmpty) {
    context.push('/search?q=${Uri.encodeQueryComponent(query)}');
    return;
  }
  context.push(
    categoryId.isEmpty ? '/categories' : '/categories/$categoryId/products',
  );
}

class CategoryHubSection extends StatefulWidget {
  const CategoryHubSection({required this.config, super.key});

  final Map<String, dynamic> config;

  @override
  State<CategoryHubSection> createState() => _CategoryHubSectionState();
}

class _CategoryHubSectionState extends State<CategoryHubSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> cfg = widget.config;
    final List<_Hub> hubs = _parse(cfg);
    if (hubs.isEmpty) return const SizedBox.shrink();
    final int index = _tab.clamp(0, hubs.length - 1);
    final _Hub hub = hubs[index];

    final Color bg = colorFrom(cfg, 'bg_color', Colors.white);
    final Color text = colorFrom(cfg, 'text_color', const Color(0xFF1B1740));
    final Color muted = colorFrom(cfg, 'muted_color', const Color(0xFF6B7280));
    final Color indicator = colorFrom(
      cfg,
      'indicator_color',
      const Color(0xFF1B1740),
    );
    final Color tile = colorFrom(cfg, 'tile_color', const Color(0xFFF4F4F6));
    final Color tileBorder = colorFrom(
      cfg,
      'tile_border_color',
      const Color(0xFFDADAE6),
    );
    final Color accent = colorFrom(
      cfg,
      'accent_color',
      const Color(0xFF0E7C66),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              physics: const BouncingScrollPhysics(),
              itemCount: hubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 22),
              itemBuilder: (BuildContext context, int i) {
                final bool on = i == index;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _tab = i),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      Center(
                        child: Text(
                          hubs[i].label,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: on ? FontWeight.w800 : FontWeight.w700,
                            color: on ? indicator : text,
                          ),
                        ),
                      ),
                      if (on)
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: indicator,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(height: 1.2, color: muted.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          if (hub.tiles.isNotEmpty)
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                physics: const BouncingScrollPhysics(),
                itemCount: hub.tiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int i) {
                  final _Tile t = hub.tiles[i];
                  return GestureDetector(
                    onTap: () => _open(context, t.categoryId, t.query),
                    child: Container(
                      width: 112,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tileBorder),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Colors.white, tile],
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: <Widget>[
                          if (t.imageUrl.isNotEmpty)
                            Positioned(
                              left: 6,
                              right: 6,
                              bottom: 4,
                              height: 70,
                              child: AppImage(
                                imageUrl: t.imageUrl,
                                memCacheWidth: 300,
                                memCacheHeight: 300,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                                placeholder: const SizedBox.shrink(),
                                errorWidget: const SizedBox.shrink(),
                              ),
                            ),
                          Positioned(
                            left: 9,
                            top: 8,
                            right: 30,
                            child: Text(
                              t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: text,
                                height: 1.2,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (hub.grid.isNotEmpty) ...<Widget>[
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      hub.gridTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                  ),
                  if (stringFrom(cfg, 'see_all_label', 'See All').isNotEmpty)
                    GestureDetector(
                      onTap: () => _open(context, ''),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              stringFrom(cfg, 'see_all_label', 'See All'),
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  const double gap = 10;
                  final double w = (box.maxWidth - gap * 3) / 4;
                  return Wrap(
                    spacing: gap,
                    runSpacing: 14,
                    children: <Widget>[
                      for (final _Tile g in hub.grid)
                        GestureDetector(
                          onTap: () => _open(context, g.categoryId, g.query),
                          child: SizedBox(
                            width: w,
                            child: Column(
                              children: <Widget>[
                                Container(
                                  width: w,
                                  height: w,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: tile,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: g.imageUrl.isEmpty
                                      ? null
                                      : AppImage(
                                          imageUrl: g.imageUrl,
                                          memCacheWidth: 300,
                                          memCacheHeight: 300,
                                          fit: BoxFit.contain,
                                          placeholder: const SizedBox.shrink(),
                                          errorWidget: const SizedBox.shrink(),
                                        ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  g.title,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: text,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
