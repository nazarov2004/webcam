import 'package:flutter/material.dart';

/// Centralized color palette for LensCast.
///
/// Dark mode is the primary experience; light mode is a secondary option.
/// All values come from the product design specification.
abstract final class AppColors {
  // Core surfaces (dark)
  static const Color background = Color(0xFF101318);
  static const Color surface = Color(0xFF191E27);
  static const Color surfaceAlt = Color(0xFF222834);
  static const Color surfaceHigh = Color(0xFF2B323F);

  // Accents
  static const Color primary = Color(0xFF7167F8);
  static const Color primaryDark = Color(0xFF5A50E0);
  static const Color secondary = Color(0xFF31C8D8);

  // Status
  static const Color success = Color(0xFF35C98A);
  static const Color warning = Color(0xFFF4B860);
  static const Color error = Color(0xFFEF6464);

  // Text (dark)
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFFA7B0C0);
  static const Color textMuted = Color(0xFF6B7483);

  // Light surfaces
  static const Color lightBackground = Color(0xFFF4F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEEF1F7);
  static const Color lightTextPrimary = Color(0xFF101318);
  static const Color lightTextSecondary = Color(0xFF5A6472);

  // Overlays
  static const Color scrim = Color(0x99000000);
  static const Color hairline = Color(0x1FFFFFFF);
}