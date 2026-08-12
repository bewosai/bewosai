import '../../../../core/theme/theme_mode.dart';

class SettingsPreferences {
  final AppThemeMode themeMode;
  final bool showNepaliCalendar;
  final bool hideAmounts;
  final String language;

  const SettingsPreferences({
    this.themeMode = AppThemeMode.light,
    this.showNepaliCalendar = true,
    this.hideAmounts = false,
    this.language = 'en',
  });

  SettingsPreferences copyWith({
    AppThemeMode? themeMode,
    bool? showNepaliCalendar,
    bool? hideAmounts,
    String? language,
  }) {
    return SettingsPreferences(
      themeMode: themeMode ?? this.themeMode,
      showNepaliCalendar: showNepaliCalendar ?? this.showNepaliCalendar,
      hideAmounts: hideAmounts ?? this.hideAmounts,
      language: language ?? this.language,
    );
  }
}
