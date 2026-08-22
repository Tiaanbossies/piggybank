import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/calc/chart_utils.dart';

/// Ports `frontend/src/components/InstrumentComparison/chartUtils.test.ts`'s
/// `buildChartData`/`downsampleToMonthly` cases — written first (TDD) per the
/// approved migration plan's Phase 6 instruction. `toChartKey`'s cases are
/// NOT ported: it exists only to make tickers safe as Recharts/lodash
/// `dataKey`s, which has no Dart equivalent (see chart_utils.dart's header).
void main() {
  group('buildChartData', () {
    test('returns empty list when series is empty', () {
      expect(buildChartData([], percent: true), <Map<String, dynamic>>[]);
    });

    test('returns empty list when all series have empty prices', () {
      const s = ChartSeries(key: 'STX40', dates: [], prices: []);
      expect(buildChartData([s], percent: true), <Map<String, dynamic>>[]);
    });

    test('uses the series key as the row key', () {
      const s = ChartSeries(
        key: 'STX40.JO',
        dates: ['2024-01-15', '2024-02-15', '2024-03-15'],
        prices: [100, 110, 105],
      );
      final rows = buildChartData([s], percent: false);
      expect(rows, isNotEmpty);
      expect(rows[0].keys, contains('STX40.JO'));
    });

    test('every row has a "date" key for the x-axis', () {
      const s = ChartSeries(
        key: 'STX40',
        dates: ['2024-01-15', '2024-02-15', '2024-03-15'],
        prices: [100, 110, 105],
      );
      final rows = buildChartData([s], percent: false);
      for (final row in rows) {
        expect(row.containsKey('date'), isTrue);
      }
    });

    test('absolute mode stores raw close prices as values', () {
      const s = ChartSeries(
        key: 'STX40',
        dates: ['2024-01-15', '2024-02-15', '2024-03-15'],
        prices: [100, 110, 105],
      );
      final rows = buildChartData([s], percent: false);
      final values = rows.map((r) => r['STX40'] as double?).whereType<double>().toList();
      expect(values, hasLength(3));
      expect(values[0], closeTo(100, 1e-4));
      expect(values[1], closeTo(110, 1e-4));
      expect(values[2], closeTo(105, 1e-4));
    });

    test('percent mode normalises first value to 0', () {
      const s = ChartSeries(
        key: 'STX40',
        dates: ['2024-01-15', '2024-02-15', '2024-03-15'],
        prices: [100, 110, 105],
      );
      final rows = buildChartData([s], percent: true);
      final values = rows.map((r) => r['STX40'] as double?).whereType<double>().toList();
      expect(values[0], closeTo(0, 1e-4));
    });

    test('percent mode: second price +10% gives ~10', () {
      const s = ChartSeries(
        key: 'STX40',
        dates: ['2024-01-15', '2024-02-15', '2024-03-15'],
        prices: [100, 110, 105],
      );
      final rows = buildChartData([s], percent: true);
      final values = rows.map((r) => r['STX40'] as double?).whereType<double>().toList();
      expect(values[1], closeTo(10, 1e-4));
    });

    test('filters out non-finite values', () {
      const s = ChartSeries(
        key: 'STX40',
        dates: ['2024-01-01', '2024-01-02', '2024-01-03'],
        prices: [0, 0, 100],
      );
      final rows = buildChartData([s], percent: false);
      final values = rows.map((r) => r['STX40'] as double?).whereType<double>().toList();
      for (final v in values) {
        expect(v.isFinite, isTrue);
        expect(v.isNaN, isFalse);
      }
    });

    test('handles two series — each gets its own column', () {
      const a = ChartSeries(
        key: 'STX40.JO',
        dates: ['2024-01-15', '2024-02-15', '2024-03-15'],
        prices: [100, 110, 105],
      );
      const b = ChartSeries(
        key: 'AAPL',
        dates: ['2024-01-15', '2024-02-15', '2024-03-15'],
        prices: [200, 210, 195],
      );
      final rows = buildChartData([a, b], percent: false);
      expect(rows, isNotEmpty);
      expect(rows[0].keys, contains('STX40.JO'));
      expect(rows[0].keys, contains('AAPL'));
    });

    test('union of dates: series missing a date gets no entry for that slot', () {
      const a = ChartSeries(key: 'STX40', dates: ['2024-01-01', '2024-01-02'], prices: [100, 110]);
      const b = ChartSeries(key: 'AAPL', dates: ['2024-01-01', '2024-01-03'], prices: [200, 210]);
      final rows = buildChartData([a, b], percent: false);
      expect(rows, hasLength(3));
      final jan02 = rows.firstWhere((r) => r['date'] == '2024-01-02');
      expect(jan02.containsKey('STX40'), isTrue);
      expect(jan02.containsKey('AAPL'), isFalse);
    });
  });

  group('downsampleToMonthly', () {
    test('returns empty list for empty input', () {
      expect(downsampleToMonthly([]), <PriceRow>[]);
    });

    test('keeps all rows when each is in a different month', () {
      final data = <PriceRow>[
        (priceDate: '2024-01-01', close: 100),
        (priceDate: '2024-02-01', close: 101),
        (priceDate: '2024-03-01', close: 102),
      ];
      expect(downsampleToMonthly(data), hasLength(3));
    });

    test('keeps only the first row per calendar month', () {
      final data = <PriceRow>[
        (priceDate: '2024-01-01', close: 100),
        (priceDate: '2024-01-15', close: 101),
        (priceDate: '2024-01-31', close: 102),
        (priceDate: '2024-02-01', close: 103),
      ];
      final out = downsampleToMonthly(data);
      expect(out, hasLength(2));
      expect(out[0].priceDate, '2024-01-01');
      expect(out[1].priceDate, '2024-02-01');
    });

    test('reduces a 6-year daily series to roughly 72 monthly rows', () {
      final data = <PriceRow>[];
      var d = DateTime(2019, 1, 1);
      final end = DateTime(2025, 1, 1);
      while (d.isBefore(end)) {
        data.add((priceDate: d.toIso8601String().substring(0, 10), close: 100));
        d = d.add(const Duration(days: 1));
      }
      final out = downsampleToMonthly(data);
      expect(out.length, greaterThan(67));
      expect(out.length, lessThan(80));
    });

    test('preserves the close price of the first-in-month row', () {
      final data = <PriceRow>[
        (priceDate: '2024-03-01', close: 99.5),
        (priceDate: '2024-03-15', close: 200),
      ];
      final out = downsampleToMonthly(data);
      expect(out[0].close, 99.5);
    });

    test('is a pure function — does not mutate input', () {
      final data = <PriceRow>[
        (priceDate: '2024-01-01', close: 100),
        (priceDate: '2024-01-15', close: 101),
      ];
      final before = List<PriceRow>.of(data);
      downsampleToMonthly(data);
      expect(data, before);
    });
  });
}
