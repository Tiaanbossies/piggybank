import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/features/budgets/data/budgets_api.dart';
import 'package:piggybank/features/budgets/models/budget.dart';
import 'package:piggybank/features/budgets/providers/budgets_provider.dart';
import 'package:piggybank/features/dashboard/screens/dashboard_screen.dart';
import 'package:piggybank/features/goals/data/goals_api.dart';
import 'package:piggybank/features/goals/models/goal.dart';
import 'package:piggybank/features/goals/providers/goals_provider.dart';
import 'package:piggybank/features/summaries/data/summaries_api.dart';
import 'package:piggybank/features/summaries/models/summaries.dart';
import 'package:piggybank/features/summaries/providers/summaries_provider.dart';
import 'package:piggybank/features/transactions/data/transactions_api.dart';
import 'package:piggybank/features/transactions/models/transaction.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';
import 'package:piggybank/features/trends/screens/trends_screen.dart';
import 'package:piggybank/features/updates/data/updates_api.dart';
import 'package:piggybank/features/updates/models/latest_release.dart';
import 'package:piggybank/shared/widgets/hero_metric_card.dart';
import 'package:piggybank/shared/widgets/progress_card.dart';

import '../../test_helpers/pump_app.dart';

class _MockSummariesApi extends Mock implements SummariesApi {}

class _MockGoalsApi extends Mock implements GoalsApi {}

class _MockBudgetsApi extends Mock implements BudgetsApi {}

class _MockTransactionsApi extends Mock implements TransactionsApi {}

class _MockUpdatesApi extends Mock implements UpdatesApi {}

NetWorthSummary _netWorth(double value) => NetWorthSummary(
      totalAssets: Decimal.parse(value.toString()),
      liabilitiesTotal: Decimal.zero,
      netWorth: Decimal.parse(value.toString()),
    );

CashflowSummary _cashflow({required double income, required double expense}) => CashflowSummary(
      incomeTotal: Decimal.parse(income.toString()),
      expenseTotal: Decimal.parse(expense.toString()),
      netCashflow: Decimal.parse((income - expense).toString()),
    );

Goal _goal({
  required String id,
  required String name,
  double target = 1000,
  double current = 250,
}) =>
    Goal(
      id: id,
      name: name,
      targetAmount: Decimal.parse(target.toString()),
      currentAmount: Decimal.parse(current.toString()),
      targetDate: null,
      category: null,
      status: GoalStatus.active,
      notes: null,
      progressPct: (current / target) * 100,
    );

BudgetProgress _budget({
  required String id,
  String? category,
  bool overBudget = false,
}) =>
    BudgetProgress(
      id: id,
      month: DateTime(2026, 8, 1),
      category: category,
      parentBudgetId: null,
      budgetAmount: Decimal.fromInt(1000),
      spent: Decimal.fromInt(500),
      remaining: Decimal.fromInt(500),
      pctUsed: overBudget ? 120.0 : 50.0,
      overBudget: overBudget,
      children: const [],
    );

Transaction _transaction({
  required String id,
  required String category,
  double amount = 100,
  TransactionType type = TransactionType.expense,
}) =>
    Transaction(
      id: id,
      accountId: null,
      transactionType: type,
      category: category,
      description: null,
      amount: Decimal.parse(amount.toString()),
      transactionDate: DateTime(2026, 8, 1),
      // Distinct from `category` on purpose: GroupRow renders merchantName
      // as the title and category as the subtitle, and if the two strings
      // are equal the same text appears twice in the tree, which breaks
      // `findsOneWidget` lookups by category name below.
      merchantName: 'Merchant-$id',
      notes: null,
      accountName: null,
    );

void main() {
  late _MockSummariesApi mockSummariesApi;
  late _MockGoalsApi mockGoalsApi;
  late _MockBudgetsApi mockBudgetsApi;
  late _MockTransactionsApi mockTransactionsApi;
  late _MockUpdatesApi mockUpdatesApi;

  List<Override> overrides() => [
        summariesApiProvider.overrideWithValue(mockSummariesApi),
        goalsApiProvider.overrideWithValue(mockGoalsApi),
        budgetsApiProvider.overrideWithValue(mockBudgetsApi),
        transactionsApiProvider.overrideWithValue(mockTransactionsApi),
        updatesApiProvider.overrideWithValue(mockUpdatesApi),
      ];

  /// Stubs every dashboard-consumed API call with a successful, empty-ish
  /// default so each test only has to override what it cares about.
  void stubDefaults({
    NetWorthSummary? netWorth,
    CashflowSummary? cashflow,
    List<Goal>? goals,
    List<BudgetProgress>? budgets,
    List<Transaction>? recentTransactions,
    LatestRelease? latestRelease,
  }) {
    when(() => mockSummariesApi.netWorth()).thenAnswer((_) async => netWorth ?? _netWorth(10000));
    when(() => mockSummariesApi.cashflow())
        .thenAnswer((_) async => cashflow ?? _cashflow(income: 5000, expense: 3000));
    when(() => mockGoalsApi.list()).thenAnswer((_) async => goals ?? const []);
    when(() => mockBudgetsApi.progress(any())).thenAnswer((_) async => budgets ?? const []);
    when(() => mockTransactionsApi.list(limit: any(named: 'limit'))).thenAnswer(
      (_) async => TransactionsPage(total: recentTransactions?.length ?? 0, items: recentTransactions ?? const []),
    );
    // Defaults to "no release published yet" so pre-existing tests that
    // don't care about the update banner never see it.
    when(() => mockUpdatesApi.latest()).thenAnswer((_) async => latestRelease);
  }

  setUp(() {
    mockSummariesApi = _MockSummariesApi();
    mockGoalsApi = _MockGoalsApi();
    mockBudgetsApi = _MockBudgetsApi();
    mockTransactionsApi = _MockTransactionsApi();
    mockUpdatesApi = _MockUpdatesApi();
    // This install's own build number, as `about_screen.dart` reads it via
    // the same `PackageInfo.fromPlatform()` call the update banner uses.
    PackageInfo.setMockInitialValues(
      appName: 'Piggybank',
      packageName: 'za.co.fynboscreative.piggybank',
      version: '1.3.0',
      buildNumber: '41',
      buildSignature: '',
    );
    stubDefaults();
  });

  group('Net worth hero', () {
    testWidgets('renders the figure from the mocked net-worth summary', (tester) async {
      stubDefaults(netWorth: _netWorth(123456.78));

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      final hero = tester.widget<HeroMetricCard>(find.byType(HeroMetricCard));
      expect(hero.label, 'Net worth');
      expect(hero.value, 'R 123 456,78');
    });
  });

  group('Cashflow stat strip', () {
    testWidgets('shows income and expense totals for this month', (tester) async {
      stubDefaults(cashflow: _cashflow(income: 8000, expense: 2500));

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('R 8 000,00'), findsOneWidget);
      expect(find.text('R 2 500,00'), findsOneWidget);
    });
  });

  group('Progress block (goal-or-budget fallback)', () {
    testWidgets('shows the goal when a goal exists, even if a budget also exists', (tester) async {
      stubDefaults(
        goals: [_goal(id: 'g1', name: 'Emergency fund')],
        budgets: [_budget(id: 'b1', category: 'Groceries')],
      );

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.byType(ProgressCard), findsOneWidget);
      final card = tester.widget<ProgressCard>(find.byType(ProgressCard));
      expect(card.title, 'Emergency fund');
    });

    testWidgets('falls back to the budget when no goal exists', (tester) async {
      stubDefaults(goals: const [], budgets: [_budget(id: 'b1', category: 'Groceries')]);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.byType(ProgressCard), findsOneWidget);
      final card = tester.widget<ProgressCard>(find.byType(ProgressCard));
      expect(card.title, 'Groceries');
    });

    testWidgets('shows nothing when neither a goal nor a budget exists', (tester) async {
      stubDefaults(goals: const [], budgets: const []);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.byType(ProgressCard), findsNothing);
    });
  });

  group('Recent transactions preview', () {
    testWidgets('renders the 5 most recent transactions returned by the API', (tester) async {
      final items = List.generate(5, (i) => _transaction(id: 't$i', category: 'Cat$i', amount: (i + 1) * 10));
      stubDefaults(recentTransactions: items);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      for (final t in items) {
        expect(find.text(t.category), findsOneWidget);
      }
      verify(() => mockTransactionsApi.list(limit: 5)).called(1);
    });

    testWidgets('shows an empty message when there are no recent transactions', (tester) async {
      stubDefaults(recentTransactions: const []);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('No transactions yet.'), findsOneWidget);
    });
  });

  group('Trends entry point', () {
    testWidgets('renders a Trends row that pushes the Trends screen (no new nav tab)', (tester) async {
      // The pushed screen fetches on mount; stub its sources so the
      // navigation assertion isn't racing an unstubbed call.
      when(() => mockSummariesApi.netWorthHistory(months: any(named: 'months')))
          .thenAnswer((_) async => const []);
      when(() => mockSummariesApi.budgetUsage(month: any(named: 'month')))
          .thenAnswer((_) async => BudgetUsageSummary.empty);
      when(() => mockSummariesApi.recurringExpenses(month: any(named: 'month')))
          .thenAnswer((_) async => const []);
      when(() => mockSummariesApi.highCostExpenses(month: any(named: 'month'), topN: any(named: 'topN')))
          .thenAnswer((_) async => const []);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('Trends'), findsOneWidget);

      await tester.tap(find.text('Trends'));
      await tester.pumpAndSettle();

      expect(find.byType(TrendsScreen), findsOneWidget);
    });
  });

  group('Update banner', () {
    LatestRelease release({required String buildNumber}) => LatestRelease(
          version: '1.4.0',
          buildNumber: buildNumber,
          filename: 'piggybank-1.4.0.apk',
          publishedAt: '2026-09-13T12:00:00Z',
          downloadUrl: 'http://tiaanbossies-h81m-ds2.tail886b94.ts.net/downloads/piggybank-1.4.0.apk',
        );

    testWidgets('shows when a newer build is published', (tester) async {
      stubDefaults(latestRelease: release(buildNumber: '42'));

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Version 1.4.0 is ready to download.'), findsOneWidget);
    });

    testWidgets('stays hidden when the current build is already up to date', (tester) async {
      stubDefaults(latestRelease: release(buildNumber: '41'));

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('stays hidden when no release has ever been published', (tester) async {
      stubDefaults();

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('the close button dismisses it for the rest of this session', (tester) async {
      stubDefaults(latestRelease: release(buildNumber: '42'));

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);
    });
  });

  group('Pull-to-refresh', () {
    testWidgets(
        'reloads every section independently: one failing section does not block the others',
        (tester) async {
      // This test asserts on the hero (top of the list) and the recent-
      // transactions preview (bottom) in the same pass. Since the Trends
      // entry row was added the two no longer both fit inside the default
      // 800x600 surface plus its cache extent, and the bottom section is
      // simply never built. Give it a phone-height surface rather than
      // scrolling, which would push the hero out of the tree instead.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Initial successful load for every section.
      stubDefaults(
        netWorth: _netWorth(1000),
        goals: [_goal(id: 'g1', name: 'Holiday')],
        recentTransactions: [_transaction(id: 't1', category: 'Coffee')],
      );

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(tester.widget<HeroMetricCard>(find.byType(HeroMetricCard)).value, 'R 1 000,00');
      expect(find.text('Holiday'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);

      // Re-stub for the post-refresh fetch: cashflow now fails, but every
      // other section gets fresh, different data so we can prove it was
      // actually re-fetched (not just left showing stale state).
      when(() => mockSummariesApi.netWorth()).thenAnswer((_) async => _netWorth(2000));
      when(() => mockSummariesApi.cashflow()).thenThrow(Exception('cashflow boom'));
      when(() => mockGoalsApi.list()).thenAnswer((_) async => [_goal(id: 'g2', name: 'New car')]);
      when(() => mockTransactionsApi.list(limit: any(named: 'limit')))
          .thenAnswer((_) async => TransactionsPage(total: 1, items: [_transaction(id: 't2', category: 'Rent')]));

      // Trigger pull-to-refresh the same way a user gesture would, via the
      // RefreshIndicator's own public API.
      //
      // Root cause of an earlier hang here, isolated this step: `.show()`'s
      // returned Future only completes once the indicator's own retract
      // animation finishes, and that animation only advances via
      // `tester.pump()` — it is driven by `SchedulerBinding`/`Ticker`
      // callbacks, not by fake-async time elapsing on its own. `await`ing
      // `.show()` directly therefore deadlocks the test: the single test
      // isolate is blocked waiting on a Future that can only resolve via a
      // `pump()` call the test body never reaches. This is unrelated to
      // `cashflow()` being stubbed to throw — it reproduces on the very
      // first pull-to-refresh call regardless of stubbing. Fix (standard
      // Flutter test idiom, matches `flutter/packages/flutter/test/material/
      // refresh_indicator_test.dart`): call `.show()` WITHOUT awaiting it,
      // then pump frames to drive the animation and let the microtask queue
      // (mocktail's `thenAnswer`/`thenThrow`, no real delay) resolve.
      unawaited(tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // Sections independent of cashflow reloaded successfully with fresh data.
      expect(tester.widget<HeroMetricCard>(find.byType(HeroMetricCard)).value, 'R 2 000,00');
      expect(find.text('New car'), findsOneWidget);
      expect(find.text('Holiday'), findsNothing);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);

      // The cashflow section itself fails silently (SizedBox.shrink on
      // error) rather than crashing the rest of the page.
      expect(find.text('Income'), findsNothing);
      expect(find.text('Expenses'), findsNothing);
      expect(find.byType(HeroMetricCard), findsOneWidget);
    });
  });
}
