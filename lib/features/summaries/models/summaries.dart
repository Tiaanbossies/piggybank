import 'package:decimal/decimal.dart';

/// The `YYYY-MM` string the summaries endpoints expect for their `month`
/// query parameter (`_MONTH_RE` in `backend/app/summaries/router.py`).
String monthKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

/// [monthKey] for today — the client-side stand-in for the "current month"
/// default that `/budget-usage`, `/recurring-expenses` and
/// `/high-cost-expenses` deliberately don't provide server-side.
String currentMonthKey() => monthKey(DateTime.now());

/// Mirrors `backend/app/summaries/schemas.py`'s `NetWorthSummary`.
class NetWorthSummary {
  const NetWorthSummary({required this.totalAssets, required this.liabilitiesTotal, required this.netWorth});
  final Decimal totalAssets;
  final Decimal liabilitiesTotal;
  final Decimal netWorth;

  factory NetWorthSummary.fromJson(Map<String, dynamic> json) => NetWorthSummary(
        totalAssets: Decimal.parse(json['total_assets'].toString()),
        liabilitiesTotal: Decimal.parse(json['liabilities_total'].toString()),
        netWorth: Decimal.parse(json['net_worth'].toString()),
      );
}

/// Mirrors `backend/app/summaries/schemas.py`'s `CashflowSummary`.
class CashflowSummary {
  const CashflowSummary({required this.incomeTotal, required this.expenseTotal, required this.netCashflow});
  final Decimal incomeTotal;
  final Decimal expenseTotal;
  final Decimal netCashflow;

  factory CashflowSummary.fromJson(Map<String, dynamic> json) => CashflowSummary(
        incomeTotal: Decimal.parse(json['income_total'].toString()),
        expenseTotal: Decimal.parse(json['expense_total'].toString()),
        netCashflow: Decimal.parse(json['net_cashflow'].toString()),
      );
}

/// Mirrors `backend/app/summaries/schemas.py`'s `BudgetUsageSummary` — one
/// month's budget-vs-actual figures.
///
/// A month with no budget row at all is a legitimate, non-error result: the
/// backend returns `budget_total = 0` (and therefore `percent_used = 0`) for
/// it rather than a 404. [hasBudget] is the flag callers should branch on,
/// never `percentUsed == 0` (a real budget with zero spend also reads 0%).
class BudgetUsageSummary {
  const BudgetUsageSummary({
    required this.budgetTotal,
    required this.actualSpend,
    required this.remaining,
    required this.percentUsed,
  });

  final Decimal budgetTotal;
  final Decimal actualSpend;
  final Decimal remaining;
  final Decimal percentUsed;

  /// The explicit "no budget set for this month" value — used by the
  /// per-month provider family so a budget-less month renders as an empty
  /// slot in a trend, not as a failed fetch.
  static final empty = BudgetUsageSummary(
    budgetTotal: Decimal.zero,
    actualSpend: Decimal.zero,
    remaining: Decimal.zero,
    percentUsed: Decimal.zero,
  );

  bool get hasBudget => budgetTotal > Decimal.zero;

  factory BudgetUsageSummary.fromJson(Map<String, dynamic> json) => BudgetUsageSummary(
        budgetTotal: Decimal.parse(json['budget_total'].toString()),
        actualSpend: Decimal.parse(json['actual_spend'].toString()),
        remaining: Decimal.parse(json['remaining'].toString()),
        percentUsed: Decimal.parse(json['percent_used'].toString()),
      );
}

/// Mirrors `backend/app/summaries/schemas.py`'s `RecurringExpenseSummary` —
/// a category the backend saw spend in during at least 2 of the trailing 3
/// calendar months.
class RecurringExpenseSummary {
  const RecurringExpenseSummary({
    required this.category,
    required this.occurrences,
    required this.avgAmount,
    required this.totalAmount,
    required this.lastDate,
  });

  final String category;
  final int occurrences;
  final Decimal avgAmount;
  final Decimal totalAmount;
  final DateTime lastDate;

  factory RecurringExpenseSummary.fromJson(Map<String, dynamic> json) => RecurringExpenseSummary(
        category: json['category'] as String,
        occurrences: (json['occurrences'] as num).toInt(),
        avgAmount: Decimal.parse(json['avg_amount'].toString()),
        totalAmount: Decimal.parse(json['total_amount'].toString()),
        lastDate: DateTime.parse(json['last_date'] as String),
      );
}

/// Mirrors `backend/app/summaries/schemas.py`'s `HighCostExpenseSummary` —
/// one month's highest-total expense categories, already sorted descending
/// by `total_amount` server-side.
class HighCostExpenseSummary {
  const HighCostExpenseSummary({
    required this.category,
    required this.count,
    required this.totalAmount,
    required this.maxSingleAmount,
    required this.avgAmount,
    required this.lastDate,
  });

  final String category;
  final int count;
  final Decimal totalAmount;
  final Decimal maxSingleAmount;
  final Decimal avgAmount;
  final DateTime lastDate;

  factory HighCostExpenseSummary.fromJson(Map<String, dynamic> json) => HighCostExpenseSummary(
        category: json['category'] as String,
        count: (json['count'] as num).toInt(),
        totalAmount: Decimal.parse(json['total_amount'].toString()),
        maxSingleAmount: Decimal.parse(json['max_single_amount'].toString()),
        avgAmount: Decimal.parse(json['avg_amount'].toString()),
        lastDate: DateTime.parse(json['last_date'] as String),
      );
}

/// Mirrors `backend/app/summaries/schemas.py`'s `NetWorthSnapshotOut` — one
/// day's stored net-worth figure, written by the daily scheduled job
/// (`summaries/snapshot_job.py`).
class NetWorthSnapshot {
  const NetWorthSnapshot({required this.snapshotDate, required this.netWorth});
  final DateTime snapshotDate;
  final Decimal netWorth;

  factory NetWorthSnapshot.fromJson(Map<String, dynamic> json) => NetWorthSnapshot(
        snapshotDate: DateTime.parse(json['snapshot_date'] as String),
        netWorth: Decimal.parse(json['net_worth'].toString()),
      );
}
