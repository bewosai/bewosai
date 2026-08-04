import 'package:flutter/material.dart';

/// Bewosy design-system palette: deep navy + warm orange, Nepal small-business
/// branding. Keep this the single source of truth for color — screens should
/// reference [AppColors], never hard-code a `Color(0x...)`.
///
/// Theme-role tokens (surface/background/text/divider/status-tints) are
/// getters driven by [isDark], which main.dart keeps in sync with the
/// active [ThemeData] so every screen's hard-coded `AppColors.x` reference
/// (not just widgets that read `Theme.of(context)`) follows dark mode too.
/// [AppTheme] builds its light/dark ThemeData from the `*Light`/`*Dark`
/// constants directly, since both must exist as fixed palettes regardless
/// of whatever `isDark` happens to be at the moment they're constructed.
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

  // Fixed palettes — AppTheme.light / AppTheme.dark build from these.
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF0F2A48);
  static const Color backgroundLight = navy50;
  static const Color backgroundDark = Color(0xFF071B32);
  static const Color textPrimaryLight = navy900;
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryLight = navy500;
  static const Color textSecondaryDark = navy300;
  static const Color dividerLight = navy100;
  static const Color dividerDark = Color(0xFF1E3B5C);
  static const Color successBgLight = Color(0xFFDCFCE7);
  static const Color successBgDark = Color(0xFF113322);
  static const Color errorBgLight = Color(0xFFFEE2E2);
  static const Color errorBgDark = Color(0xFF3B1414);
  static const Color infoBgLight = Color(0xFFDBEAFE);
  static const Color infoBgDark = Color(0xFF122A4A);

  // Runtime lookups — every screen already references these; they follow
  // isDark automatically instead of needing Theme.of(context) everywhere.
  static Color get surface => isDark ? surfaceDark : surfaceLight;
  static Color get background => isDark ? backgroundDark : backgroundLight;
  static Color get textPrimary => isDark ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary => isDark ? textSecondaryDark : textSecondaryLight;
  static Color get divider => isDark ? dividerDark : dividerLight;
  static Color get successBg => isDark ? successBgDark : successBgLight;
  static Color get errorBg => isDark ? errorBgDark : errorBgLight;
  static Color get infoBg => isDark ? infoBgDark : infoBgLight;

  // Status — hue stays constant across themes
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2563EB);

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
        return textSecondary;
    }
  }
}
