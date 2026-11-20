import 'package:flutter/painting.dart';

import 'package:dealker_app/core/theme/product_card_tokens.dart';

/// Colours of the search screens (entry, suggestions, results, filter sheet),
/// measured from the approved search design. The accent is the same blue as the
/// Dealkr product card's Add button so the two never disagree.
class SearchTokens {
  SearchTokens._();

  static const Color canvas = Color(0xFFFFFFFF);
  static const Color accent = ProductCardTokens.blue;
  static const Color accentSoft = Color(
    0xFFEAF0FE,
  ); // selected chip / pill fill
  static const Color accentBorder = Color(0xFFC9D8FB);
  static const Color ink = ProductCardTokens.ink;
  static const Color grey = ProductCardTokens.grey;
  static const Color greyLight = Color(0xFF9A9CA8);
  static const Color divider = Color(0xFFECEEF3);
  static const Color chipBg = Color(0xFFF1F3F8);
  static const Color chipBorder = Color(0xFFE1E4EC);
  static const Color fieldBg = Color(0xFFFFFFFF);
  static const Color fieldBorder = Color(0xFFD5DBF2);
  static const Color thumbBg = Color(0xFFF5F6FA);
  static const Color resultsCanvas = Color(0xFFF6F7FB);
  static const Color star = ProductCardTokens.star;
  static const Color green = ProductCardTokens.green;
  static const Color greenSoft = ProductCardTokens.greenSoft;
  static const Color scrim = Color(0x8C101114);
}
