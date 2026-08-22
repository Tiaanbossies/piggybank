import 'risk_metrics.dart';

// Pure chart-data-shaping helpers, ported from the web app's
// `InstrumentComparison/ComparisonChart.tsx` (`buildChartData`) and
// `useComparisonData.ts` (`downsampleToMonthly`). No Flutter/project imports.
//
// `toChartKey` from the web source is NOT ported — it exists only to make
// tickers safe as Recharts/lodash `dataKey`s (dots/hyphens break lodash's
// `_.get` path parsing). Dart uses real Map keys, not string-path property
// access, so the raw series key (e.g. the ticker) is used directly.

/// One instrument's price series, keyed by an identifier (typically the
/// ticker) that becomes its column key in the output rows.
class ChartSeries {
  const ChartSeries({required this.key, required this.dates, required this.prices});

  final String key;

  /// ISO date strings, chronological, same length as [prices].
  final List<String> dates;
  final List<double> prices;
}

/// Builds one row per date across the union of all series' dates. Each row
/// has a `'date'` key plus one entry per series that has a point on that
/// date — series missing a point for a given date are simply absent from
/// that row (not zero), matching the web's `undefined`-slot behaviour so a
/// line chart can render gaps rather than false zeros.
List<Map<String, dynamic>> buildChartData(List<ChartSeries> series, {required bool percent}) {
  final active = series.where((s) => s.prices.isNotEmpty).toList();
  if (active.isEmpty) return [];

  final transformed = <String, Map<String, double>>{};
  for (final s in active) {
    final values = percent ? calcPercentChange(s.prices) : s.prices;
    final m = <String, double>{};
    for (var i = 0; i < s.dates.length && i < values.length; i++) {
      final date = s.dates[i];
      final v = values[i];
      if (date.isNotEmpty && v.isFinite) m[date] = v;
    }
    transformed[s.key] = m;
  }

  final dateSet = <String>{};
  for (final s in active) {
    for (final date in s.dates) {
      if (date.isNotEmpty) dateSet.add(date);
    }
  }
  final dates = dateSet.toList()
    ..sort((a, b) {
      final ta = DateTime.tryParse(a);
      final tb = DateTime.tryParse(b);
      if (ta != null && tb != null) return ta.compareTo(tb);
      return a.compareTo(b);
    });

  return dates.map((date) {
    final row = <String, dynamic>{'date': date};
    for (final s in active) {
      final v = transformed[s.key]?[date];
      if (v != null) row[s.key] = v;
    }
    return row;
  }).toList();
}

/// One raw price-history point, as returned by the ticker-history endpoint.
typedef PriceRow = ({String priceDate, double close});

/// Keeps only the first row seen per calendar month ("YYYY-MM" prefix of
/// [PriceRow.priceDate]), so a multi-year daily series can render on a chart
/// without thousands of points. Pure — does not mutate [data].
List<PriceRow> downsampleToMonthly(List<PriceRow> data) {
  final seen = <String>{};
  final out = <PriceRow>[];
  for (final row in data) {
    final ym = row.priceDate.length >= 7 ? row.priceDate.substring(0, 7) : row.priceDate;
    if (seen.contains(ym)) continue;
    seen.add(ym);
    out.add(row);
  }
  return out;
}
