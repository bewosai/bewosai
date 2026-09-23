import 'package:bewosai_app/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.required', () {
    test('rejects null and blank/whitespace-only input', () {
      expect(Validators.required(null, 'Name'), 'Name is required');
      expect(Validators.required('', 'Name'), 'Name is required');
      expect(Validators.required('   ', 'Name'), 'Name is required');
    });

    test('accepts real, non-empty input', () {
      expect(Validators.required('Ram', 'Name'), isNull);
    });
  });

  group('Validators.positiveNumber', () {
    test('empty is allowed — this validator is opt-in, not required', () {
      expect(Validators.positiveNumber(null, 'Amount'), isNull);
      expect(Validators.positiveNumber('', 'Amount'), isNull);
    });

    test('rejects non-numeric input', () {
      expect(Validators.positiveNumber('abc', 'Amount'), 'Amount must be a number');
    });

    test('rejects zero and negative amounts', () {
      expect(Validators.positiveNumber('0', 'Amount'), 'Amount must be greater than 0');
      expect(Validators.positiveNumber('-5', 'Amount'), 'Amount must be greater than 0');
    });

    test('accepts positive integers and decimals', () {
      expect(Validators.positiveNumber('5', 'Amount'), isNull);
      expect(Validators.positiveNumber('12.50', 'Amount'), isNull);
    });
  });

  group('Validators.email', () {
    test('rejects empty email', () {
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email(null), 'Email is required');
    });

    test('rejects malformed email addresses', () {
      expect(Validators.email('not-an-email'), 'Enter a valid email');
      expect(Validators.email('missing@domain'), 'Enter a valid email');
      expect(Validators.email('@nolocal.com'), 'Enter a valid email');
      expect(Validators.email('spaces in@email.com'), 'Enter a valid email');
    });

    test('accepts well-formed email addresses, trimming surrounding whitespace', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('first.last+tag@sub.example.co'), isNull);
      expect(Validators.email('  user@example.com  '), isNull);
    });
  });

  group('Validators.phone', () {
    test('phone is optional — empty is always valid', () {
      expect(Validators.phone(null), isNull);
      expect(Validators.phone(''), isNull);
    });

    test('rejects too-short, too-long, or non-numeric input', () {
      expect(Validators.phone('12345'), 'Enter a valid phone number');
      expect(Validators.phone('1234567890123456'), 'Enter a valid phone number');
      expect(Validators.phone('98abc00001'), 'Enter a valid phone number');
    });

    test('accepts 7-15 digit phone numbers', () {
      expect(Validators.phone('9841000001'), isNull);
      expect(Validators.phone('1234567'), isNull); // 7 digits, the lower bound
    });
  });

  group('Validators.otp', () {
    test('rejects an empty code', () {
      expect(Validators.otp(''), 'Enter the code');
      expect(Validators.otp(null), 'Enter the code');
    });

    test('rejects codes that are not exactly 6 digits', () {
      expect(Validators.otp('12345'), 'Enter the 6-digit code');
      expect(Validators.otp('1234567'), 'Enter the 6-digit code');
      expect(Validators.otp('12a456'), 'Enter the 6-digit code');
    });

    test('accepts a well-formed 6-digit code', () {
      expect(Validators.otp('123456'), isNull);
    });
  });

  group('Validators.discount', () {
    test('empty input is fine (no discount)', () {
      expect(Validators.discount('', 100), isNull);
      expect(Validators.discount(null, 100), isNull);
      expect(Validators.discount('   ', 100), isNull);
    });

    test('accepts anything from 0 up to the amount it discounts', () {
      expect(Validators.discount('0', 100), isNull);
      expect(Validators.discount('40.5', 100), isNull);
      expect(Validators.discount('100', 100), isNull); // the whole line
      expect(Validators.discount('100.004', 100), isNull); // a rounding hair over
    });

    test('rejects negative, non-numeric and too-large discounts', () {
      expect(Validators.discount('-1', 100), "Discount can't be negative");
      expect(Validators.discount('abc', 100), 'Discount must be a number');
      expect(Validators.discount('100.01', 100), "Can't be more than 100.00");
      expect(Validators.discount('5', 0), "Can't be more than 0.00"); // nothing entered yet
    });
  });

  group('Validators.cappedDiscount', () {
    test('passes a sensible value through', () {
      expect(Validators.cappedDiscount('25', 100), 25);
      expect(Validators.cappedDiscount(' 12.5 ', 100), 12.5);
    });

    test('caps at the amount, floors at zero', () {
      expect(Validators.cappedDiscount('250', 100), 100);
      expect(Validators.cappedDiscount('-40', 100), 0);
    });

    test('treats empty or unparseable input as no discount', () {
      expect(Validators.cappedDiscount('', 100), 0);
      expect(Validators.cappedDiscount(null, 100), 0);
      expect(Validators.cappedDiscount('abc', 100), 0);
    });

    test('a negative gross (bad quantity) never throws', () {
      expect(Validators.cappedDiscount('10', -50), 0);
    });
  });
}
