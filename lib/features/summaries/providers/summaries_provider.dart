import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
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

/// How many trailing months the Trends screen charts. Kept here beside the
/// providers that honour it so the window is defined once, not restated in
/// the API layer and the UI.
const int trendWindowMonths = 6;

/// The trailing [trendWindowMonths] month keys (`YYYY-MM`), oldest first,
/// ending with the current month.
List<String> trailingMonthKeys({int count = trendWindowMonths, DateTime? now}) {
  final today = now ?? DateTime.now();
  return [
    for (var i = count - 1; i >= 0; i--) monthKey(DateTime(today.year, today.month - i, 1)),
  ];
}

/// Longer net-worth history than [netWorthHistoryProvider]'s 2 months —
/// the Trends screen charts the same trailing window it uses everywhere
/// else, so the three sections all describe the same period.
final netWorthTrendHistoryProvider = FutureProvider.autoDispose<List<NetWorthSnapshot>>((ref) {
  return ref.watch(summariesApiProvider).netWorthHistory(months: trendWindowMonths);
});

/// Keyed by a `YYYY-MM` month key — one call per month, matching the
/// per-id family pattern already used across this app (see
/// `portfolioHoldingsProvider`, `holdingTradesProvider`). `/budget-usage`
/// is single-month by design, so a trend fans this out over
/// [trailingMonthKeys].
///
/// A month with no budget set is an **empty state, never an error**: the
/// backend already answers with zeros, and a 404 (defensively, should the
/// backend ever start signalling "no budget" that way) is mapped to
/// [BudgetUsageSummary.empty] here rather than surfacing as a failed month
/// that would blank out the whole trend.
final budgetUsageProvider = FutureProvider.autoDispose.family<BudgetUsageSummary, String>((ref, month) async {
  try {
    return await ref.watch(summariesApiProvider).budgetUsage(month: month);
  } on ApiError catch (e) {
    if (e.statusCode == 404) return BudgetUsageSummary.empty;
    rethrow;
  }
});

/// Recurring-spend categories for the current month's trailing 3-month
/// window (the window is the backend's, see `get_recurring_expenses`).
final recurringExpensesProvider = FutureProvider.autoDispose<List<RecurringExpenseSummary>>((ref) {
  return ref.watch(summariesApiProvider).recurringExpenses();
});

/// This month's biggest expense categories.
final highCostExpensesProvider = FutureProvider.autoDispose<List<HighCostExpenseSummary>>((ref) {
  return ref.watch(summariesApiProvider).highCostExpenses();
});
