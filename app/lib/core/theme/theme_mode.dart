import 'package:flutter/material.dart' show ThemeMode;

/// User-facing theme preference, persisted separately from Flutter's own
/// [ThemeMode] so it can be stored as a plain string.
enum AppThemeMode { light, dark }

extension AppThemeModeX on AppThemeMode {
  // No stored value (first launch) defaults to light.
  static AppThemeMode fromStorage(String? value) {
    switch (value) {
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.light;
    }
  }

  String get storageValue => switch (this) {
        AppThemeMode.light => 'light',
        AppThemeMode.dark => 'dark',
      };

  ThemeMode get materialThemeMode => switch (this) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}
