import 'package:bewosai_app/core/utils/validators.dart';
import 'package:bewosai_app/features/inventory/data/models/inventory_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _box = Unit(
  id: 1,
  name: 'Box',
  abbreviation: 'bx',
  secondaryUnit: 'Piece',
  secondaryAbbreviation: 'pc',
  conversionFactor: 12,
  display: 'Box/Piece',
);

void main() {
  group('price for the billed unit', () {
    test('primary unit keeps the main price', () {
      expect(_box.priceFor(1200, 'Box'), 1200);
    });

    test('secondary unit divides by the conversion when no own price is set', () {
      expect(_box.priceFor(1200, 'Piece'), 100);
      expect(_box.priceFor(1000, 'piece '), 83.33);
    });

    test("the product's own per-piece price wins when set", () {
      expect(_box.priceFor(1200, 'Piece', secondaryPrice: 110), 110);
      expect(_box.priceFor(1200, 'Box', secondaryPrice: 110), 1200);
      expect(_box.priceFor(1200, 'Piece', secondaryPrice: 0), 100);
    });
  });

  group('line discount as Rs or %', () {
    test('rupees are capped to the line', () {
      expect(Validators.discountAmount('50', 400), 50);
      expect(Validators.discountAmount('900', 400), 400);
      expect(Validators.discountAmount('', 400), 0);
    });

    test('a percent is taken of the line and capped at 100%', () {
      expect(Validators.discountAmount('10', 400, percent: true), 40);
      expect(Validators.discountAmount('12.5', 333, percent: true), 41.63);
      expect(Validators.discountAmount('150', 400, percent: true), 400);
      expect(Validators.discountAmount('-5', 400, percent: true), 0);
    });

    test('percent validation', () {
      expect(Validators.discountPercent('20'), isNull);
      expect(Validators.discountPercent('101'), isNotNull);
      expect(Validators.discountPercent('abc'), isNotNull);
    });
  });
}
