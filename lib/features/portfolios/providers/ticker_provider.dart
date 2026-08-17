import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ticker_history.dart';
import '../models/ticker_search_result.dart';
import 'portfolios_provider.dart';

/// Keyed by the raw (debounced) search query — feeds
/// [TickerAutocompleteField]'s suggestions dropdown.
final tickerSearchProvider = FutureProvider.autoDispose.family<List<TickerSearchResult>, String>((ref, query) {
  return ref.watch(portfoliosApiProvider).tickerSearch(query);
});

typedef TickerHistoryKey = ({String ticker, String period});

/// Keyed by ticker+period — feeds both the holdings-list sparkline
/// (period: '1mo') and the holding detail sheet's price chart.
final tickerHistoryProvider = FutureProvider.autoDispose.family<TickerHistory, TickerHistoryKey>((ref, key) {
  return ref.watch(portfoliosApiProvider).tickerHistory(key.ticker, period: key.period);
});
