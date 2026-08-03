import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/calendar/nepali_calendar_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_mode.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../providers/settings_provider.dart';

class SettingsPreferencesScreen extends StatelessWidget {
  const SettingsPreferencesScreen({super.key});

  static String _themeLabel(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => 'System',
        AppThemeMode.light => 'Light Mode',
        AppThemeMode.dark => 'Dark Mode',
      };

  Future<void> _pickTheme(BuildContext context, SettingsProvider settings) async {
    final picked = await showModalBottomSheet<AppThemeMode>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            for (final mode in AppThemeMode.values)
              RadioListTile<AppThemeMode>(
                value: mode,
                // ignore: deprecated_member_use
                groupValue: settings.settings.themeMode,
                // ignore: deprecated_member_use
                onChanged: (v) => Navigator.pop(sheetContext, v),
                title: Text(_themeLabel(mode)),
                activeColor: AppColors.orange,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    final ok = await settings.setThemeMode(picked);
    if (!context.mounted || ok) return;
    showAppSnackBar(context, settings.error ?? 'Could not save theme', isError: true);
  }

  Future<void> _setCalendar(BuildContext context, SettingsProvider settings, bool nepali) async {
    if (settings.settings.showNepaliCalendar == nepali) return;
    final ok = await settings.setNepaliCalendar(nepali);
    if (!context.mounted || ok) return;
    showAppSnackBar(context, settings.error ?? 'Could not save calendar setting', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('App Preferences'), actions: const [HomeLogoButton()]),
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
                        InkWell(
                          onTap: () => _pickTheme(context, settings),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.contrast, size: 22, color: AppColors.textSecondary),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                ),
                                Text(
                                  _themeLabel(settings.settings.themeMode),
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                                const Icon(Icons.chevron_right, size: 20, color: AppColors.navy300),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_outlined, size: 22, color: AppColors.textSecondary),
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
                      ],
                    ),
                  ),
                ],
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
