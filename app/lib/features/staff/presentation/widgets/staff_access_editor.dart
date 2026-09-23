import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/staff_access.dart';

/// One row per feature with a level to pick - what a staff member may do in
/// each. [value] is the full permission map; [onChanged] gets a new one when
/// the owner changes a row.
class StaffAccessEditor extends StatelessWidget {
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const StaffAccessEditor({super.key, required this.value, required this.onChanged, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (module, label) in staffModules) _row(context, module, label),
      ],
    );
  }

  Widget _row(BuildContext context, String module, String label) {
    final current = accessFor(value, module); // null = a custom mix
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          DropdownButton<StaffAccess?>(
            value: current,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: current == StaffAccess.none ? AppColors.textSecondary : AppColors.orangeDark,
            ),
            items: [
              // A mix no level describes stays selectable-looking but can't be re-picked.
              if (current == null)
                const DropdownMenuItem<StaffAccess?>(value: null, enabled: false, child: Text('Custom')),
              for (final level in StaffAccess.values)
                DropdownMenuItem<StaffAccess?>(value: level, child: Text(accessLabel(level))),
            ],
            onChanged: enabled
                ? (level) {
                    if (level != null) onChanged(withAccess(value, module, level));
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
