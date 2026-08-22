import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/calc/risk_metrics.dart';

/// Ports `frontend/src/components/InstrumentComparison/riskMetrics.test.ts`'s
/// cases bit-for-bit — written first (TDD) per the approved migration plan's
/// Phase 6 instruction, before `risk_metrics.dart`'s test coverage existed.
void main() {
  group('calcAnnualisedReturn', () {
    test('returns 0 for empty or single-point input', () {
      expect(calcAnnualisedReturn([], 1), 0);
      expect(calcAnnualisedReturn([100], 1), 0);
    });

    test('computes 10% annualised return over 1 year', () {
      final r = calcAnnualisedReturn([100, 110], 1);
      expect(r, closeTo(0.1, 1e-6));
    });

    test('annualises a 21% 2-year return to ~10%', () {
      final r = calcAnnualisedReturn([100, 121], 2);
      expect(r, closeTo(0.1, 1e-5));
    });

    test('returns 0 when periodYears is 0 or negative', () {
      expect(calcAnnualisedReturn([100, 110], 0), 0);
      expect(calcAnnualisedReturn([100, 110], -1), 0);
    });

    test('returns 0 when first price is not positive', () {
      expect(calcAnnualisedReturn([0, 110], 1), 0);
      expect(calcAnnualisedReturn([-10, 110], 1), 0);
    });
  });

  group('actualYearsSpan', () {
    test('returns 0 for fewer than 2 dates', () {
      expect(actualYearsSpan([]), 0);
      expect(actualYearsSpan(['2024-01-01']), 0);
    });

    test('returns 0 for invalid or non-positive span', () {
      expect(actualYearsSpan(['not-a-date', '2024-01-01']), 0);
      expect(actualYearsSpan(['2024-01-01', '2024-01-01']), 0);
      expect(actualYearsSpan(['2024-06-01', '2024-01-01']), 0);
    });

    test('computes ~1 year for a full calendar year span', () {
      final span = actualYearsSpan(['2023-01-01', '2024-01-01']);
      expect(span, closeTo(1.0, 0.01));
    });
  });

  group('calcVolatility', () {
    test('returns 0 for flat price series', () {
      expect(calcVolatility([100, 100, 100, 100]), 0);
    });

    test('returns positive volatility for varying prices', () {
      final v = calcVolatility([100, 102, 99, 103, 98, 105]);
      expect(v, greaterThan(0));
    });

    test('returns 0 for two identical prices (zero log returns -> zero sample variance)', () {
      expect(calcVolatility([100, 100]), 0);
    });

    test('returns 0 for a single price (edge case guard)', () {
      expect(calcVolatility([100]), 0);
    });

    test('returns 0 for empty input', () {
      expect(calcVolatility([]), 0);
    });
  });

  group('calcMaxDrawdown', () {
    test('returns 0 when prices only go up', () {
      expect(calcMaxDrawdown([100, 110, 120, 130]), 0);
    });

    test('captures a 50% drawdown', () {
      expect(calcMaxDrawdown([100, 200, 100]), closeTo(0.5, 1e-6));
    });

    test('captures the largest drawdown across the series', () {
      expect(calcMaxDrawdown([100, 80, 120, 60]), closeTo(0.5, 1e-6));
    });

    test('returns 0 for fewer than 2 prices', () {
      expect(calcMaxDrawdown([]), 0);
      expect(calcMaxDrawdown([100]), 0);
    });
  });

  group('calcSharpeRatio', () {
    test('returns 0 when volatility is 0', () {
      expect(calcSharpeRatio(0.1, 0), 0);
    });

    test('computes (return - rf) / vol', () {
      expect(calcSharpeRatio(0.15, 0.2, 0.07), closeTo(0.4, 1e-6));
    });

    test('uses 7% default risk-free rate', () {
      expect(calcSharpeRatio(0.17, 0.2), closeTo(0.5, 1e-6));
    });
  });

  group('calcPercentChange', () {
    test('returns empty array for empty input', () {
      expect(calcPercentChange([]), <double>[]);
    });

    test('normalises first value to 0%', () {
      final out = calcPercentChange([100, 110, 90]);
      expect(out[0], 0);
      expect(out[1], closeTo(10, 1e-6));
      expect(out[2], closeTo(-10, 1e-6));
    });

    test('returns all zeros when base price is 0', () {
      expect(calcPercentChange([0, 0, 0]), [0, 0, 0]);
    });
  });

  group('calcTotalReturn', () {
    test('computes simple total return', () {
      expect(calcTotalReturn([100, 150]), closeTo(0.5, 1e-6));
    });

    test('returns 0 for fewer than 2 prices or non-positive first price', () {
      expect(calcTotalReturn([]), 0);
      expect(calcTotalReturn([100]), 0);
      expect(calcTotalReturn([0, 150]), 0);
    });
  });

  group('calcDailyReturns', () {
    test('returns n-1 daily returns', () {
      final out = calcDailyReturns([100, 110, 99]);
      expect(out, hasLength(2));
      expect(out[0], closeTo(0.1, 1e-6));
      expect(out[1], closeTo(-0.1, 1e-6));
    });

    test('pushes 0 when previous price is non-positive', () {
      final out = calcDailyReturns([0, 110]);
      expect(out, [0]);
    });
  });

  group('calcPearson', () {
    test('returns 1 for perfectly correlated series', () {
      expect(calcPearson([1, 2, 3, 4], [2, 4, 6, 8]), closeTo(1, 1e-6));
    });

    test('returns -1 for perfectly anti-correlated series', () {
      expect(calcPearson([1, 2, 3, 4], [4, 3, 2, 1]), closeTo(-1, 1e-6));
    });

    test('returns 0 for constant series', () {
      expect(calcPearson([1, 1, 1, 1], [1, 2, 3, 4]), 0);
    });

    test('returns 0 for fewer than 2 points (truncated to shorter length)', () {
      expect(calcPearson([1], [1, 2, 3]), 0);
      expect(calcPearson([], []), 0);
    });
  });
}
