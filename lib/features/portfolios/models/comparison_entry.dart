import 'package:flutter/material.dart';

import 'ticker_history.dart';
import 'ticker_lookup.dart';

/// Time windows offered by the ticker-history endpoint (`?period=`), mirrors
/// the web app's `TimePeriod` union.
enum ComparisonPeriod {
  oneMonth('1mo', 1 / 12),
  threeMonths('3mo', 0.25),
  sixMonths('6mo', 0.5),
  oneYear('1y', 1),
  threeYears('3y', 3),
  fiveYears('5y', 5);

  const ComparisonPeriod(this.apiValue, this.years);

  /// The `period` query-param value sent to `GET /portfolios/ticker-history`.
  final String apiValue;

  /// Nominal length in years, used as the annualisation denominator when
  /// [risk_metrics.actualYearsSpan] can't be computed (e.g. no data yet).
  final double years;
}

/// One instrument being compared — client-side-only state, never persisted
/// server-side, so unlike this feature's other models it has no `fromJson`.
/// Mirrors the web app's `TickerEntry`, minus the benchmark fields (CPI/STeFI
/// overlays are out of scope for this port, per the migration-status doc).
class ComparisonEntry {
  const ComparisonEntry({
    required this.id,
    required this.ticker,
    required this.name,
    required this.currency,
    required this.color,
    this.data = const [],
    this.loading = false,
    this.error,
    this.lookup,
  });

  final String id;
  final String ticker;
  final String name;
  final String currency;
  final Color color;
  final List<PricePoint> data;
  final bool loading;
  final String? error;

  /// Factsheet fields (expense ratio, fund family, inception date, category,
  /// dividend yield) — reuses the existing model rather than duplicating its
  /// fields onto this one.
  final TickerLookup? lookup;

  ComparisonEntry copyWith({
    String? ticker,
    String? name,
    String? currency,
    List<PricePoint>? data,
    bool? loading,
    String? error,
    TickerLookup? lookup,
  }) =>
      ComparisonEntry(
        id: id,
        ticker: ticker ?? this.ticker,
        name: name ?? this.name,
        currency: currency ?? this.currency,
        color: color,
        data: data ?? this.data,
        loading: loading ?? this.loading,
        error: error,
        lookup: lookup ?? this.lookup,
      );
}

/// Provisional per-entry line colours, cycled by insertion order — mirrors
/// the web app's `PALETTE`.
const comparisonPalette = [
  Color(0xFFF97316),
  Color(0xFF4CAF82),
  Color(0xFF4F8EF7),
  Color(0xFFE05C5C),
  Color(0xFFA78BFA),
];

/// A comparison holds at most this many instruments — matches the web app's
/// UI constraint (5-colour palette, 5-column summary table).
const maxComparisonEntries = 5;
