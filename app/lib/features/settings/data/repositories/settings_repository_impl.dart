import '../../domain/entities/settings_preferences.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';
import '../models/settings_preferences_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource localDataSource;

  SettingsRepositoryImpl(this.localDataSource);

  @override
  Future<SettingsPreferences> getPreferences() {
    return localDataSource.read();
  }

  @override
  Future<void> savePreferences(SettingsPreferences preferences) {
    return localDataSource.save(
      SettingsPreferencesModel(
        themeMode: preferences.themeMode,
        showNepaliCalendar: preferences.showNepaliCalendar,
        hideAmounts: preferences.hideAmounts,
        language: preferences.language,
      ),
    );
  }
}
