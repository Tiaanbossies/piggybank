import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../summaries/providers/summaries_provider.dart';
import '../models/month_budget_usage.dart';

/// The trailing-[trendWindowMonths] budget-adherence series, oldest month
/// first.
///
/// There is no multi-month budget endpoint (`get_budget_usage` in
/// `backend/app/summaries/router.py` takes a required single `month`), so
/// this composes the existing single-month call once per month via
/// [budgetUsageProvider]'s family — each month is its own cached provider,
/// so a re-render or a partial refresh doesn't refetch the whole window.
final budgetAdherenceTrendProvider = FutureProvider.autoDispose<List<MonthBudgetUsage>>((ref) async {
  final months = trailingMonthKeys();
  final usages = await Future.wait(months.map((m) => ref.watch(budgetUsageProvider(m).future)));
  return [
    for (var i = 0; i < months.length; i++) MonthBudgetUsage(monthKey: months[i], usage: usages[i]),
  ];
});
