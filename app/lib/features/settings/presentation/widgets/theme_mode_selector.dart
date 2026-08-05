import 'package:flutter/material.dart';

import '../../../../core/theme/theme_mode.dart';

class ThemeModeSelector extends StatelessWidget {
  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  const ThemeModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _item(
          context,
          AppThemeMode.system,
          Icons.brightness_auto_outlined,
          'System',
          'Follow device appearance',
        ),
        _item(
          context,
          AppThemeMode.light,
          Icons.light_mode_outlined,
          'Light',
          'Always use light mode',
        ),
        _item(
          context,
          AppThemeMode.dark,
          Icons.dark_mode_outlined,
          'Dark',
          'Always use dark mode',
        ),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    AppThemeMode mode,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return RadioListTile<AppThemeMode>(
      value: mode,
      groupValue: value,
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
    );
  }
}
