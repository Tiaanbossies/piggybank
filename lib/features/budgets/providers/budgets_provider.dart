import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/format/pay_period.dart';
import '../data/budgets_api.dart';
import '../models/budget.dart';

final budgetsApiProvider = Provider<BudgetsApi>((ref) => BudgetsApi(ref.watch(apiClientProvider)));

/// The month the Budgets tab is showing. Not autoDispose — the user's
/// browsing survives tab switches — which is exactly why it needs
/// [syncToCurrentMonth]: an app left running from 30 September was still
/// showing September in October (UX plan item 4).
///
/// Months are pay-cycle labels (`pay_period.dart`): with salary day 25, on
/// 26 September "this month" is already October.
class SelectedMonthNotifier extends StateNotifier<DateTime> {
  SelectedMonthNotifier({DateTime Function()? clock, int? salaryDay})
      : _clock = clock ?? DateTime.now,
        _salaryDay = salaryDay,
        _currentMonth = labelForDate((clock ?? DateTime.now)(), salaryDay),
        super(labelForDate((clock ?? DateTime.now)(), salaryDay));

  final DateTime Function() _clock;
  final int? _salaryDay;

  /// What "this month" was at the last sync — not [state], which may be a
  /// month the user deliberately browsed to.
  DateTime _currentMonth;

  void next() => state = DateTime(state.year, state.month + 1, 1);
  void previous() => state = DateTime(state.year, state.month - 1, 1);

  /// Called when the app returns to the foreground. Jumps to the new month
  /// only if the calendar month has turned since the last sync; a month
  /// the user browsed to within the same calendar month is left alone.
  void syncToCurrentMonth() {
    final current = labelForDate(_clock(), _salaryDay);
    if (current == _currentMonth) return;
    _currentMonth = current;
    state = current;
  }
}

final selectedBudgetMonthProvider = StateNotifierProvider<SelectedMonthNotifier, DateTime>(
  // Rebuilt when the salary day changes, so "this month" moves with it.
  (ref) => SelectedMonthNotifier(salaryDay: ref.watch(salaryDayProvider)),
);

final budgetProgressProvider = FutureProvider.autoDispose<List<BudgetProgress>>((ref) {
  final month = ref.watch(selectedBudgetMonthProvider);
  return ref.watch(budgetsApiProvider).progress(month);
});

/// This (pay-cycle) month's progress, whatever month the Budgets tab is on —
/// Home's progress card. It used [budgetProgressProvider], so browsing
/// back to August in Budgets quietly put August's budget on Home.
final currentMonthBudgetProgressProvider = FutureProvider.autoDispose<List<BudgetProgress>>((ref) {
  return ref.watch(budgetsApiProvider).progress(labelForDate(clock.now(), ref.watch(salaryDayProvider)));
});

/// Flat budget list for the current month, used to populate the
/// parent-budget picker when creating a sub-category budget.
final budgetsForMonthProvider = FutureProvider.autoDispose<List<Budget>>((ref) async {
  final month = ref.watch(selectedBudgetMonthProvider);
  final all = await ref.watch(budgetsApiProvider).list();
  return all.where((b) => b.month.year == month.year && b.month.month == month.month).toList();
});
