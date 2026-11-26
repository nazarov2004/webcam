import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles for LensCast.
///
/// Uses the platform default font family (San Francisco / Roboto / Segoe) so
/// the app ships with no bundled font assets while staying modern.
abstract final class AppTypography {
  static const TextTheme dark = TextTheme(
    displayLarge: TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      color: AppColors.textPrimary,
      height: 1.1,
    ),
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppColors.textPrimary,
      height: 1.15,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: AppColors.textPrimary,
    ),
  );

  static const TextTheme light = TextTheme(
    displayLarge: TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      color: AppColors.lightTextPrimary,
      height: 1.1,
    ),
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppColors.lightTextPrimary,
      height: 1.15,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: AppColors.lightTextPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: AppColors.lightTextPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.lightTextPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.lightTextSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.lightTextSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: AppColors.lightTextPrimary,
    ),
  );
}