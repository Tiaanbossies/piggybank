import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/summaries/data/summaries_api.dart';
import 'package:piggybank/features/summaries/models/summaries.dart';
import 'package:piggybank/features/summaries/providers/summaries_provider.dart';
import 'package:piggybank/features/trends/screens/trends_screen.dart';
import 'package:piggybank/shared/widgets/hero_metric_card.dart';
import 'package:piggybank/shared/widgets/progress_card.dart';
import 'package:piggybank/shared/widgets/state_views.dart';

import '../../../test_helpers/pump_app.dart';

class _MockSummariesApi extends Mock implements SummariesApi {}

NetWorthSnapshot _snapshot(DateTime date, double value) =>
    NetWorthSnapshot(snapshotDate: date, netWorth: Decimal.parse(value.toString()));

BudgetUsageSummary _usage({double budget = 4000, double spend = 2000}) => BudgetUsageSummary(
      budgetTotal: Decimal.parse(budget.toString()),
      actualSpend: Decimal.parse(spend.toString()),
      remaining: Decimal.parse((budget - spend).toString()),
      percentUsed: budget == 0 ? Decimal.zero : Decimal.parse((spend / budget * 100).toStringAsFixed(2)),
    );

/// Trends stacks a hero card, six month rows and two spending sections, so
/// the default 800x600 test surface can't hold it — sections below the fold
/// are never built and `find.text` legitimately misses them. Give the tests
/// a phone-shaped, phone-height surface instead of scrolling past the
/// assertions they're about to make.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late _MockSummariesApi mockApi;

  List<Override> overrides() => [summariesApiProvider.overrideWithValue(mockApi)];

  /// Successful, populated defaults for every source the screen reads, so
  /// each test only overrides the one it cares about.
  void stubDefaults({
    List<NetWorthSnapshot>? history,
    BudgetUsageSummary? usage,
    List<RecurringExpenseSummary>? recurring,
    List<HighCostExpenseSummary>? highCost,
  }) {
    when(() => mockApi.netWorthHistory(months: any(named: 'months'))).thenAnswer(
      (_) async =>
          history ?? [_snapshot(DateTime(2026, 4, 1), 100000), _snapshot(DateTime(2026, 9, 1), 125000)],
    );
    when(() => mockApi.budgetUsage(month: any(named: 'month'))).thenAnswer((_) async => usage ?? _usage());
    when(() => mockApi.recurringExpenses(month: any(named: 'month'))).thenAnswer(
      (_) async =>
          recurring ??
          [
            RecurringExpenseSummary(
              category: 'Groceries',
              occurrences: 3,
              avgAmount: Decimal.fromInt(1200),
              totalAmount: Decimal.fromInt(3600),
              lastDate: DateTime(2026, 8, 20),
            ),
          ],
    );
    when(() => mockApi.highCostExpenses(month: any(named: 'month'), topN: any(named: 'topN'))).thenAnswer(
      (_) async =>
          highCost ??
          [
            HighCostExpenseSummary(
              category: 'Rent',
              count: 1,
              totalAmount: Decimal.fromInt(9000),
              maxSingleAmount: Decimal.fromInt(9000),
              avgAmount: Decimal.fromInt(9000),
              lastDate: DateTime(2026, 8, 1),
            ),
          ],
    );
  }

  setUp(() {
    mockApi = _MockSummariesApi();
    stubDefaults();
  });

  group('populated state', () {
    testWidgets('renders the net-worth hero, a budget card per month, and both spending sections',
        (tester) async {
      _useTallSurface(tester);
      await pumpApp(tester, const TrendsScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      final hero = tester.widget<HeroMetricCard>(find.byType(HeroMetricCard));
      expect(hero.value, 'R 125 000,00');
      expect(hero.deltaText, contains('+25.0%'));

      // One ProgressCard per month of the trailing window.
      expect(find.byType(ProgressCard), findsNWidgets(trendWindowMonths));

      // Spending-pattern stat strip.
      expect(find.text('Top category'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Largest single'), findsOneWidget);

      // Recurring list.
      await tester.scrollUntilVisible(find.text('Groceries'), 200);
      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets('fans the budget call out once per month of the window', (tester) async {
      _useTallSurface(tester);
      await pumpApp(tester, const TrendsScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      for (final month in trailingMonthKeys()) {
        verify(() => mockApi.budgetUsage(month: month)).called(1);
      }
    });

    testWidgets('does not offer any ask-a-question affordance (that stays the Assistant tab)',
        (tester) async {
      _useTallSurface(tester);
      await pumpApp(tester, const TrendsScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('Ask', findRichText: true), findsNothing);
    });
  });

  group('loading state', () {
    testWidgets('shows progress indicators while every source is in flight', (tester) async {
      _useTallSurface(tester);
      when(() => mockApi.netWorthHistory(months: any(named: 'months')))
          .thenAnswer((_) => Future.delayed(const Duration(seconds: 1), () => <NetWorthSnapshot>[]));

      await pumpApp(tester, const TrendsScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('error state', () {
    testWidgets('shows an InlineError per failing source, leaving the others intact', (tester) async {
      _useTallSurface(tester);
      when(() => mockApi.netWorthHistory(months: any(named: 'months')))
          .thenThrow(const ApiError(statusCode: 500, message: 'History unavailable'));

      await pumpApp(tester, const TrendsScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('History unavailable'), findsOneWidget);
      // Budget adherence still rendered — one failing source does not blank
      // the screen.
      expect(find.byType(ProgressCard), findsNWidgets(trendWindowMonths));
    });

    testWidgets('a failing budget month surfaces as one error, not a crash', (tester) async {
      _useTallSurface(tester);
      when(() => mockApi.budgetUsage(month: any(named: 'month')))
          .thenThrow(const ApiError(statusCode: 500, message: 'Budgets unavailable'));

      await pumpApp(tester, const TrendsScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('Budgets unavailable'), findsOneWidget);
      expect(find.byType(HeroMetricCard), findsOneWidget);
    });
  });

  group('empty states', () {
    testWidgets('no snapshots yet shows the net-worth empty state instead of a hero', (tester) async {
      _useTallSurface(tester);
      stubDefaults(history: const []);

      await pumpApp(tester, const TrendsScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.byType(HeroMetricCard), findsNothing);
      expect(find.text('No net-worth history yet.'), findsOneWidget);
    });

    testWidgets('no budget in any month shows one empty state, not six blank cards', (tester) async {
      _useTallSurface(tester);
      stubDefaults(usage: _usage(budget: 0, spend: 0));

      await pumpApp(tester, const TrendsScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.byType(ProgressCard), findsNothing);
      expect(find.text('No budgets in the last $trendWindowMonths months.'), findsOneWidget);
    });

    testWidgets('no spending this month shows both spending empty states', (tester) async {
      _useTallSurface(tester);
      stubDefaults(recurring: const [], highCost: const []);

      await pumpApp(tester, const TrendsScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('No spending recorded this month.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Nothing recurring yet.'), 200);
      expect(find.text('Nothing recurring yet.'), findsOneWidget);
      expect(find.byType(EmptyState), findsWidgets);
    });
  });
}
