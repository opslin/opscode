import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/remote_theme_model.dart';

/// Colour set for one top-of-home store tab. The whole header (address row,
/// tab bar and search zone) cross-fades to the selected store's palette.
/// Palettes are assigned by the store's position, so they work for any
/// store list the backend returns.
///
/// Only four colours are chosen (dashboard-editable); the rest are derived
/// with the ratios measured from the reference video (2026-10-21).
class StoreTabPalette {
  const StoreTabPalette({
    required this.background,
    required this.tabFill,
    required this.tabEdge,
    required this.restTop,
    required this.restBottom,
    required this.baseLine,
    required this.onBackground,
    required this.onBackgroundMuted,
    required this.bloom,
  });

  /// Header band behind the tabs.
  final Color background;

  /// Raised (selected) tab body and the panel below it (search + categories).
  final Color tabFill;

  /// Outline of the selected tab (resting tab outlines use it faintly).
  final Color tabEdge;

  /// Resting tab glass, top and bottom of its vertical fade (opaque).
  final Color restTop;
  final Color restBottom;

  /// Thin line along the bottom of the tab bar.
  final Color baseLine;

  final Color onBackground;
  final Color onBackgroundMuted;

  /// Light at the top of the raised tab (transparent on light palettes).
  final Color bloom;

  bool get isDark => background.computeLuminance() < 0.35;

  /// Palette for the tab at [index] from the dashboard-editable colours
  /// (four palettes, repeating for further tabs).
  static StoreTabPalette fromLook(HomeLookTheme look, int index) {
    final int n = (index < 0 ? 0 : index) % 4;
    final List<Color> c = <List<Color>>[
      <Color>[
        look.storePalette1Background,
        look.storePalette1TabFill,
        look.storePalette1TabEdge,
        look.storePalette1Text,
      ],
      <Color>[
        look.storePalette2Background,
        look.storePalette2TabFill,
        look.storePalette2TabEdge,
        look.storePalette2Text,
      ],
      <Color>[
        look.storePalette3Background,
        look.storePalette3TabFill,
        look.storePalette3TabEdge,
        look.storePalette3Text,
      ],
      <Color>[
        look.storePalette4Background,
        look.storePalette4TabFill,
        look.storePalette4TabEdge,
        look.storePalette4Text,
      ],
    ][n];
    return derive(background: c[0], tabFill: c[1], tabEdge: c[2], text: c[3]);
  }

  static StoreTabPalette derive({
    required Color background,
    required Color tabFill,
    required Color tabEdge,
    required Color text,
  }) {
    final bool dark = background.computeLuminance() < 0.35;
    Color over(Color top, double a, Color base) =>
        Color.alphaBlend(top.withValues(alpha: a), base);
    return StoreTabPalette(
      background: background,
      tabFill: tabFill,
      tabEdge: tabEdge,
      // Dark: faint white glass that dims towards the bottom (#0A0115 ->
      // #180F23 / #0E051C). Light: a shade of the outline at the top that
      // clears to near-white at the bottom (#FEFCF8 -> #F3EFE9 / #FDF4ED).
      restTop: dark
          ? over(Colors.white, 0.065, background)
          : over(tabEdge, 0.05, background),
      restBottom: dark
          ? over(Colors.white, 0.02, background)
          : Color.lerp(tabFill, Colors.white, 0.4)!,
      baseLine: dark
          ? over(Colors.white, 0.17, background)
          : over(Colors.black, 0.12, background),
      onBackground: text,
      onBackgroundMuted: text.withValues(alpha: dark ? 0.7 : 0.75),
      bloom: dark ? tabEdge.withValues(alpha: 0.3) : Colors.transparent,
    );
  }

  static StoreTabPalette lerp(StoreTabPalette a, StoreTabPalette b, double t) =>
      StoreTabPalette(
        background: Color.lerp(a.background, b.background, t)!,
        tabFill: Color.lerp(a.tabFill, b.tabFill, t)!,
        tabEdge: Color.lerp(a.tabEdge, b.tabEdge, t)!,
        restTop: Color.lerp(a.restTop, b.restTop, t)!,
        restBottom: Color.lerp(a.restBottom, b.restBottom, t)!,
        baseLine: Color.lerp(a.baseLine, b.baseLine, t)!,
        onBackground: Color.lerp(a.onBackground, b.onBackground, t)!,
        onBackgroundMuted: Color.lerp(
          a.onBackgroundMuted,
          b.onBackgroundMuted,
          t,
        )!,
        bloom: Color.lerp(a.bloom, b.bloom, t)!,
      );
}

class StoreTabPaletteTween extends Tween<StoreTabPalette> {
  StoreTabPaletteTween({super.begin, super.end});

  @override
  StoreTabPalette lerp(double t) => StoreTabPalette.lerp(begin!, end!, t);
}
