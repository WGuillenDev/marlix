import 'package:flutter/material.dart';

/// Colors from the style guide (docs/diagrams/wireframes/style-guide/colors.png).
abstract final class AppColors {
  static const tan = Color(0xFFD9822B);
  static const tanDark = Color(0xFFA85F1C);
  static const tanLight = Color(0xFFF6D9B8);
  static const charcoal = Color(0xFF3B3A40);
  static const cream = Color(0xFFFFF8EE);
  static const white = Color(0xFFFFFFFF);
  static const line = Color(0xFFEADFCF);
  static const textSecondary = Color(0xFF7A7268);
  static const listening = Color(0xFF6FA8DC);
  static const success = Color(0xFF5BAA7A);
  // Reserved for 9-1-1, crisis and irreversible actions.
  static const crisis = Color(0xFFC8453C);
  static const warningBackground = Color(0xFFFDF1D6);
}

abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.tan,
      primary: AppColors.tanDark,
      onPrimary: AppColors.white,
      secondary: AppColors.charcoal,
      surface: AppColors.cream,
      onSurface: AppColors.charcoal,
      onSurfaceVariant: AppColors.textSecondary,
      outlineVariant: AppColors.line,
      error: AppColors.crisis,
    );
    return ThemeData(colorScheme: colorScheme, scaffoldBackgroundColor: AppColors.cream);
  }
}
