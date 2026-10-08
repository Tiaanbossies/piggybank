import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/format/money.dart';

/// Ports `frontend/src/lib/formatMoney.test.ts`'s cases, with the spaces as
/// no-break spaces (` `), which the web version doesn't use.
void main() {
  group('formatZAR', () {
    test('never contains a space a line can break at', () {
      expect(formatZAR(480000), isNot(contains(' ')));
      expect(formatZAR(-1250.5), isNot(contains(' ')));
    });

    test('formats a positive string value with ZAR locale grouping', () {
      expect(formatZAR('3430.00'), 'R\u00A03\u00A0430,00');
    });

    test('formats a negative value with leading minus outside the R prefix', () {
      expect(formatZAR('-500'), '-R\u00A0500,00');
    });

    test('formats zero', () {
      expect(formatZAR('0'), 'R\u00A00,00');
    });

    test('returns R — for NaN input', () {
      expect(formatZAR('not-a-number'), 'R —');
    });

    test('accepts a numeric argument directly', () {
      expect(formatZAR(1000000), 'R\u00A01\u00A0000\u00A0000,00');
    });

    test('formats a large value with multiple thousand separators', () {
      expect(formatZAR('5482000.00'), 'R\u00A05\u00A0482\u00A0000,00');
    });
  });
}
