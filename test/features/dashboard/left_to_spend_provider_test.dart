import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/dashboard/providers/left_to_spend_provider.dart';

void main() {
  group('daysLeftInMonth', () {
    test('counts the days after today', () {
      expect(daysLeftInMonth(DateTime(2026, 10, 9)), 22);
    });

    test('is zero on the last day of the month', () {
      expect(daysLeftInMonth(DateTime(2026, 10, 31)), 0);
      expect(daysLeftInMonth(DateTime(2026, 2, 28)), 0);
    });

    test('knows a leap February', () {
      expect(daysLeftInMonth(DateTime(2028, 2, 1)), 28);
    });

    test('rolls over December', () {
      expect(daysLeftInMonth(DateTime(2026, 12, 30)), 1);
    });
  });
}
