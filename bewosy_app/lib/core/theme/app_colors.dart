import 'package:flutter/material.dart';

/// Bewosy design-system palette: deep navy + warm orange, Nepal small-business
/// branding. Keep this the single source of truth for color — screens should
/// reference [AppColors], never hard-code a `Color(0x...)`.
///
/// Theme-role tokens (surface/background/text/divider/status-tints) are
/// getters driven by [isDark], which [SettingsProvider] flips app-wide —
/// see AppTheme and main.dart's MaterialApp.themeMode wiring. Brand colors
/// (navy/orange scales, status hues) stay constant across both themes.
class AppColors {
  AppColors._();

  static bool isDark = false;

  // Navy — brand scale, constant across themes
  static const Color navy900 = Color(0xFF0A2540);
  static const Color navy800 = Color(0xFF102D50);
  static const Color navy700 = Color(0xFF1A3A60);
  static const Color navy600 = Color(0xFF2A4A78);
  static const Color navy500 = Color(0xFF607898);
  static const Color navy400 = Color(0xFF90B0D0);
  static const Color navy300 = Color(0xFFB0C8E4);
  static const Color navy200 = Color(0xFFCCD8F0);
  static const Color navy100 = Color(0xFFDDE6F8);
  static const Color navy50 = Color(0xFFF0F4FB);
  static const Color navy = navy900;

  static const Gradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy900, navy700],
  );

  // Orange — brand accent, constant across themes
  static const Color orange = Color(0xFFFF6B35);
  static const Color orangeDark = Color(0xFFE0501C);
  static const Color orangeLight = Color(0xFFFFE4D6);

  static const Gradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange, orangeDark],
  );

  // Dark-mode surfaces (deep navy, not pure black — matches the brand)
  static const Color _darkBackground = Color(0xFF071B32);
  static const Color _darkSurface = Color(0xFF0F2A48);
  static const Color _darkDivider = Color(0xFF1E3B5C);

  // Surfaces / text — flip with theme
  static Color get surface => isDark ? _darkSurface : Colors.white;
  static Color get background => isDark ? _darkBackground : navy50;
  static Color get textPrimary => isDark ? Colors.white : navy900;
  static Color get textSecondary => isDark ? navy300 : navy500;
  static Color get divider => isDark ? _darkDivider : navy100;

  // Status — hue stays constant, tint background flips for legibility
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2563EB);

  static Color get successBg => isDark ? const Color(0xFF113322) : const Color(0xFFDCFCE7);
  static Color get errorBg => isDark ? const Color(0xFF3B1414) : const Color(0xFFFEE2E2);
  static Color get infoBg => isDark ? const Color(0xFF122A4A) : const Color(0xFFDBEAFE);

  /// Maps a backend status/type code (e.g. Sale.status, Business.status) to a
  /// badge color. Falls back to neutral navy for anything unrecognized.
  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
      case 'ACTIVE':
      case 'ACCEPTED':
      case 'PAID':
      case 'COMPLETED':
        return success;
      case 'CANCELLED':
      case 'REJECTED':
      case 'SUSPENDED':
      case 'OVERDUE':
      case 'ARCHIVED':
        return error;
      case 'SENT':
        return info;
      case 'DRAFT':
      case 'PENDING':
        return warning;
      default:
        return isDark ? navy300 : navy500;
    }
  }
}
