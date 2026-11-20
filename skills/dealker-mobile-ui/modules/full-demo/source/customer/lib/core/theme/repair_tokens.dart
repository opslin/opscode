import 'package:flutter/painting.dart';

/// Colours and sizes of the Repair Mobile journey, from the approved visual pack
/// (`Dealker_Repair_Mobile/DESIGN_SPEC.md`, 390 × 844).
class RT {
  RT._();

  static const Color yellow = Color(
    0xFFFFFFFF,
  ); // legacy name: status + app bar are white now
  static const Color blue = Color(
    0xFF001F5F,
  ); // Dealkr navy — buttons, links, active step
  static const Color indigo = Color(
    0xFF001F5F,
  ); // primary, selected, active step (Dealkr navy)
  static const Color ink = Color(0xFF0A1B4D); // headings, prices
  static const Color grey = Color(0xFF6B7390); // secondary
  static const Color muted = Color(0xFF8A93AB); // inactive, captions
  static const Color border = Color(0xFFE3E8F3); // hairlines, card stroke
  static const Color tint = Color(0xFFE8EEFB); // navy tint
  static const Color green = Color(0xFF15803D);
  static const Color greenTint = Color(0xFFDDF5E4);
  static const Color amber = Color(0xFF8A5A00);
  static const Color amberTint = Color(0xFFFFF0C2);
  static const Color red = Color(0xFFE5232E);
  static const Color redTint = Color(0xFFFDECEE);
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color field = Color(0xFFF4F5FA); // search / text fields
  static const Color star = Color(0xFFE0A800);
  static const Color gold = Color(0xFFFFC400);

  static const double gutter = 16;
  static const double gap = 12;
  static const double cardRadius = 16;
  static const double sheetRadius = 24;
  static const double buttonRadius = 14;
  static const double buttonHeight = 52;

  static const String head = 'PlusJakartaSans';
  static const String body = 'Inter';
}
