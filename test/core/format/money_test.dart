import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/format/money.dart';

/// Ports `frontend/src/lib/formatMoney.test.ts`'s cases bit-for-bit.
void main() {
  group('formatZAR', () {
    test('formats a positive string value with ZAR locale grouping', () {
      expect(formatZAR('3430.00'), 'R 3 430,00');
    });

    test('formats a negative value with leading minus outside the R prefix', () {
      expect(formatZAR('-500'), '-R 500,00');
    });

    test('formats zero', () {
      expect(formatZAR('0'), 'R 0,00');
    });

    test('returns R — for NaN input', () {
      expect(formatZAR('not-a-number'), 'R —');
    });

    test('accepts a numeric argument directly', () {
      expect(formatZAR(1000000), 'R 1 000 000,00');
    });

    test('formats a large value with multiple thousand separators', () {
      expect(formatZAR('5482000.00'), 'R 5 482 000,00');
    });
  });
}
