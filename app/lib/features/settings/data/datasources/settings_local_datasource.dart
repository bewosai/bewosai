import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/theme_mode.dart';
import '../models/settings_preferences_model.dart';

class SettingsLocalDataSource {
  static const _themeModeKey = 'settings.theme_mode';
  static const _nepaliCalendarKey = 'settings.show_nepali_calendar';
  static const _hideAmountsKey = 'settings.hide_amounts';

  Future<SettingsPreferencesModel> read() async {
    final prefs = await SharedPreferences.getInstance();

    return SettingsPreferencesModel(
      themeMode: AppThemeModeX.fromStorage(
        prefs.getString(_themeModeKey),
      ),
      showNepaliCalendar:
          prefs.getBool(_nepaliCalendarKey) ?? true,
      hideAmounts: prefs.getBool(_hideAmountsKey) ?? false,
    );
  }

  Future<void> save(SettingsPreferencesModel settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _themeModeKey,
      settings.themeMode.storageValue,
    );
    await prefs.setBool(
      _nepaliCalendarKey,
      settings.showNepaliCalendar,
    );
    await prefs.setBool(
      _hideAmountsKey,
      settings.hideAmounts,
    );
  }
}
