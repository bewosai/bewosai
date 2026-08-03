import '../../../../core/theme/theme_mode.dart';

class SettingsPreferences {
  final AppThemeMode themeMode;
  final bool showNepaliCalendar;

  const SettingsPreferences({
    this.themeMode = AppThemeMode.system,
    this.showNepaliCalendar = true,
  });

  SettingsPreferences copyWith({
    AppThemeMode? themeMode,
    bool? showNepaliCalendar,
  }) {
    return SettingsPreferences(
      themeMode: themeMode ?? this.themeMode,
      showNepaliCalendar: showNepaliCalendar ?? this.showNepaliCalendar,
    );
  }
}
