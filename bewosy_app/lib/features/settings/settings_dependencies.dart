import 'data/datasources/settings_local_datasource.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'domain/usecases/get_settings_preferences.dart';
import 'domain/usecases/save_settings_preferences.dart';
import 'presentation/providers/settings_provider.dart';

SettingsProvider createSettingsProvider() {
  final dataSource = SettingsLocalDataSource();
  final repository = SettingsRepositoryImpl(dataSource);

  return SettingsProvider(
    getPreferences: GetSettingsPreferences(repository),
    savePreferences: SaveSettingsPreferences(repository),
  );
}
