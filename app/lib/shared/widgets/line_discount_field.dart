import 'package:flutter/material.dart';

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
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: isPercent ? 'Discount (%)' : 'Discount (Rs)',
        helperText: amount > 0 && gross > 0
            ? isPercent
                ? '= ${Formatters.currency(amount)} off'
                : '= ${(amount / gross * 100).toStringAsFixed(1)}% of the line'
            : null,
        suffixIcon: TextButton(
          onPressed: _toggle,
          child: Text(isPercent ? '%' : 'Rs', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      // Re-checked as quantity/price change too, since the cap moves with them.
      validator: (v) => isPercent ? Validators.discountPercent(v) : Validators.discount(v, gross),
      onChanged: (_) => onChanged(),
    );
  }
}
