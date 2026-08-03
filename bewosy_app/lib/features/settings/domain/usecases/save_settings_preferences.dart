import '../entities/settings_preferences.dart';
import '../repositories/settings_repository.dart';

class SaveSettingsPreferences {
  final SettingsRepository repository;

  SaveSettingsPreferences(this.repository);

  Future<void> call(SettingsPreferences preferences) {
    return repository.savePreferences(preferences);
  }
}
