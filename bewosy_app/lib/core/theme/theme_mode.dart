import 'package:flutter/material.dart' show ThemeMode;

/// User-facing theme preference, persisted separately from Flutter's own
/// [ThemeMode] so it can be stored as a plain string.
enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  static AppThemeMode fromStorage(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }

  String get storageValue => switch (this) {
        AppThemeMode.light => 'light',
        AppThemeMode.dark => 'dark',
        AppThemeMode.system => 'system',
      };

  ThemeMode get materialThemeMode => switch (this) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };
}
