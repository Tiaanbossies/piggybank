import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/budgets_api.dart';
import '../models/budget.dart';

final budgetsApiProvider = Provider<BudgetsApi>((ref) => BudgetsApi(ref.watch(apiClientProvider)));

DateTime _firstOfCurrentMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
}

class SelectedMonthNotifier extends StateNotifier<DateTime> {
  SelectedMonthNotifier() : super(_firstOfCurrentMonth());

  void next() => state = DateTime(state.year, state.month + 1, 1);
  void previous() => state = DateTime(state.year, state.month - 1, 1);
}

final selectedBudgetMonthProvider = StateNotifierProvider<SelectedMonthNotifier, DateTime>(
  (ref) => SelectedMonthNotifier(),
);

final budgetProgressProvider = FutureProvider.autoDispose<List<BudgetProgress>>((ref) {
  final month = ref.watch(selectedBudgetMonthProvider);
  return ref.watch(budgetsApiProvider).progress(month);
});

/// Flat budget list for the current month, used to populate the
/// parent-budget picker when creating a sub-category budget.
final budgetsForMonthProvider = FutureProvider.autoDispose<List<Budget>>((ref) async {
  final month = ref.watch(selectedBudgetMonthProvider);
  final all = await ref.watch(budgetsApiProvider).list();
  return all.where((b) => b.month.year == month.year && b.month.month == month.month).toList();
});
