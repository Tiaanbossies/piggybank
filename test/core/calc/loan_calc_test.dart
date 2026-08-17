import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/calc/loan_calc.dart';

/// Ports `frontend/src/lib/loanCalc.test.ts`'s cases bit-for-bit — written
/// first (TDD) per the approved migration plan's Phase 3 instruction, before
/// `loan_calc.dart` exists.
void main() {
  group('calcExtraForTarget', () {
    test('returns 0 when monthsEarly is 0', () {
      expect(calcExtraForTarget(200000, 10, 120, 0), 0);
    });

    test('returns a positive number for monthsEarly=12 on a 120-month R200000 loan at 10%', () {
      final extra = calcExtraForTarget(200000, 10, 120, 12);
      expect(extra, greaterThan(0));
    });

    test('returns 0 when monthsEarly >= remainingMonths', () {
      expect(calcExtraForTarget(200000, 10, 120, 120), 0);
      expect(calcExtraForTarget(200000, 10, 120, 150), 0);
    });
  });

  group('calcAcceleratedPayoff', () {
    test('newMonths equals remainingMonths when extra is 0', () {
      final result = calcAcceleratedPayoff(200000, 10, 108, 0);
      expect(result.newMonths, 108);
      expect(result.monthsSaved, 0);
    });

    test('newMonths is less than remainingMonths when extra=500 on a 108-month R200000 loan at 10%', () {
      final result = calcAcceleratedPayoff(200000, 10, 108, 500);
      expect(result.newMonths, lessThan(108));
      expect(result.monthsSaved, greaterThan(0));
    });

    test('interestSaved is greater than 0 when extra > 0', () {
      final result = calcAcceleratedPayoff(200000, 10, 108, 500);
      expect(result.interestSaved, greaterThan(0));
    });
  });
}
