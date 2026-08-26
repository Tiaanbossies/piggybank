import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/budgets/models/budget.dart';

void main() {
  group('Budget.fromJson', () {
    test('parses a full top-level budget', () {
      final json = {
        'id': 'bud-1',
        'month': '2026-08-01',
        'total_budget': '1500.00',
        'category': 'Groceries',
        'parent_budget_id': null,
      };

      final budget = Budget.fromJson(json);

      expect(budget.id, 'bud-1');
      expect(budget.month, DateTime.parse('2026-08-01'));
      expect(budget.totalBudget, Decimal.parse('1500.00'));
      expect(budget.category, 'Groceries');
      expect(budget.parentBudgetId, isNull);
    });

    test('parses a sub-category budget with a parent id', () {
      final json = {
        'id': 'bud-2',
        'month': '2026-08-01',
        'total_budget': '250',
        'category': 'Takeout',
        'parent_budget_id': 'bud-1',
      };

      final budget = Budget.fromJson(json);

      expect(budget.parentBudgetId, 'bud-1');
      expect(budget.category, 'Takeout');
    });

    test('parses a budget with a null category (overall total)', () {
      final json = {
        'id': 'bud-3',
        'month': '2026-08-01',
        'total_budget': '5000',
        'category': null,
        'parent_budget_id': null,
      };

      final budget = Budget.fromJson(json);

      expect(budget.category, isNull);
    });

    test('parses total_budget from a numeric JSON value, not just a string', () {
      final json = {
        'id': 'bud-4',
        'month': '2026-08-01',
        'total_budget': 1000,
        'category': null,
        'parent_budget_id': null,
      };

      final budget = Budget.fromJson(json);

      expect(budget.totalBudget, Decimal.fromInt(1000));
    });
  });

  group('BudgetProgress.fromJson', () {
    test('parses a leaf node with no children', () {
      final json = {
        'id': 'bud-1',
        'month': '2026-08-01',
        'category': 'Groceries',
        'parent_budget_id': null,
        'budget_amount': '1500.00',
        'spent': '900.00',
        'remaining': '600.00',
        'pct_used': 60.0,
        'over_budget': false,
        'children': [],
      };

      final progress = BudgetProgress.fromJson(json);

      expect(progress.id, 'bud-1');
      expect(progress.budgetAmount, Decimal.parse('1500.00'));
      expect(progress.spent, Decimal.parse('900.00'));
      expect(progress.remaining, Decimal.parse('600.00'));
      expect(progress.pctUsed, 60.0);
      expect(progress.overBudget, isFalse);
      expect(progress.children, isEmpty);
    });

    test('parses an over-budget node', () {
      final json = {
        'id': 'bud-1',
        'month': '2026-08-01',
        'category': 'Groceries',
        'parent_budget_id': null,
        'budget_amount': '1500.00',
        'spent': '1800.00',
        'remaining': '-300.00',
        'pct_used': 120.0,
        'over_budget': true,
        'children': [],
      };

      final progress = BudgetProgress.fromJson(json);

      expect(progress.overBudget, isTrue);
      expect(progress.remaining, Decimal.parse('-300.00'));
      expect(progress.pctUsed, 120.0);
    });

    test('recursively parses nested children', () {
      final json = {
        'id': 'bud-1',
        'month': '2026-08-01',
        'category': 'Groceries',
        'parent_budget_id': null,
        'budget_amount': '1500.00',
        'spent': '900.00',
        'remaining': '600.00',
        'pct_used': 60.0,
        'over_budget': false,
        'children': [
          {
            'id': 'bud-2',
            'month': '2026-08-01',
            'category': 'Takeout',
            'parent_budget_id': 'bud-1',
            'budget_amount': '250.00',
            'spent': '300.00',
            'remaining': '-50.00',
            'pct_used': 120.0,
            'over_budget': true,
            'children': [],
          },
        ],
      };

      final progress = BudgetProgress.fromJson(json);

      expect(progress.children, hasLength(1));
      final child = progress.children.single;
      expect(child.id, 'bud-2');
      expect(child.parentBudgetId, 'bud-1');
      expect(child.overBudget, isTrue);
    });

    test('treats a missing children key as an empty list', () {
      final json = {
        'id': 'bud-1',
        'month': '2026-08-01',
        'category': null,
        'parent_budget_id': null,
        'budget_amount': '1500.00',
        'spent': '900.00',
        'remaining': '600.00',
        'pct_used': 60.0,
        'over_budget': false,
      };

      final progress = BudgetProgress.fromJson(json);

      expect(progress.children, isEmpty);
    });
  });
}
