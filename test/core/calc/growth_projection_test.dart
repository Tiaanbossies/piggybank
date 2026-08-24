import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/calc/growth_projection.dart';

/// Ports `frontend/src/pages/TfsaPage.tsx`'s `growthProjection` test cases
/// bit-for-bit, matching `loan_calc_test.dart`'s TDD convention.
void main() {
  group('growthProjection', () {
    test('returns startBalance when startBalance is 0', () {
      expect(growthProjection(0, 8, 10), 0);
    });

    test('returns startBalance when startBalance is negative', () {
      expect(growthProjection(-100, 8, 10), -100);
    });

    test('returns startBalance when years is 0', () {
      expect(growthProjection(50000, 8, 0), 50000);
    });

    test('returns startBalance when rate is 0 (no growth)', () {
      expect(growthProjection(50000, 0, 10), 50000);
    });

    test('compounds R50,000 at 8% over 10 years to ~R107,946.25', () {
      final result = growthProjection(50000, 8, 10);
      expect(result, closeTo(107946.25, 0.01));
    });

    test('larger rate produces a larger projection for the same balance/years', () {
      final lower = growthProjection(50000, 5, 10);
      final higher = growthProjection(50000, 10, 10);
      expect(higher, greaterThan(lower));
    });
  });
}
