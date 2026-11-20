import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand gradient (logo, primary CTA)
  static const brandBlue = Color(0xFF1E9BFF);
  static const brandIndigo = Color(0xFF4F46E5);
  static const brandPurple = Color(0xFFB164F5);
  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandBlue, Color(0xFF6D6AF0), brandPurple],
  );

  static const primary = Color(0xFF2563EB);

  // Partner Hub (home) accents
  static const violet = Color(0xFF5B4BEA);
  static const violetSoft = Color(0xFFEEEBFF);
  static const violetGradient =
      LinearGradient(colors: [Color(0xFF5B4BEA), Color(0xFF7B5CF0)]);
  static const cardBorder = Color(0xFFE6EAF6);
  static const amber = Color(0xFFF6B726);
  static const amberSoft = Color(0xFFFFF1CF);
  static const rose = Color(0xFFE5484D);
  static const roseSoft = Color(0xFFFFE3E3);
  static const mint = Color(0xFF16A34A);
  static const mintSoft = Color(0xFFE3F7EA);
  static const countdownRed = Color(0xFFE5232E);
  static const navy = Color(0xFF0B1033);
  static const textPrimary = Color(0xFF0B1033);
  static const textSecondary = Color(0xFF4B5563);
  static const textMuted = Color(0xFF8A94A6);
  static const link = Color(0xFF2563EB);

  static const canvas = Color(0xFFF6F8FE);
  static const surface = Colors.white;
  static const border = Color(0xFFDCE6F7);
  static const borderStrong = Color(0xFFB9CDF3);
  static const selectedFill = Color(0xFFEEF0FE);

  static const error = Color(0xFFD92D20);
  static const success = Color(0xFF16A34A);

  // Role tile accents (soft bg / icon)
  static const roleB2b = Color(0xFF4F46E5);
  static const roleB2bBg = Color(0xFFE8EAFD);
  static const roleB2c = Color(0xFF7C3AED);
  static const roleB2cBg = Color(0xFFF0E8FD);
  static const roleAuction = Color(0xFF0FA67E);
  static const roleAuctionBg = Color(0xFFDDF6EE);
  static const roleRepair = Color(0xFFD946EF);
  static const roleRepairBg = Color(0xFFFBE7FB);
}
