import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the light and dark [ThemeData] for LensCast.
abstract final class AppTheme {
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scaffold: AppColors.background,
        surface: AppColors.surface,
        surfaceAlt: AppColors.surfaceAlt,
        textTheme: AppTypography.dark,
        onSurface: AppColors.textPrimary,
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scaffold: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        surfaceAlt: AppColors.lightSurfaceAlt,
        textTheme: AppTypography.light,
        onSurface: AppColors.lightTextPrimary,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color surfaceAlt,
    required TextTheme textTheme,
    required Color onSurface,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      colorScheme: colorScheme,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceAlt),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconTheme: IconThemeData(color: onSurface),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.hairline : AppColors.lightSurfaceAlt,
        space: 1,
        thickness: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: surfaceAlt,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.15),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? AppColors.textMuted : AppColors.lightTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return surfaceAlt;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
    );
  }
}