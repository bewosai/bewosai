import 'package:flutter/foundation.dart';

import '../../../../core/theme/theme_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/settings_preferences.dart';
import '../../domain/usecases/get_settings_preferences.dart';
import '../../domain/usecases/save_settings_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final GetSettingsPreferences getPreferences;
  final SaveSettingsPreferences savePreferences;

  SettingsProvider({
    required this.getPreferences,
    required this.savePreferences,
  });

  SettingsPreferences _settings = const SettingsPreferences();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  SettingsPreferences get settings => _settings;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await getPreferences();
      Formatters.useNepaliCalendar = _settings.showNepaliCalendar;
      Formatters.hideAmounts = _settings.hideAmounts;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> setThemeMode(AppThemeMode mode) async {
    return _save(_settings.copyWith(themeMode: mode));
  }

  Future<bool> setNepaliCalendar(bool enabled) async {
    return _save(_settings.copyWith(showNepaliCalendar: enabled));
  }

  Future<bool> setHideAmounts(bool enabled) async {
    return _save(_settings.copyWith(hideAmounts: enabled));
  }

  Future<bool> _save(SettingsPreferences value) async {
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      await savePreferences(value);
      _settings = value;
      Formatters.useNepaliCalendar = _settings.showNepaliCalendar;
      Formatters.hideAmounts = _settings.hideAmounts;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
