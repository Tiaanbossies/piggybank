import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/expenses_api.dart';
import '../models/expenses_summary.dart';

final expensesApiProvider = Provider<ExpensesApi>((ref) => ExpensesApi(ref.watch(apiClientProvider)));

class ExpensesDateRange {
  const ExpensesDateRange({this.dateFrom, this.dateTo});
  final DateTime? dateFrom;
  final DateTime? dateTo;

  ExpensesDateRange copyWith({DateTime? Function()? dateFrom, DateTime? Function()? dateTo}) {
    return ExpensesDateRange(
      dateFrom: dateFrom != null ? dateFrom() : this.dateFrom,
      dateTo: dateTo != null ? dateTo() : this.dateTo,
    );
  }
}

class ExpensesDateRangeNotifier extends StateNotifier<ExpensesDateRange> {
  ExpensesDateRangeNotifier() : super(const ExpensesDateRange());

  void setDateFrom(DateTime? value) => state = state.copyWith(dateFrom: () => value);
  void setDateTo(DateTime? value) => state = state.copyWith(dateTo: () => value);
  void clear() => state = const ExpensesDateRange();
}

final expensesDateRangeProvider = StateNotifierProvider<ExpensesDateRangeNotifier, ExpensesDateRange>(
  (ref) => ExpensesDateRangeNotifier(),
);

final expensesSummaryProvider = FutureProvider.autoDispose<ExpensesSummary>((ref) {
  final range = ref.watch(expensesDateRangeProvider);
  return ref.watch(expensesApiProvider).summary(dateFrom: range.dateFrom, dateTo: range.dateTo);
});
