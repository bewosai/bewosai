import '../entities/settings_preferences.dart';

abstract class SettingsRepository {
  Future<SettingsPreferences> getPreferences();
  Future<void> savePreferences(SettingsPreferences preferences);
}
