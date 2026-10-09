import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../budgets/providers/budgets_provider.dart';
import '../../summaries/providers/summaries_provider.dart';

/// What the Home hero says about this month (UX rework spec §2.1).
sealed class LeftToSpend {
  const LeftToSpend();
}

/// Top-level budgets have [amount] left between them.
class UnderBudget extends LeftToSpend {
  const UnderBudget(this.amount);
  final Decimal amount;
}

/// Top-level budgets are [amount] over between them.
class OverBudget extends LeftToSpend {
  const OverBudget(this.amount);
  final Decimal amount;
}

/// No budgets this month, so the hero shows what was spent instead.
/// [spentThisMonth] is null while the month's cashflow is still loading or
/// failed. The hero shows a dash rather than hiding the invitation.
class NoBudgets extends LeftToSpend {
  const NoBudgets(this.spentThisMonth);
  final Decimal? spentThisMonth;
}

/// UI-only, derived from existing providers: the current month's budget
/// progress (top-level budgets only, so a sub-category isn't counted twice)
/// and, when there are no budgets, the month's cashflow.
final leftToSpendProvider = Provider.autoDispose<AsyncValue<LeftToSpend>>((ref) {
  final budgets = ref.watch(currentMonthBudgetProgressProvider);
  return budgets.whenData((all) {
    final topLevel = all.where((b) => b.parentBudgetId == null);
    if (topLevel.isEmpty) {
      return NoBudgets(ref.watch(cashflowProvider).valueOrNull?.expenseTotal);
    }
    final remaining = topLevel.fold(Decimal.zero, (sum, b) => sum + b.remaining);
    return remaining < Decimal.zero ? OverBudget(-remaining) : UnderBudget(remaining);
  });
});

/// Days left in [now]'s month after today: 22 on 9 October.
int daysLeftInMonth(DateTime now) => DateTime(now.year, now.month + 1, 0).day - now.day;
