import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// One way a list can be ordered: [value] gives the thing to compare
/// (a String, num or DateTime; null = empty, always shown last).
class SortOption<T> {
  final String key;
  final String label;
  final Comparable? Function(T item) value;
  const SortOption(this.key, this.label, this.value);
}

/// [items] ordered by [option], ascending or descending. Text ignores capitals;
/// equal values keep their original order.
List<T> applySort<T>(List<T> items, SortOption<T> option, bool ascending) {
  Comparable? key(T item) {
    final v = option.value(item);
    if (v is String) return v.trim().isEmpty ? null : v.toLowerCase();
    return v;
  }

  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i], key(items[i]))];
  indexed.sort((a, b) {
    final va = a.$3, vb = b.$3;
    if (va == null && vb == null) return a.$1.compareTo(b.$1);
    if (va == null) return 1;
    if (vb == null) return -1;
    final c = va.compareTo(vb);
    if (c != 0) return ascending ? c : -c;
    return a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// The "Sort" button next to a list's search box: pick a field, then
/// Ascending or Descending.
class SortMenuButton<T> extends StatelessWidget {
  final List<SortOption<T>> options;
  final String selectedKey;
  final bool ascending;
  final void Function(String key, bool ascending) onChanged;

  const SortMenuButton({
    super.key,
    required this.options,
    required this.selectedKey,
    required this.ascending,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((o) => o.key == selectedKey, orElse: () => options.first);
    return PopupMenuButton<String>(
      tooltip: 'Sort',
      onSelected: (v) {
        if (v == '__asc') return onChanged(current.key, true);
        if (v == '__desc') return onChanged(current.key, false);
        onChanged(v, ascending);
      },
      itemBuilder: (_) => [
        for (final o in options)
          CheckedPopupMenuItem(value: o.key, checked: o.key == current.key, child: Text(o.label)),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(value: '__asc', checked: ascending, child: const Text('Ascending (A→Z, low→high, old→new)')),
        CheckedPopupMenuItem(value: '__desc', checked: !ascending, child: const Text('Descending (Z→A, high→low, new→old)')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.navy100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: AppColors.orange),
            const SizedBox(width: 4),
            Text(current.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
