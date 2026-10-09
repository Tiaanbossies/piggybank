import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/budgets/models/budget.dart';
import 'package:piggybank/features/budgets/providers/budgets_provider.dart';
import 'package:piggybank/features/chatbot/providers/suggested_questions_provider.dart';
import 'package:piggybank/features/savings/models/savings.dart';
import 'package:piggybank/features/savings/providers/savings_provider.dart';

BudgetProgress _budget(String category, {double pct = 50, bool over = false}) => BudgetProgress(
      id: category,
      month: DateTime(2026, 10, 1),
      category: category,
      parentBudgetId: null,
      budgetAmount: Decimal.fromInt(1000),
      spent: Decimal.fromInt(500),
      remaining: Decimal.fromInt(500),
      pctUsed: pct,
      overBudget: over,
      children: const [],
    );

SavingsOverview _overview({String? gap}) => SavingsOverview(
      target: null,
      basis: OverviewBasis.fullMonths,
      monthsOfData: 2,
      income: Decimal.parse('20000'),
      incomeIsOverride: false,
      fixedCosts: Decimal.parse('2000'),
      everydaySpending: Decimal.parse('10500'),
      leftOver: Decimal.parse('7500'),
      gap: gap == null ? null : Decimal.parse(gap),
      targetMet: false,
      savingsFound: Decimal.zero,
      confirmedCount: 0,
      suggestedCount: 0,
    );

List<String> _read({
  required Future<List<BudgetProgress>> Function() budgets,
  required Future<SavingsOverview> Function() savings,
}) {
  final container = ProviderContainer(overrides: [
    currentMonthBudgetProgressProvider.overrideWith((ref) => budgets()),
    savingsOverviewProvider.overrideWith((ref) => savings()),
  ]);
  addTearDown(container.dispose);
  return container.read(suggestedQuestionsProvider);
}

Future<List<String>> _settled({
  required Future<List<BudgetProgress>> Function() budgets,
  required Future<SavingsOverview> Function() savings,
}) async {
  final container = ProviderContainer(overrides: [
    currentMonthBudgetProgressProvider.overrideWith((ref) => budgets()),
    savingsOverviewProvider.overrideWith((ref) => savings()),
  ]);
  addTearDown(container.dispose);
  final sub = container.listen(suggestedQuestionsProvider, (_, _) {});
  addTearDown(sub.close);
  await container.read(currentMonthBudgetProgressProvider.future).catchError((_) => <BudgetProgress>[]);
  await container.read(savingsOverviewProvider.future).catchError((_) => _overview());
  return container.read(suggestedQuestionsProvider);
}

void main() {
  test('the furthest-over category leads, then the savings gap', () async {
    final questions = await _settled(
      budgets: () async => [
        _budget('Groceries', pct: 110, over: true),
        _budget('Dining Out', pct: 140, over: true),
      ],
      savings: () async => _overview(gap: '3967.00'),
    );
    expect(questions, hasLength(3));
    expect(questions[0], 'Why is Dining Out over budget?');
    expect(questions[1], startsWith('Where should I cut to close my R'));
    expect(questions[2], genericPennyQuestions.first);
  });

  test('no over-budget category and no gap: the generic questions', () async {
    final questions = await _settled(
      budgets: () async => [_budget('Groceries')],
      savings: () async => _overview(gap: '0.00'),
    );
    expect(questions, genericPennyQuestions);
  });

  test('failing sources are skipped, never failing the row', () async {
    final questions = await _settled(
      budgets: () async => throw Exception('offline'),
      savings: () async => throw Exception('offline'),
    );
    expect(questions, genericPennyQuestions);
  });

  test('while loading, the generic questions show at once', () {
    expect(
      _read(budgets: () => Future.delayed(const Duration(days: 1)), savings: () => Future.delayed(const Duration(days: 1))),
      genericPennyQuestions,
    );
  });
}
