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

/// Type scale from the style guide (docs/diagrams/wireframes/style-guide/typography.png):
/// Baloo 2 for titles, Nunito for UI and chat.
abstract final class AppText {
  static const _baloo = 'Baloo 2';
  static const _nunito = 'Nunito';

  static const display = TextStyle(
    fontFamily: _baloo,
    fontWeight: FontWeight.w800,
    fontSize: 32,
    height: 40 / 32,
  );
  static const title = TextStyle(
    fontFamily: _baloo,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 32 / 24,
  );
  static const heading = TextStyle(
    fontFamily: _nunito,
    fontWeight: FontWeight.w800,
    fontSize: 18,
    height: 24 / 18,
  );
  static const body = TextStyle(
    fontFamily: _nunito,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
  );
  static const bodyStrong = TextStyle(
    fontFamily: _nunito,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 24 / 16,
  );
  static const caption = TextStyle(
    fontFamily: _nunito,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 18 / 13,
  );
  static const button = TextStyle(
    fontFamily: _nunito,
    fontWeight: FontWeight.w800,
    fontSize: 16,
    height: 20 / 16,
  );
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
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: 'Nunito',
      textTheme: const TextTheme(
        displaySmall: AppText.display,
        titleLarge: AppText.title,
        titleMedium: AppText.heading,
        bodyLarge: AppText.body,
        bodyMedium: AppText.body,
        labelLarge: AppText.button,
        bodySmall: AppText.caption,
      ).apply(bodyColor: AppColors.charcoal, displayColor: AppColors.charcoal),
    );
  }
}
