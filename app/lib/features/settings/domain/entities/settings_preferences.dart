import '../../../../core/theme/theme_mode.dart';

class SettingsPreferences {
  final AppThemeMode themeMode;
  final bool showNepaliCalendar;
  final bool hideAmounts;

  const SettingsPreferences({
    this.themeMode = AppThemeMode.system,
    this.showNepaliCalendar = true,
    this.hideAmounts = false,
  });

  SettingsPreferences copyWith({
    AppThemeMode? themeMode,
    bool? showNepaliCalendar,
    bool? hideAmounts,
  }) {
    return SettingsPreferences(
      themeMode: themeMode ?? this.themeMode,
      showNepaliCalendar: showNepaliCalendar ?? this.showNepaliCalendar,
      hideAmounts: hideAmounts ?? this.hideAmounts,
    );
  }
}
