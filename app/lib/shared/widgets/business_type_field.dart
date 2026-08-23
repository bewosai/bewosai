import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

const List<String> businessTypePresets = [
  'Retail Shop',
  'Restaurant',
  'Pharmacy',
  'Wholesale',
  'Grocery',
  'Electronics',
  'Hardware',
  'Service',
  'Manufacturing',
  'Other',
];

/// Preset chips (Retail/Restaurant/Pharmacy/...) with an "Other" fallback
/// that reveals a free-text field — wired to an external [controller] that
/// always holds the final value to save, same as every other field on
/// these forms.
class BusinessTypeField extends StatefulWidget {
  final TextEditingController controller;

  const BusinessTypeField({super.key, required this.controller});

  @override
  State<BusinessTypeField> createState() => _BusinessTypeFieldState();
}

class _BusinessTypeFieldState extends State<BusinessTypeField> {
  // Kept separate from the controller's text so picking "Other" can clear
  // the field for typing without that clearing also un-selecting "Other"
  // (deriving custom-mode from the text value alone creates exactly that
  // dead end).
  late bool _customMode;
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    final current = widget.controller.text.trim();
    _customMode = current.isNotEmpty && !businessTypePresets.contains(current);
    _customController = TextEditingController(text: _customMode ? current : '');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _pick(String preset) {
    if (preset == 'Other') {
      setState(() => _customMode = true);
      widget.controller.text = _customController.text.trim();
      return;
    }
    setState(() => _customMode = false);
    widget.controller.text = preset;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _customMode ? 'Other' : widget.controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business Type', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: businessTypePresets.map((preset) {
            final isSelected = selected == preset;
            return ChoiceChip(
              label: Text(preset),
              selected: isSelected,
              onSelected: (_) => _pick(preset),
              selectedColor: AppColors.orange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              backgroundColor: AppColors.navy50,
              side: BorderSide.none,
            );
          }).toList(),
        ),
        if (_customMode) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _customController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Enter your business type'),
            onChanged: (v) => widget.controller.text = v.trim(),
          ),
        ],
      ],
    );
  }
}
