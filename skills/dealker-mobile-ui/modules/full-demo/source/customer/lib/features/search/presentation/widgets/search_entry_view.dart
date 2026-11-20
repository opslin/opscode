import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/search_tokens.dart';
import 'package:dealker_app/features/categories/domain/entities/category_entity.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

const String _font = 'PlusJakartaSans';

/// Section title with an optional blue action on the right ("Clear all", "View all").
class SearchSectionHeading extends StatelessWidget {
  const SearchSectionHeading({
    required this.title,
    this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: SearchTokens.ink,
              height: 1.2,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              child: Text(
                action!,
                style: const TextStyle(
                  fontFamily: _font,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: SearchTokens.accent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The page before anything is typed: recent searches, popular right now and
/// browse by category — all from the customer's history and the live catalogue.
class SearchEntryView extends StatelessWidget {
  const SearchEntryView({
    required this.recent,
    required this.popular,
    required this.categories,
    required this.onPick,
    required this.onFill,
    required this.onRemoveRecent,
    required this.onClearRecent,
    required this.onCategory,
    required this.onAllCategories,
    super.key,
  });

  final List<String> recent;
  final List<String> popular;
  final List<CategoryEntity> categories;

  /// Run this search now.
  final ValueChanged<String> onPick;

  /// Put this text in the field to keep editing it (the ↖ arrow).
  final ValueChanged<String> onFill;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;
  final ValueChanged<CategoryEntity> onCategory;
  final VoidCallback onAllCategories;

  @override
  Widget build(BuildContext context) {
    final List<String> shownRecent = recent.take(6).toList();
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: <Widget>[
        if (shownRecent.isNotEmpty) ...<Widget>[
          SearchSectionHeading(
            title: 'Recent searches',
            action: 'Clear all',
            onAction: onClearRecent,
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < shownRecent.length; i++)
            _SuggestionRow(
              icon: PhosphorIconsRegular.clockCounterClockwise,
              text: shownRecent[i],
              showDivider: i != shownRecent.length - 1,
              onTap: () => onPick(shownRecent[i]),
              onFill: () => onFill(shownRecent[i]),
              onLongPress: () => onRemoveRecent(shownRecent[i]),
            ),
          const SizedBox(height: 22),
        ],
        if (popular.isNotEmpty) ...<Widget>[
          const SearchSectionHeading(title: 'Popular right now'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (int i = 0; i < popular.length; i++)
                SearchChip(
                  label: popular[i],
                  highlighted: i == 0,
                  onTap: () => onPick(popular[i]),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (categories.isNotEmpty) ...<Widget>[
          SearchSectionHeading(
            title: 'Browse by category',
            action: 'View all',
            onAction: onAllCategories,
          ),
          const SizedBox(height: 14),
          _CategoryGrid(categories: categories, onTap: onCategory),
        ],
      ],
    );
  }
}

/// A rounded pill: the first "popular" one is highlighted blue in the design.
class SearchChip extends StatelessWidget {
  const SearchChip({
    required this.label,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: highlighted ? SearchTokens.accentSoft : SearchTokens.chipBg,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: highlighted ? SearchTokens.accentBorder : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 14,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                  color: highlighted ? SearchTokens.accent : SearchTokens.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of recent / suggested text: [icon] text ........ [↖]
class SearchSuggestionRow extends StatelessWidget {
  const SearchSuggestionRow({
    required this.text,
    required this.onTap,
    required this.onFill,
    this.typed = '',
    this.showDivider = true,
    super.key,
  });

  final String text;

  /// The part the customer already typed (shown lighter, the rest bold).
  final String typed;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    return _SuggestionRow(
      icon: PhosphorIconsRegular.magnifyingGlass,
      text: text,
      typed: typed,
      showDivider: showDivider,
      onTap: onTap,
      onFill: onFill,
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.icon,
    required this.text,
    required this.showDivider,
    required this.onTap,
    required this.onFill,
    this.typed = '',
    this.onLongPress,
  });

  final PhosphorIconData icon;
  final String text;
  final String typed;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onFill;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final String lower = text.toLowerCase();
    final String t = typed.toLowerCase().trim();
    final bool hasPrefix = t.isNotEmpty && lower.startsWith(t);
    const TextStyle base = TextStyle(
      fontFamily: _font,
      fontSize: 15,
      color: SearchTokens.ink,
      height: 1.25,
    );
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: SearchTokens.divider),
                )
              : null,
        ),
        child: Row(
          children: <Widget>[
            PhosphorIcon(icon, size: 21, color: SearchTokens.grey),
            const SizedBox(width: 16),
            Expanded(
              child: hasPrefix
                  ? Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: text.substring(0, t.length),
                            style: base.copyWith(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(
                            text: text.substring(t.length),
                            style: base.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(fontWeight: FontWeight.w500),
                    ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onFill,
              child: const SizedBox(
                width: 40,
                height: 52,
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIconsRegular.arrowUpLeft,
                    size: 19,
                    color: SearchTokens.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, required this.onTap});

  final List<CategoryEntity> categories;
  final ValueChanged<CategoryEntity> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const int columns = 4;
        const double gap = 12;
        final double w = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: <Widget>[
            for (final CategoryEntity cat in categories)
              GestureDetector(
                onTap: () => onTap(cat),
                child: SizedBox(
                  width: w,
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: w,
                        height: w,
                        decoration: BoxDecoration(
                          color: SearchTokens.thumbBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (cat.imageUrl ?? '').isEmpty
                            ? const Center(
                                child: PhosphorIcon(
                                  PhosphorIconsRegular.squaresFour,
                                  size: 26,
                                  color: SearchTokens.grey,
                                ),
                              )
                            : AppImage(
                                imageUrl: cat.imageUrl!,
                                memCacheWidth: 240,
                                memCacheHeight: 240,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        cat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: SearchTokens.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
