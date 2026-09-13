import '../../summaries/models/summaries.dart';

const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `Aug 2026` for a date — the one place the Trends feature names a month,
/// shared by the budget-adherence rows, the net-worth delta pill and the
/// recurring-spend rows so they can't drift apart.
String monthLabel(DateTime date) => '${_monthAbbreviations[date.month - 1]} ${date.year}';

/// One month of the budget-adherence trend: the `YYYY-MM` key it was fetched
/// with, paired with that month's usage figures.
///
/// Deliberately not called an "insight" — the backend's `/insights` router is
/// an unrelated AI Q&A surface (see `plans/piggybank-nav-stitch-ota-update.md`
/// § Insights naming collision).
class MonthBudgetUsage {
  const MonthBudgetUsage({required this.monthKey, required this.usage});

  /// `YYYY-MM`, as passed to `SummariesApi.budgetUsage`.
  final String monthKey;
  final BudgetUsageSummary usage;

  /// A month with no budget row at all — rendered as a muted "not set" row
  /// in the trend rather than dropped, so the window stays a continuous
  /// six-month story instead of silently skipping gaps.
  bool get hasBudget => usage.hasBudget;

  /// `2026-08` -> `Aug 2026`.
  String get label {
    final year = int.tryParse(monthKey.substring(0, 4));
    final month = int.tryParse(monthKey.substring(5, 7));
    if (year == null || month == null || month < 1 || month > 12) return monthKey;
    return '${_monthAbbreviations[month - 1]} $year';
  }
}
