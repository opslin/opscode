import 'package:flutter/material.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

  static const headingFont = 'PlusJakartaSans';
  static const bodyFont = 'DMSans';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      fontFamily: bodyFont,
      textTheme: ThemeData.light().textTheme.apply(
            fontFamily: bodyFont,
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
