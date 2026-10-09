import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/shared_preferences_provider.dart';
import 'package:piggybank/features/accounts/data/accounts_api.dart';
import 'package:piggybank/features/accounts/providers/accounts_provider.dart';
import 'package:piggybank/features/budgets/data/budgets_api.dart';
import 'package:piggybank/features/budgets/models/budget.dart';
import 'package:piggybank/features/budgets/providers/budgets_provider.dart';
import 'package:piggybank/features/dashboard/screens/dashboard_screen.dart';
import 'package:piggybank/features/detection/data/detection_api.dart';
import 'package:piggybank/features/detection/models/detected_event.dart';
import 'package:piggybank/features/detection/providers/detection_provider.dart';
import 'package:piggybank/features/detection/screens/pending_review_screen.dart';
import 'package:piggybank/features/goals/data/goals_api.dart';
import 'package:piggybank/features/goals/models/goal.dart';
import 'package:piggybank/features/goals/providers/goals_provider.dart';
import 'package:piggybank/features/networth/screens/net_worth_screen.dart';
import 'package:piggybank/features/plan/screens/plan_screen.dart';
import 'package:piggybank/features/savings/data/savings_api.dart';
import 'package:piggybank/features/savings/models/savings.dart';
import 'package:piggybank/features/savings/providers/savings_provider.dart';
import 'package:piggybank/features/summaries/data/summaries_api.dart';
import 'package:piggybank/features/summaries/models/summaries.dart';
import 'package:piggybank/features/summaries/providers/summaries_provider.dart';
import 'package:piggybank/features/transactions/data/transactions_api.dart';
import 'package:piggybank/features/transactions/models/transaction.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';
import 'package:piggybank/features/transactions/widgets/transaction_sheet.dart';
import 'package:piggybank/features/updates/data/updates_api.dart';
import 'package:piggybank/features/updates/models/latest_release.dart';
import 'package:piggybank/shared/widgets/completed_goal_card.dart';
import 'package:piggybank/shared/widgets/hero_metric_card.dart';
import 'package:piggybank/shared/widgets/progress_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/pump_app.dart';

class _MockSummariesApi extends Mock implements SummariesApi {}

class _MockGoalsApi extends Mock implements GoalsApi {}

class _MockBudgetsApi extends Mock implements BudgetsApi {}

class _MockTransactionsApi extends Mock implements TransactionsApi {}

class _MockUpdatesApi extends Mock implements UpdatesApi {}

class _MockDetectionApi extends Mock implements DetectionApi {}

class _MockAccountsApi extends Mock implements AccountsApi {}

class _MockSavingsApi extends Mock implements SavingsApi {}

SavingsOverview _savings({SavingsTarget? target, String gap = '1500.00', bool met = false, String found = '0.00'}) =>
    SavingsOverview(
      target: target,
      basis: OverviewBasis.fullMonths,
      monthsOfData: 2,
      income: Decimal.parse('20000'),
      incomeIsOverride: false,
      fixedCosts: Decimal.parse('2000'),
      everydaySpending: Decimal.parse('10500'),
      leftOver: Decimal.parse('7500'),
      gap: target == null ? null : Decimal.parse(gap),
      targetMet: met,
      savingsFound: Decimal.parse(found),
      confirmedCount: 2,
      suggestedCount: 0,
    );

final _rent = SavingsTarget(
  id: 't1',
  label: 'Rent',
  monthlyAmount: Decimal.fromInt(9000),
  targetDate: null,
  incomeOverride: null,
);

DetectedEvent _detected(String id, {DetectionStatus status = DetectionStatus.pending}) => DetectedEvent(
      id: id,
      sourceType: DetectionSourceType.notification,
      sourceRef: 'za.co.fnb.connect.itest',
      rawText: 'You spent R50.00 at Spar',
      capturedAt: DateTime(2026, 10, 5, 9),
      status: status,
      extractedJson: const {'event_kind': 'transaction', 'amount': '50.00', 'description': 'Spar'},
      eventKind: 'transaction',
      errorReason: null,
    );

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
  GoalStatus status = GoalStatus.active,
}) =>
    Goal(
      id: id,
      name: name,
      targetAmount: Decimal.parse(target.toString()),
      currentAmount: Decimal.parse(current.toString()),
      targetDate: null,
      category: null,
      status: status,
      notes: null,
      progressPct: (current / target) * 100,
    );

BudgetProgress _budget({
  required String id,
  String? category,
  bool overBudget = false,
  double remaining = 500,
  double? pctUsed,
  String? parentBudgetId,
}) =>
    BudgetProgress(
      id: id,
      month: DateTime(2026, 8, 1),
      category: category,
      parentBudgetId: parentBudgetId,
      budgetAmount: Decimal.fromInt(1000),
      spent: Decimal.parse((1000 - remaining).toString()),
      remaining: Decimal.parse(remaining.toString()),
      pctUsed: pctUsed ?? (overBudget ? 120.0 : 50.0),
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

/// The Dashboard is a lazily-built ListView, so sections below the default
/// 800x600 test viewport are never built. Recent transactions sits at the
/// bottom; tests that look for it need a phone-tall surface.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late _MockSummariesApi mockSummariesApi;
  late _MockGoalsApi mockGoalsApi;
  late _MockBudgetsApi mockBudgetsApi;
  late _MockTransactionsApi mockTransactionsApi;
  late _MockUpdatesApi mockUpdatesApi;
  late _MockDetectionApi mockDetectionApi;
  late _MockAccountsApi mockAccountsApi;
  late _MockSavingsApi mockSavingsApi;

  List<Override> overrides() => [
        summariesApiProvider.overrideWithValue(mockSummariesApi),
        goalsApiProvider.overrideWithValue(mockGoalsApi),
        budgetsApiProvider.overrideWithValue(mockBudgetsApi),
        transactionsApiProvider.overrideWithValue(mockTransactionsApi),
        updatesApiProvider.overrideWithValue(mockUpdatesApi),
        detectionApiProvider.overrideWithValue(mockDetectionApi),
        accountsApiProvider.overrideWithValue(mockAccountsApi),
        savingsApiProvider.overrideWithValue(mockSavingsApi),
      ];

  /// Home inside a router, for taps that now switch tabs (UX rework Step 1).
  Future<void> pumpRouted(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/plan', builder: (context, state) => const Text('Plan route')),
        GoRoute(path: '/transactions', builder: (context, state) => const Text('Transactions route')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides()],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }


  /// Stubs every dashboard-consumed API call with a successful, empty-ish
  /// default so each test only has to override what it cares about.
  void stubDefaults({
    NetWorthSummary? netWorth,
    CashflowSummary? cashflow,
    List<Goal>? goals,
    List<BudgetProgress>? budgets,
    List<Transaction>? recentTransactions,
    LatestRelease? latestRelease,
    List<DetectedEvent>? pendingEvents,
    List<Transaction>? todayExpenses,
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
    // The "Spent today" query — the only list() call that filters by type
    // and date, so it never collides with the recent-transactions stub.
    when(() => mockTransactionsApi.list(
          transactionType: TransactionType.expense,
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          limit: 200,
        )).thenAnswer(
      (_) async => TransactionsPage(total: todayExpenses?.length ?? 0, items: todayExpenses ?? const []),
    );
    // Defaults to an empty review queue so the "N to review" card stays
    // hidden for every test that isn't about it.
    when(() => mockDetectionApi.listPending()).thenAnswer((_) async => pendingEvents ?? const []);
    when(() => mockAccountsApi.list(includeInactive: any(named: 'includeInactive'))).thenAnswer((_) async => []);
    // Defaults to a failed overview, which hides the savings card, so
    // tests that aren't about it see Home exactly as before.
    when(() => mockSavingsApi.overview())
        .thenAnswer((_) async => throw const ApiError(statusCode: 404, message: 'not found'));
  }

  setUp(() {
    mockSummariesApi = _MockSummariesApi();
    mockGoalsApi = _MockGoalsApi();
    mockBudgetsApi = _MockBudgetsApi();
    mockTransactionsApi = _MockTransactionsApi();
    mockUpdatesApi = _MockUpdatesApi();
    mockDetectionApi = _MockDetectionApi();
    mockAccountsApi = _MockAccountsApi();
    mockSavingsApi = _MockSavingsApi();
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

  group('Left to spend hero', () {
    HeroMetricCard hero(WidgetTester tester) => tester.widget<HeroMetricCard>(find.byType(HeroMetricCard));

    testWidgets("sums what's left across top-level budgets", (tester) async {
      stubDefaults(budgets: [
        _budget(id: 'b1', category: 'Groceries', remaining: 300),
        _budget(id: 'b2', category: 'Dining Out', remaining: 200),
        // A sub-category is already inside its parent's figure.
        _budget(id: 'b3', category: 'Takeaways', remaining: 50, parentBudgetId: 'b2'),
      ]);
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(hero(tester).label, startsWith('Left to spend · '));
      expect(hero(tester).value, 'R 500,00');
    });

    testWidgets("carries today's spend and the days left under the number", (tester) async {
      stubDefaults(
        budgets: [_budget(id: 'b1', category: 'Groceries')],
        todayExpenses: [
          _transaction(id: 'd1', category: 'Coffee', amount: 38.5),
          _transaction(id: 'd2', category: 'Fuel', amount: 650),
        ],
      );
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(hero(tester).deltaText, startsWith('Spent today R 688,50 · '));
    });

    testWidgets('over budget says by how much, on the red card only', (tester) async {
      stubDefaults(budgets: [_budget(id: 'b1', category: 'Groceries', remaining: -640, overBudget: true)]);
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hero-over-budget')), findsOneWidget);
      expect(find.text('Over by R 640,00'), findsOneWidget);
      expect(find.byType(HeroMetricCard), findsNothing);
    });

    testWidgets("with no budgets, shows the month's spending and invites one", (tester) async {
      stubDefaults(cashflow: _cashflow(income: 8000, expense: 2500));
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(hero(tester).label, startsWith('Spent this month · '));
      expect(hero(tester).value, 'R 2 500,00');
      expect(find.byKey(const Key('hero-set-budget')), findsOneWidget);
    });

    testWidgets('a failed load recovers in place via Retry', (tester) async {
      var calls = 0;
      when(() => mockBudgetsApi.progress(any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return [_budget(id: 'b1', category: 'Groceries')];
      });
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load this month's budgets"), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(hero(tester).label, startsWith('Left to spend · '));
    });

    testWidgets('tapping it opens Plan on Budgets', (tester) async {
      stubDefaults(budgets: [_budget(id: 'b1', category: 'Groceries')]);
      await pumpRouted(tester);
      await tester.tap(find.byKey(const Key('left-to-spend-hero')));
      await tester.pumpAndSettle();

      expect(find.text('Plan route'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.text('Plan route')));
      expect(container.read(planSegmentProvider), PlanSegment.budgets);
    });
  });

  group('Net worth card', () {
    testWidgets('shows the figure and opens the Net worth screen', (tester) async {
      stubDefaults(netWorth: _netWorth(123456.78));
      when(() => mockSummariesApi.netWorthHistory(months: any(named: 'months'))).thenAnswer((_) async => const []);
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('R 123 456,78'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-net-worth')));
      await tester.pumpAndSettle();

      expect(find.byType(NetWorthScreen), findsOneWidget);
      for (final row in ['Accounts', 'Assets', 'Liabilities', 'Loan calculators']) {
        expect(find.text(row), findsOneWidget);
      }
    });
  });

  group('What left Home', () {
    testWidgets('no quick links, Trends card or cashflow strip', (tester) async {
      _useTallView(tester);
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      for (final gone in ['Accounts', 'Assets', 'Liabilities', 'Calculators', 'Trends', 'Income']) {
        expect(find.text(gone), findsNothing, reason: '$gone should have left Home');
      }
    });
  });

  group('Recent row dates', () {
    testWidgets('a transaction from today is labelled Today', (tester) async {
      _useTallView(tester);
      final t = Transaction(
        id: 'now',
        accountId: null,
        transactionType: TransactionType.expense,
        category: 'Coffee',
        description: null,
        amount: Decimal.parse('38.50'),
        transactionDate: DateTime.now(),
        merchantName: 'Seattle',
        notes: null,
        accountName: null,
      );
      stubDefaults(recentTransactions: [t]);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('Coffee · Today'), findsOneWidget);
    });
  });

  group('Needs attention', () {
    testWidgets('an over-budget category beats an in-progress goal', (tester) async {
      stubDefaults(
        goals: [_goal(id: 'g1', name: 'Emergency fund')],
        budgets: [_budget(id: 'b1', category: 'Groceries'), _budget(id: 'b2', category: 'Dining Out', overBudget: true)],
      );
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      final card = tester.widget<ProgressCard>(find.byType(ProgressCard));
      expect(card.title, 'Dining Out');
      expect(card.overBudget, isTrue);
    });

    testWidgets('a budget at 80% or more counts as at risk', (tester) async {
      stubDefaults(
        goals: [_goal(id: 'g1', name: 'Emergency fund')],
        budgets: [_budget(id: 'b1', category: 'Groceries', pctUsed: 85)],
      );
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(tester.widget<ProgressCard>(find.byType(ProgressCard)).title, 'Groceries');
    });

    testWidgets('a calm budget gives way to a goal in progress', (tester) async {
      stubDefaults(
        goals: [_goal(id: 'g1', name: 'Emergency fund')],
        budgets: [_budget(id: 'b1', category: 'Groceries')],
      );
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(tester.widget<ProgressCard>(find.byType(ProgressCard)).title, 'Emergency fund');
    });

    testWidgets('a completed goal is never shown', (tester) async {
      stubDefaults(goals: [
        _goal(id: 'g1', name: 'New laptop', current: 1000, status: GoalStatus.completed),
        _goal(id: 'g2', name: 'House deposit'),
      ]);
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.byType(CompletedGoalCard), findsNothing);
      expect(tester.widget<ProgressCard>(find.byType(ProgressCard)).title, 'House deposit');
    });

    testWidgets('only calm budgets and completed goals: nothing to show', (tester) async {
      stubDefaults(
        goals: [_goal(id: 'g1', name: 'New laptop', current: 1000, status: GoalStatus.completed)],
        budgets: [_budget(id: 'b1', category: 'Groceries')],
      );
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.byType(ProgressCard), findsNothing);
      expect(find.byType(CompletedGoalCard), findsNothing);
    });

    testWidgets('tapping a goal opens Plan on Goals', (tester) async {
      stubDefaults(goals: [_goal(id: 'g1', name: 'Emergency fund')]);
      await pumpRouted(tester);
      await tester.tap(find.byKey(const Key('needs-attention')));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('Plan route')));
      expect(container.read(planSegmentProvider), PlanSegment.goals);
    });
  });

  group('Recent transactions preview', () {
    testWidgets('renders the 5 most recent transactions returned by the API', (tester) async {
      _useTallView(tester);
      final items = List.generate(5, (i) => _transaction(id: 't$i', category: 'Cat$i', amount: (i + 1) * 10));
      stubDefaults(recentTransactions: items);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      for (final t in items) {
        expect(find.textContaining(t.category), findsOneWidget);
      }
      verify(() => mockTransactionsApi.list(limit: 5)).called(1);
    });

    testWidgets('shows an empty message when there are no recent transactions', (tester) async {
      _useTallView(tester);
      stubDefaults(recentTransactions: const []);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('No transactions yet.'), findsOneWidget);
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
      _useTallView(tester);
      stubDefaults(
        netWorth: _netWorth(1000),
        goals: [_goal(id: 'g1', name: 'Holiday')],
        budgets: [_budget(id: 'b1', category: 'Groceries')],
        recentTransactions: [_transaction(id: 't1', category: 'Coffee')],
      );
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('R 1 000,00'), findsOneWidget);
      expect(find.text('Holiday'), findsOneWidget);
      expect(find.textContaining('Coffee'), findsOneWidget);

      // After the refresh, the budgets behind the hero fail; everything else
      // gets fresh data, which proves it was really re-fetched.
      when(() => mockSummariesApi.netWorth()).thenAnswer((_) async => _netWorth(2000));
      when(() => mockBudgetsApi.progress(any())).thenThrow(Exception('budgets boom'));
      when(() => mockGoalsApi.list()).thenAnswer((_) async => [_goal(id: 'g2', name: 'New car')]);
      when(() => mockTransactionsApi.list(limit: any(named: 'limit')))
          .thenAnswer((_) async => TransactionsPage(total: 1, items: [_transaction(id: 't2', category: 'Rent')]));

      // `.show()` only completes once its retract animation runs, which
      // needs pump(); awaiting it directly deadlocks the test.
      unawaited(tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      expect(find.text('R 2 000,00'), findsOneWidget);
      expect(find.text('New car'), findsOneWidget);
      expect(find.textContaining('Rent'), findsOneWidget);
      expect(find.text("Couldn't load this month's budgets"), findsOneWidget);
    });
  });

  group('Review card', () {
    testWidgets('is hidden when nothing is waiting for review', (tester) async {
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.textContaining('to review'), findsNothing);
    });

    testWidgets('counts only pending items, not skipped_invalid ones', (tester) async {
      stubDefaults(pendingEvents: [
        _detected('a'),
        _detected('b'),
        _detected('c', status: DetectionStatus.skippedInvalid),
      ]);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.text('2 new transactions to review'), findsOneWidget);
    });

    testWidgets('stays hidden when detection is unavailable', (tester) async {
      when(() => mockDetectionApi.listPending())
          .thenAnswer((_) async => throw const ApiError(statusCode: 403, message: 'consent required'));

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      expect(find.textContaining('to review'), findsNothing);
      expect(find.textContaining('consent required'), findsNothing);
    });

    testWidgets('tapping it opens the review screen', (tester) async {
      stubDefaults(pendingEvents: [_detected('a')]);

      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 new transaction to review'));
      await tester.pumpAndSettle();

      expect(find.byType(PendingReviewScreen), findsOneWidget);
    });
  });

  group('Quick add', () {
    testWidgets('the Add button opens the add-transaction sheet from Home', (tester) async {
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionSheet), findsOneWidget);
      expect(find.text('Add transaction'), findsOneWidget);
    });
  });

  group('Savings card (cost-cutting item 2)', () {
    testWidgets('hidden when the overview fails to load', (tester) async {
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();
      expect(find.textContaining('Set a savings target'), findsNothing);
      expect(find.textContaining('gap'), findsNothing);
    });

    testWidgets('invites a target when none is set', (tester) async {
      when(() => mockSavingsApi.overview()).thenAnswer((_) async => _savings());
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();
      expect(find.text('Set a savings target'), findsOneWidget);
    });

    testWidgets('shows the gap to the target', (tester) async {
      when(() => mockSavingsApi.overview()).thenAnswer((_) async => _savings(target: _rent));
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();
      expect(find.text('Rent: gap R\u00A01\u00A0500,00'), findsOneWidget);
      expect(find.text('Tap to find costs to cut'), findsOneWidget);
    });

    testWidgets('says when the target is met', (tester) async {
      when(() => mockSavingsApi.overview())
          .thenAnswer((_) async => _savings(target: _rent, gap: '0.00', met: true));
      await pumpApp(tester, const DashboardScreen(), overrides: overrides(), useAppTheme: true);
      await tester.pumpAndSettle();
      expect(find.text('Rent: target met'), findsOneWidget);
    });

    testWidgets('See all switches to the Transactions tab', (tester) async {
      when(() => mockSavingsApi.overview()).thenAnswer((_) async => _savings(target: _rent));
      await pumpRouted(tester);
      await tester.scrollUntilVisible(find.text('See all'), 300);
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.text('Transactions route'), findsOneWidget);
    });

    testWidgets('opens Plan on the Savings segment in one tap', (tester) async {
      when(() => mockSavingsApi.overview()).thenAnswer((_) async => _savings(target: _rent));
      when(() => mockSavingsApi.listRecurring()).thenAnswer((_) async => const []);
      await pumpRouted(tester);

      await tester.tap(find.text('Rent: gap R 1 500,00'));
      await tester.pumpAndSettle();

      expect(find.text('Plan route'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.text('Plan route')));
      expect(container.read(planSegmentProvider), PlanSegment.savings);
    });
  });
}
