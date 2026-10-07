import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';

/// A billing line's discount, typed as rupees or as a % of the line. The
/// Rs / % button at the end switches between them, converting what's typed so
/// the discount itself doesn't change. The rupee figure to save is
/// `Validators.discountAmount(controller.text, gross, percent: isPercent)`.
class LineDiscountField extends StatelessWidget {
  final TextEditingController controller;
  final bool isPercent;
  final double gross;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onChanged;

  const LineDiscountField({
    super.key,
    required this.controller,
    required this.isPercent,
    required this.gross,
    required this.onModeChanged,
    required this.onChanged,
  });

  static String _clean(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _toggle() {
    final amount = Validators.discountAmount(controller.text, gross, percent: isPercent);
    if (amount == 0) {
      controller.text = '';
    } else if (isPercent) {
      controller.text = _clean(amount);
    } else {
      controller.text = gross > 0 ? _clean((amount / gross * 10000).round() / 100) : '';
    }
    onModeChanged(!isPercent);
  }

  @override
  Widget build(BuildContext context) {
    final amount = Validators.discountAmount(controller.text, gross, percent: isPercent);
    // The two modes are a clearly labelled choice above the field (same as the
    // invoice-level "Discount as" on the sale screen) — a % and a rupee amount
    // look identical while typing, so which one is meant must be obvious.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Discount as', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Amount (Rs)'),
              selected: !isPercent,
              selectedColor: AppColors.orangeLight,
              onSelected: (_) { if (isPercent) _toggle(); },
            ),
            ChoiceChip(
              label: const Text('% of line'),
              selected: isPercent,
              selectedColor: AppColors.orangeLight,
              onSelected: (_) { if (!isPercent) _toggle(); },
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: isPercent ? 'Discount percent' : 'Discount amount',
            prefixText: isPercent ? null : 'Rs ',
            suffixText: isPercent ? '%' : null,
            helperText: amount > 0 && gross > 0
                ? isPercent
                    ? '= ${Formatters.currency(amount)} off'
                    : '= ${(amount / gross * 100).toStringAsFixed(1)}% of the line'
                : null,
          ),
          // Re-checked as quantity/price change too, since the cap moves with them.
          validator: (v) => isPercent ? Validators.discountPercent(v) : Validators.discount(v, gross),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
