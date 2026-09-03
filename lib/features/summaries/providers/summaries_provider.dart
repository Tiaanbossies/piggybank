import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/summaries_api.dart';
import '../models/summaries.dart';

final summariesApiProvider = Provider<SummariesApi>((ref) => SummariesApi(ref.watch(apiClientProvider)));

final netWorthProvider = FutureProvider.autoDispose<NetWorthSummary>((ref) {
  return ref.watch(summariesApiProvider).netWorth();
});

final cashflowProvider = FutureProvider.autoDispose<CashflowSummary>((ref) {
  return ref.watch(summariesApiProvider).cashflow();
});

/// Feeds the Dashboard's net-worth trend pill — 2 months of history is
/// enough to find a ~30-day-old comparison point without over-fetching.
final netWorthHistoryProvider = FutureProvider.autoDispose<List<NetWorthSnapshot>>((ref) {
  return ref.watch(summariesApiProvider).netWorthHistory(months: 2);
});
