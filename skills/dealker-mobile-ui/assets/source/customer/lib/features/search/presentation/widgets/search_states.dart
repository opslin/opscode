import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'package:dealker_app/core/theme/search_tokens.dart';
import 'package:dealker_app/features/search/presentation/widgets/search_entry_view.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';
import 'package:dealker_app/shared/widgets/dealker_product_grid.dart';

const String _font = 'PlusJakartaSans';

/// Card-shaped placeholders matching the results grid while it loads.
class SearchSkeletonGrid extends StatelessWidget {
  const SearchSkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const double gap = 12;
        const double side = 14;
        final int columns =
            productGridColumns(c.maxWidth - side * 2, isWeb: kIsWeb);
        final double w =
            (c.maxWidth - side * 2 - gap * (columns - 1)) / columns;
        final double h = DealkerProductCard.heightFor(w);
        return Shimmer.fromColors(
          baseColor: const Color(0xFFE9EBF2),
          highlightColor: const Color(0xFFF7F8FC),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(side, 14, side, 20),
            child: Wrap(
              spacing: gap,
              runSpacing: 14,
              children: <Widget>[
                for (int i = 0; i < columns * 3; i++)
                  _SkeletonCard(width: w, height: h),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double inner = width - 24;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: width * 0.78,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EBF2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: inner * 0.9,
            height: 12,
            color: const Color(0xFFE9EBF2),
          ),
          const SizedBox(height: 8),
          Container(
            width: inner * 0.55,
            height: 11,
            color: const Color(0xFFE9EBF2),
          ),
          const SizedBox(height: 12),
          Container(
            width: inner * 0.6,
            height: 16,
            color: const Color(0xFFE9EBF2),
          ),
          const Spacer(),
          Container(
            width: inner,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EBF2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }
}

/// "No results for “xyzabc”" + popular searches + Browse categories.
class SearchNoResultsView extends StatelessWidget {
  const SearchNoResultsView({
    required this.query,
    required this.popular,
    required this.onPick,
    required this.onBrowse,
    this.filtered = false,
    this.onClearFilters,
    super.key,
  });

  final String query;
  final List<String> popular;
  final ValueChanged<String> onPick;
  final VoidCallback onBrowse;

  /// Results exist for the query but the filters hide all of them.
  final bool filtered;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
      children: <Widget>[
        const Center(
          child: _IconBadge(icon: PhosphorIconsRegular.magnifyingGlass),
        ),
        const SizedBox(height: 22),
        Text(
          filtered
              ? 'No products match your filters'
              : 'No results for “$query”',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: SearchTokens.ink,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          filtered
              ? 'Try removing a filter to see more of “$query”.'
              : 'Check the spelling or try a more general term',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: SearchTokens.grey,
            height: 1.35,
          ),
        ),
        if (filtered && onClearFilters != null) ...<Widget>[
          const SizedBox(height: 26),
          _OutlineButton(label: 'Clear filters', onTap: onClearFilters!),
        ] else ...<Widget>[
          if (popular.isNotEmpty) ...<Widget>[
            const SizedBox(height: 30),
            const Text(
              'Popular searches',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: SearchTokens.ink,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String p in popular.take(6))
                  SearchChip(label: p, onTap: () => onPick(p)),
              ],
            ),
          ],
          const SizedBox(height: 28),
          _OutlineButton(label: 'Browse categories', onTap: onBrowse),
        ],
      ],
    );
  }
}

/// "Couldn't load results" / "You're offline" with a retry button.
class SearchErrorView extends StatelessWidget {
  const SearchErrorView({
    required this.offline,
    required this.onRetry,
    super.key,
  });

  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _IconBadge(
              icon: offline
                  ? PhosphorIconsRegular.wifiSlash
                  : PhosphorIconsRegular.cloudWarning,
            ),
            const SizedBox(height: 22),
            Text(
              offline ? 'You’re offline' : 'Couldn’t load results',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SearchTokens.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              offline
                  ? 'Check your internet connection and try again.'
                  : 'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SearchTokens.grey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: SearchTokens.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  offline ? 'Try again' : 'Retry',
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final PhosphorIconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: const BoxDecoration(
        color: SearchTokens.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: PhosphorIcon(icon, size: 44, color: SearchTokens.accent),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SearchTokens.accent, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: SearchTokens.accent,
          ),
        ),
      ),
    );
  }
}
