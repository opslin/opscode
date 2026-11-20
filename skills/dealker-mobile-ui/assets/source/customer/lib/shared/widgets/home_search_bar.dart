import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/theme/remote_theme_provider.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

import 'package:dealker_app/core/theme/remote_theme_model.dart';

const List<String> _fallbackHints = <String>['products'];

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({
    required this.onSearchTap,
    this.onSellTap,
    this.animateHints = true,
    this.searchTheme,
    this.outerPadding,
    super.key,
  });

  final VoidCallback onSearchTap;
  final VoidCallback? onSellTap;
  final bool animateHints;
  final SearchZoneTheme? searchTheme;
  final EdgeInsetsGeometry? outerPadding;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  int _hintIndex = 0;
  Timer? _hintTimer;

  // Hints come from the selected store's theme (`searchZone.searchHints`).
  List<String> get _resolvedSearchHints {
    final List<String>? hints = widget.searchTheme?.searchHints;
    return (hints == null || hints.isEmpty) ? _fallbackHints : hints;
  }

  @override
  void initState() {
    super.initState();
    _syncHintRotation();
  }

  @override
  void didUpdateWidget(covariant HomeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateHints != widget.animateHints) {
      _syncHintRotation();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _syncHintRotation() {
    _hintTimer?.cancel();
    final searchHints = _resolvedSearchHints;
    if (_hintIndex >= searchHints.length) {
      _hintIndex = 0;
    }
    if (!widget.animateHints) {
      _hintTimer = null;
      return;
    }
    if (searchHints.length <= 1) {
      return;
    }

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) {
        return;
      }
      final hints = _resolvedSearchHints;
      if (hints.isEmpty) {
        return;
      }
      setState(() {
        _hintIndex = (_hintIndex + 1) % hints.length;
      });
    });
  }

  static const double _designWidth = 914;

  // Box sizes in design px (914 wide). Dashboard tells the admin to upload at
  // 4x these (668x336 and 960x336) so the image fits edge to edge, no crop.
  static const double _sellBoxW = 167;
  static const double _promoBoxW = 240;

  Widget _imageBox(String url, double w, double h, double k) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22 * k),
      child: SizedBox(
        width: w,
        height: h,
        child: AppImage(
          imageUrl: url,
          memCacheWidth: (w * 4).round().clamp(240, 1080),
          memCacheHeight: (h * 4).round().clamp(120, 360),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        final HomeLookTheme look = ref.watch(activeTabThemeProvider
            .select((RemoteTheme t) => t.sections.homeLook));
        return _buildRow(context, look);
      },
    );
  }

  Widget _buildRow(BuildContext context, HomeLookTheme look) {
    final double k = MediaQuery.sizeOf(context).width / _designWidth;
    final List<String> searchHints = _resolvedSearchHints;
    final String hint = searchHints[_hintIndex % searchHints.length];
    final String? promoUrl =
        ApiConstants.resolveMediaUrl(widget.searchTheme?.promoBoxImageUrl);
    final String? sellUrl =
        ApiConstants.resolveMediaUrl(widget.searchTheme?.sellBoxImageUrl);
    final double h = 84 * k;

    final Widget hintLabel = Align(
      alignment: Alignment.centerLeft,
      key: ValueKey<int>(_hintIndex),
      child: Text(
        'Search for \u201c$hint\u201d',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 27 * k,
          color: look.searchPillTextColor,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: 14 * k, bottom: 10 * k),
      child: SizedBox(
        height: h,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 22 * k),
          children: <Widget>[
            GestureDetector(
              onTap: widget.onSearchTap,
              child: Container(
                width: 458 * k,
                height: h,
                padding: EdgeInsets.symmetric(horizontal: 22 * k),
                decoration: BoxDecoration(
                  color: look.searchPillColor,
                  borderRadius: BorderRadius.circular(22 * k),
                  // Dark outline so the white pill never melts into the
                  // yellow (or white, once sticky) header behind it.
                  border: Border.all(
                    color: look.searchPillBorderColor,
                    width: 3.2 * k,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.search,
                      size: 44 * k,
                      color: const Color(0xFF111111),
                    ),
                    SizedBox(width: 20 * k),
                    Expanded(
                      child: widget.animateHints
                          ? AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              layoutBuilder:
                                  (Widget? current, List<Widget> previous) =>
                                      SizedBox.expand(
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: <Widget>[
                                    ...previous,
                                    if (current != null) current,
                                  ],
                                ),
                              ),
                              child: hintLabel,
                            )
                          : hintLabel,
                    ),
                  ],
                ),
              ),
            ),
            if (sellUrl != null) ...<Widget>[
              SizedBox(width: 16 * k),
              GestureDetector(
                onTap: widget.onSellTap,
                child: _imageBox(sellUrl, _sellBoxW * k, h, k),
              ),
            ],
            if (promoUrl != null) ...<Widget>[
              SizedBox(width: 10 * k),
              GestureDetector(
                onTap: widget.onSearchTap,
                child: _imageBox(promoUrl, _promoBoxW * k, h, k),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
