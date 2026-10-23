import 'package:bewosai_app/shared/widgets/sort_menu.dart';
import 'package:flutter_test/flutter_test.dart';

class _Row {
  final String name;
  final double? amount;
  final DateTime? date;
  const _Row(this.name, [this.amount, this.date]);
}

void main() {
  final byName = SortOption<_Row>('name', 'Name', (r) => r.name);
  final byAmount = SortOption<_Row>('amount', 'Amount', (r) => r.amount);
  final byDate = SortOption<_Row>('date', 'Date', (r) => r.date);

  test('names sort A–Z ignoring capitals, empty names last', () {
    final rows = [const _Row('zebra'), const _Row(''), const _Row('Apple'), const _Row('mango'), const _Row('banana')];
    expect(applySort(rows, byName, true).map((r) => r.name), ['Apple', 'banana', 'mango', 'zebra', '']);
    expect(applySort(rows, byName, false).map((r) => r.name), ['zebra', 'mango', 'banana', 'Apple', '']);
  });

  test('numbers and dates sort both ways; missing values stay last', () {
    final rows = [
      _Row('a', 50, DateTime(2026, 3, 1)),
      const _Row('b'),
      _Row('c', 5, DateTime(2026, 1, 1)),
      _Row('d', 500, DateTime(2026, 2, 1)),
    ];
    expect(applySort(rows, byAmount, true).map((r) => r.name), ['c', 'a', 'd', 'b']);
    expect(applySort(rows, byAmount, false).map((r) => r.name), ['d', 'a', 'c', 'b']);
    expect(applySort(rows, byDate, false).map((r) => r.name), ['a', 'd', 'c', 'b']);
  });

  test('equal values keep their original order', () {
    final rows = [const _Row('x', 1), const _Row('y', 1), const _Row('z', 1)];
    expect(applySort(rows, byAmount, false).map((r) => r.name), ['x', 'y', 'z']);
  });
}
