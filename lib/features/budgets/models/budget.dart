import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/budgets/schemas.py`'s `BudgetOut`.
class Budget {
  const Budget({
    required this.id,
    required this.month,
    required this.totalBudget,
    required this.category,
    required this.parentBudgetId,
  });

  final String id;
  final DateTime month;
  final Decimal totalBudget;
  final String? category;
  final String? parentBudgetId;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        month: DateTime.parse(json['month'] as String),
        totalBudget: Decimal.parse(json['total_budget'].toString()),
        category: json['category'] as String?,
        parentBudgetId: json['parent_budget_id'] as String?,
      );
}

/// Mirrors `backend/app/budgets/schemas.py`'s `BudgetProgressOut` — a
/// recursive tree, one level of nesting rendered per DESIGN.md § Budgets.
class BudgetProgress {
  const BudgetProgress({
    required this.id,
    required this.month,
    required this.category,
    required this.parentBudgetId,
    required this.budgetAmount,
    required this.spent,
    required this.remaining,
    required this.pctUsed,
    required this.overBudget,
    required this.children,
  });

  final String id;
  final DateTime month;
  final String? category;
  final String? parentBudgetId;
  final Decimal budgetAmount;
  final Decimal spent;
  final Decimal remaining;
  final double pctUsed;
  final bool overBudget;
  final List<BudgetProgress> children;

  factory BudgetProgress.fromJson(Map<String, dynamic> json) => BudgetProgress(
        id: json['id'] as String,
        month: DateTime.parse(json['month'] as String),
        category: json['category'] as String?,
        parentBudgetId: json['parent_budget_id'] as String?,
        budgetAmount: Decimal.parse(json['budget_amount'].toString()),
        spent: Decimal.parse(json['spent'].toString()),
        remaining: Decimal.parse(json['remaining'].toString()),
        pctUsed: (json['pct_used'] as num).toDouble(),
        overBudget: json['over_budget'] as bool,
        children: (json['children'] as List? ?? const [])
            .map((e) => BudgetProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
