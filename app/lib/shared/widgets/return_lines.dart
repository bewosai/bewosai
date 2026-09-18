import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// A whole number without ".0", never with thousands separators.
///
/// [Formatters.amount] writes 1000 as "1,000" — fine for display, but
/// `double.tryParse('1,000')` is null, so putting it back into a text field
/// made a return quantity of 1,000 or more silently read as 0.
String plainNumber(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

double _round2(double v) => double.parse(v.toStringAsFixed(2));

/// One returnable line of a sale or purchase, shared by the Sales Return and
/// Purchase Return screens so both behave identically.
class ReturnLine {
  /// The SaleItem / PurchaseItem this line came from.
  final int? sourceItemId;
  final int? productId;
  final String productName;
  final String unitLabel;

  /// What can still be returned: the billed quantity minus earlier returns.
  final double maxQuantity;

  /// Price per unit actually charged (see [effectivePrice]), rounded to paisa.
  final double unitPrice;

  final qtyController = TextEditingController();

  ReturnLine({
    this.sourceItemId,
    this.productId,
    required this.productName,
    this.unitLabel = '',
    required this.maxQuantity,
    required this.unitPrice,
  });

  double get qty => double.tryParse(qtyController.text.trim()) ?? 0;
  double get amount => qty * unitPrice;

  void dispose() => qtyController.dispose();

  /// The price a unit really sold for: the line total (which already has any
  /// line discount taken off) divided by its quantity. Using the list price
  /// would refund more than was paid on a discounted line. Rounded to two
  /// places because the backend stores unit prices to the paisa.
  static double effectivePrice({required double quantity, required double unitPrice, required double total}) {
    if (quantity > 0 && total > 0) return _round2(total / quantity);
    return _round2(unitPrice);
  }

  /// Sum of a set of lines, rounded to paisa like the backend's amount field.
  static double totalOf(Iterable<ReturnLine> lines) => _round2(lines.fold(0.0, (sum, l) => sum + l.amount));
}

class ReturnLineRow extends StatelessWidget {
  final ReturnLine line;
  final VoidCallback onChanged;
  final String billedLabel; // "Sold" / "Purchased"

  const ReturnLineRow({
    super.key,
    required this.line,
    required this.onChanged,
    required this.billedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final nothingLeft = line.maxQuantity <= 0;
    final unit = line.unitLabel.isEmpty ? '' : ' ${line.unitLabel}';
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                nothingLeft
                    ? 'Already fully returned'
                    : '$billedLabel at ${Formatters.currency(line.unitPrice)} · up to ${Formatters.amount(line.maxQuantity)}$unit',
                style: TextStyle(fontSize: 11.5, color: nothingLeft ? AppColors.error : AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: TextField(
            controller: line.qtyController,
            enabled: !nothingLeft,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'Return Qty',
              isDense: true,
              // One tap to return everything that's left on this line.
              suffixIcon: nothingLeft
                  ? null
                  : IconButton(
                      tooltip: 'Return all',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.done_all, size: 18),
                      onPressed: () {
                        line.qtyController.text = plainNumber(line.maxQuantity);
                        onChanged();
                      },
                    ),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v.trim()) ?? 0;
              // Never above what's left; the backend rejects it anyway, this just
              // stops the mistake before it's made.
              if (parsed > line.maxQuantity) {
                final text = plainNumber(line.maxQuantity);
                line.qtyController.value = TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(offset: text.length),
                );
              }
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}
