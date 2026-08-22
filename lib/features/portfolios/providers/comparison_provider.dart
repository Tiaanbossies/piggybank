import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../models/comparison_entry.dart';
import '../models/ticker_lookup.dart';
import 'portfolios_provider.dart';

/// Holds the list of instruments currently being compared, plus the active
/// period and display mode. Mutable multi-item client state (add/remove/
/// period-change), unlike this feature's other `FutureProvider`s — follows
/// the same `StateNotifier` pattern as `AuthController`.
class ComparisonState {
  const ComparisonState({this.entries = const [], this.period = ComparisonPeriod.oneYear, this.percentMode = true});

  final List<ComparisonEntry> entries;
  final ComparisonPeriod period;
  final bool percentMode;

  ComparisonState copyWith({List<ComparisonEntry>? entries, ComparisonPeriod? period, bool? percentMode}) =>
      ComparisonState(
        entries: entries ?? this.entries,
        period: period ?? this.period,
        percentMode: percentMode ?? this.percentMode,
      );
}

class ComparisonController extends StateNotifier<ComparisonState> {
  ComparisonController(this._ref) : super(const ComparisonState());

  final Ref _ref;

  Future<void> addTicker(String rawTicker) async {
    final ticker = rawTicker.trim().toUpperCase();
    if (ticker.isEmpty) return;
    if (state.entries.length >= maxComparisonEntries) return;
    if (state.entries.any((e) => e.ticker == ticker)) return;

    final id = '$ticker-${DateTime.now().microsecondsSinceEpoch}';
    final color = comparisonPalette[state.entries.length % comparisonPalette.length];
    final provisional =
        ComparisonEntry(id: id, ticker: ticker, name: ticker, currency: 'ZAR', color: color, loading: true);
    state = state.copyWith(entries: [...state.entries, provisional]);

    final api = _ref.read(portfoliosApiProvider);
    try {
      final history = await api.tickerHistory(ticker, period: state.period.apiValue);
      TickerLookup? lookup;
      try {
        lookup = await api.tickerLookup(ticker);
      } catch (_) {
        lookup = null;
      }
      _updateEntry(
        id,
        (e) => e.copyWith(name: history.name, currency: history.currency, data: history.data, loading: false, lookup: lookup),
      );
    } catch (e) {
      _updateEntry(
        id,
        (entry) => entry.copyWith(loading: false, error: e is ApiError ? e.message : 'Failed to fetch history'),
      );
    }
  }

  void removeTicker(String id) {
    state = state.copyWith(entries: state.entries.where((e) => e.id != id).toList());
  }

  /// Re-fetches every entry's history for the newly selected period —
  /// mirrors the web app's "re-fetch all entries when the period changes".
  Future<void> setPeriod(ComparisonPeriod period) async {
    if (period == state.period) return;
    state = state.copyWith(period: period, entries: [for (final e in state.entries) e.copyWith(loading: true)]);
    final api = _ref.read(portfoliosApiProvider);
    await Future.wait(state.entries.map((e) async {
      try {
        final history = await api.tickerHistory(e.ticker, period: period.apiValue);
        _updateEntry(e.id, (entry) => entry.copyWith(data: history.data, loading: false, error: null));
      } catch (err) {
        _updateEntry(
          e.id,
          (entry) => entry.copyWith(loading: false, error: err is ApiError ? err.message : 'Failed to fetch history'),
        );
      }
    }));
  }

  void setPercentMode(bool percent) {
    state = state.copyWith(percentMode: percent);
  }

  void _updateEntry(String id, ComparisonEntry Function(ComparisonEntry) update) {
    state = state.copyWith(
      entries: [for (final e in state.entries) if (e.id == id) update(e) else e],
    );
  }
}

final comparisonControllerProvider = StateNotifierProvider.autoDispose<ComparisonController, ComparisonState>((ref) {
  return ComparisonController(ref);
});
