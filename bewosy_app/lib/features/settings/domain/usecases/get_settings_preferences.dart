import '../entities/settings_preferences.dart';
import '../repositories/settings_repository.dart';

class GetSettingsPreferences {
  final SettingsRepository repository;

  GetSettingsPreferences(this.repository);

  Future<SettingsPreferences> call() {
    return repository.getPreferences();
  }
}
