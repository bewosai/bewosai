import 'package:flutter/foundation.dart';

import '../../../../core/i18n/translations.dart';
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
      AppTranslations.language = _settings.language;
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

  /// Also switches the calendar to match (Nepali → BS, English → AD) — the
  /// two started as independent toggles, but users consistently expect
  /// picking Nepali to mean "everything Nepali," dates included. The
  /// separate "Date Format" setting still lets anyone override this
  /// afterward (e.g. English UI with BS dates).
  Future<bool> setLanguage(String language) async {
    return _save(_settings.copyWith(
      language: language,
      showNepaliCalendar: language == 'ne',
    ));
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
      AppTranslations.language = _settings.language;
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
