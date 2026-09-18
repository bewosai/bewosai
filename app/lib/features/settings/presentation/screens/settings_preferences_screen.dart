import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/calendar/nepal_time.dart';
import '../../../../core/calendar/nepali_calendar_service.dart';
import '../../../../core/i18n/translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_mode.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../providers/settings_provider.dart';

class SettingsPreferencesScreen extends StatelessWidget {
  const SettingsPreferencesScreen({super.key});

  Future<void> _setTheme(BuildContext context, SettingsProvider settings, bool dark) async {
    final ok = await settings.setThemeMode(dark ? AppThemeMode.dark : AppThemeMode.light);
    if (!context.mounted || ok) return;
    showAppSnackBar(context, settings.error ?? 'Could not save theme', isError: true);
  }

  Future<void> _setCalendar(BuildContext context, SettingsProvider settings, bool nepali) async {
    if (settings.settings.showNepaliCalendar == nepali) return;
    final ok = await settings.setNepaliCalendar(nepali);
    if (!context.mounted || ok) return;
    showAppSnackBar(context, settings.error ?? 'Could not save calendar setting', isError: true);
  }

  Future<void> _setHideAmounts(BuildContext context, SettingsProvider settings, bool hide) async {
    final ok = await settings.setHideAmounts(hide);
    if (!context.mounted || ok) return;
    showAppSnackBar(context, settings.error ?? 'Could not save privacy setting', isError: true);
  }

  Future<void> _setLanguage(BuildContext context, SettingsProvider settings, String language) async {
    if (settings.settings.language == language) return;
    final ok = await settings.setLanguage(language);
    if (!context.mounted || ok) return;
    showAppSnackBar(context, settings.error ?? 'Could not save language', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('App Preferences'), actions: const [HomeLogoButton()]),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: ResponsiveBody(
        child: settings.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.language_outlined, size: 22, color: AppColors.textSecondary),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(t('language'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                              _LanguageToggle(
                                nepali: settings.settings.language == 'ne',
                                onChanged: (nepali) => _setLanguage(context, settings, nepali ? 'ne' : 'en'),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                settings.settings.themeMode == AppThemeMode.dark
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                                size: 22,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                              _AppearanceToggle(
                                dark: settings.settings.themeMode == AppThemeMode.dark,
                                onChanged: (dark) => _setTheme(context, settings, dark),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_outlined, size: 22, color: AppColors.textSecondary),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text('Calendar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                              _CalendarToggle(
                                nepali: settings.settings.showNepaliCalendar,
                                onChanged: (nepali) => _setCalendar(context, settings, nepali),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              settings.settings.showNepaliCalendar
                                  ? 'Today: ${NepaliCalendarService.today()}'
                                  : 'Dates shown in AD (Gregorian)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.schedule_outlined, size: 22, color: AppColors.textSecondary),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text('Time zone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Nepal (UTC+5:45)', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    // Business dates and "today" always follow Nepal
                                    // time, whatever the phone's own timezone is set to.
                                    'Now ${TimeOfDay.fromDateTime(NepalTime.now()).format(context)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                settings.settings.hideAmounts
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 22,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text('Hide Amounts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                              Switch(
                                value: settings.settings.hideAmounts,
                                onChanged: (v) => _setHideAmounts(context, settings, v),
                                activeThumbColor: AppColors.orange,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Masks sales, dues, and balances on every screen',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AppearanceToggle extends StatelessWidget {
  final bool dark;
  final ValueChanged<bool> onChanged;

  const _AppearanceToggle({required this.dark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.navy50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, label: 'Light', selected: !dark, onTap: () => onChanged(false)),
          _segment(context, label: 'Dark', selected: dark, onTap: () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, {required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.success : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final bool nepali;
  final ValueChanged<bool> onChanged;

  const _LanguageToggle({required this.nepali, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.navy50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, label: 'English', selected: !nepali, onTap: () => onChanged(false)),
          _segment(context, label: 'नेपाली', selected: nepali, onTap: () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, {required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.success : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CalendarToggle extends StatelessWidget {
  final bool nepali;
  final ValueChanged<bool> onChanged;

  const _CalendarToggle({required this.nepali, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.navy50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, label: 'BS', selected: nepali, onTap: () => onChanged(true)),
          _segment(context, label: 'AD', selected: !nepali, onTap: () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, {required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.success : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
