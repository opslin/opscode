import 'package:flutter/painting.dart';

/// Colours of the Dealkr product card (`DealkerProductCard`), measured from the
/// approved "boAt Rockerz 450" card design.
class ProductCardTokens {
  ProductCardTokens._();

  static const Color ink = Color(0xFF101114); // name, price, rating
  static const Color grey = Color(
    0xFF6C6E78,
  ); // variant, "Sold by", review count
  static const Color greyLight = Color(0xFF8C8E98); // struck-through MRP
  static const Color metaLabel = Color(
    0xFF55575F,
  ); // "Fast delivery", "Assured"
  static const Color divider = Color(0xFFD7D9E0);
  static const Color blue = Color(0xFF1B5BF2); // vendor name, Add to Cart
  static const Color buttonDisabled = Color(0xFFB9BDC9);
  static const Color green = Color(0xFF14A241); // % OFF text, Assured, In Stock
  static const Color greenBadge = Color(0xFF12B047); // NEW pill
  static const Color greenSoft = Color(0xFFE5F6EA); // % OFF pill background
  static const Color pink = Color(0xFFE5224F); // % OFF text
  static const Color pinkSoft = Color(0xFFFDE3E9); // % OFF pill background
  static const Color teal = Color(0xFF0E9F8E); // delivery truck
  static const Color star = Color(0xFFF7A81B);
  static const Color danger = Color(0xFFD93025); // out of stock
  static const Color heartOn = Color(0xFFD32F2F);
  static const Color heartOff = Color(0xFF2A2B33);
  static const Color heartBorder = Color(0xFFE3E5EB);
  static const Color shadow = Color(0xFF1B2540);
}
