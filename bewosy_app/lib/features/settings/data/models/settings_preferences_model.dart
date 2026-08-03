import '../../../../core/theme/theme_mode.dart';
import '../../domain/entities/settings_preferences.dart';

class SettingsPreferencesModel extends SettingsPreferences {
  const SettingsPreferencesModel({
    super.themeMode,
    super.showNepaliCalendar,
  });

  factory SettingsPreferencesModel.fromMap(Map<String, dynamic> map) {
    return SettingsPreferencesModel(
      themeMode: AppThemeModeX.fromStorage(map['theme_mode'] as String?),
      showNepaliCalendar: map['show_nepali_calendar'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'theme_mode': themeMode.storageValue,
      'show_nepali_calendar': showNepaliCalendar,
    };
  }
}
