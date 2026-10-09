import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/detection/widgets/review_banner.dart';
import 'package:piggybank/features/transactions/data/transactions_api.dart';
import 'package:piggybank/features/transactions/models/transaction.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';
import 'package:piggybank/features/transactions/screens/transactions_screen.dart';
import 'package:piggybank/shared/widgets/mascot_moment.dart';

import '../../../test_helpers/mocktail_setup.dart';
import '../../../test_helpers/pump_app.dart';

class _MockTransactionsApi extends Mock implements TransactionsApi {}

Transaction _tx({
  required String id,
  required TransactionType type,
  required String category,
  String? merchantName,
  DateTime? date,
  Decimal? amount,
}) =>
    Transaction(
      id: id,
      accountId: null,
      transactionType: type,
      category: category,
      description: null,
      amount: amount ?? Decimal.fromInt(100),
      transactionDate: date ?? DateTime(2026, 8, 20),
      merchantName: merchantName,
      notes: null,
      accountName: null,
    );

/// Stubs `mockApi.list(...)` to behave like a real (filtering) backend: it
/// returns only the items matching whatever `transactionType` was passed to
/// this particular call, mirroring how the real `/transactions/` endpoint
/// filters server-side. This lets a single stub back both the "renders
/// everything" tests and the "chips actually filter" test.
void _stubList(_MockTransactionsApi mockApi, List<Transaction> allItems) {
  when(() => mockApi.list(
        accountId: any(named: 'accountId'),
        transactionType: any(named: 'transactionType'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        category: any(named: 'category'),
        offset: any(named: 'offset'),
      )).thenAnswer((invocation) async {
    final type = invocation.namedArguments[#transactionType] as TransactionType?;
    final filtered = type == null ? allItems : allItems.where((t) => t.transactionType == type).toList();
    return TransactionsPage(total: filtered.length, items: filtered);
  });
}

void main() {
  setUpAll(registerCommonFallbackValues);

  late _MockTransactionsApi mockApi;

  setUp(() {
    mockApi = _MockTransactionsApi();
  });

  group('TransactionsScreen', () {
    // Regression coverage for the 2026-08-25 "always shows empty state" bug.
    // Root cause: AccumulatedTransactionsNotifier's predecessor mutated its
    // own state as a side effect of a widget-build-time `ref.watch`, which
    // Riverpod disallows -- the mutation threw silently, so `accumulated`
    // stayed stuck at `[]` forever regardless of what the (mocked) backend
    // returned, and the screen always rendered "No transactions match this
    // filter." This is the exact widget-level assertion that would have
    // caught it: a non-empty mocked API response must result in the actual
    // transaction rows rendering, not the empty state.
    testWidgets('renders the transaction list when the API returns transactions (2026-08-25 regression)', (tester) async {
      _stubList(mockApi, [
        _tx(id: '1', type: TransactionType.expense, category: 'Groceries', merchantName: 'Woolworths', date: DateTime(2026, 8, 20)),
        _tx(id: '2', type: TransactionType.income, category: 'Salary', merchantName: 'Employer Inc', date: DateTime(2026, 8, 19)),
      ]);

      await pumpApp(
        tester,
        const TransactionsScreen(),
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
      );
      await tester.pumpAndSettle();

      expect(find.text('No transactions match this filter.'), findsNothing);
      expect(find.text('Woolworths'), findsOneWidget);
      expect(find.text('Employer Inc'), findsOneWidget);
    });

    testWidgets('shows the empty state when the API returns zero transactions', (tester) async {
      _stubList(mockApi, []);

      await pumpApp(
        tester,
        const TransactionsScreen(),
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
      );
      await tester.pumpAndSettle();

      // Nothing filtered: a first-run empty list, with Penny welcoming.
      expect(find.text('No transactions yet.'), findsOneWidget);
      expect(find.byType(MascotMoment), findsOneWidget);
    });

    testWidgets('a filter that matches nothing says so, with no mascot', (tester) async {
      _stubList(mockApi, []);

      await pumpApp(
        tester,
        const TransactionsScreen(),
        overrides: [
          transactionsApiProvider.overrideWithValue(mockApi),
          transactionFiltersProvider.overrideWith((ref) => TransactionFiltersNotifier()..setCategory('Fuel')),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('No transactions match this filter.'), findsOneWidget);
      expect(find.byType(MascotMoment), findsNothing);
    });

    testWidgets('groups the transaction list by date', (tester) async {
      _stubList(mockApi, [
        _tx(id: '1', type: TransactionType.expense, category: 'Groceries', merchantName: 'Woolworths', date: DateTime(2026, 8, 20)),
        _tx(id: '2', type: TransactionType.expense, category: 'Fuel', merchantName: 'Shell', date: DateTime(2026, 8, 18)),
      ]);

      await pumpApp(
        tester,
        const TransactionsScreen(),
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
      );
      await tester.pumpAndSettle();

      expect(find.text('20 Aug 2026'), findsOneWidget);
      expect(find.text('18 Aug 2026'), findsOneWidget);
    });

    testWidgets('the Income/Expense/Transfer type filter chips filter the visible list', (tester) async {
      _stubList(mockApi, [
        _tx(id: '1', type: TransactionType.expense, category: 'Groceries', merchantName: 'Woolworths', date: DateTime(2026, 8, 20)),
        _tx(id: '2', type: TransactionType.income, category: 'Salary', merchantName: 'Employer Inc', date: DateTime(2026, 8, 19)),
      ]);

      await pumpApp(
        tester,
        const TransactionsScreen(),
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
      );
      await tester.pumpAndSettle();

      // Both present under the default "All" filter.
      expect(find.text('Woolworths'), findsOneWidget);
      expect(find.text('Employer Inc'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Woolworths'), findsOneWidget);
      expect(find.text('Employer Inc'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
      await tester.pumpAndSettle();

      expect(find.text('Woolworths'), findsNothing);
      expect(find.text('Employer Inc'), findsOneWidget);
    });

    // Regression coverage for QA_PRODUCTION_AUDIT_2026-09-11.md M2 + M3: the
    // non-empty list must render via a lazy builder delegate (not the
    // eagerly-materialized ListView(children:) it used before), and must
    // reserve enough bottom padding to clear the "Add transaction" FAB so a
    // scrolled-to-the-bottom row's amount is never hidden behind it.
    testWidgets('the non-empty transaction list uses a lazy builder delegate with FAB-clearing bottom padding', (tester) async {
      _stubList(mockApi, [
        _tx(id: '1', type: TransactionType.expense, category: 'Groceries', merchantName: 'Woolworths', date: DateTime(2026, 8, 20)),
      ]);

      await pumpApp(
        tester,
        const TransactionsScreen(),
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
      );
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.childrenDelegate, isA<SliverChildBuilderDelegate>());

      final padding = listView.padding;
      expect(padding, isA<EdgeInsets>());
      if (padding is EdgeInsets) {
        expect(padding.bottom, greaterThan(kFloatingActionButtonMargin + 56), // FAB height + its default margin
            reason: 'bottom padding must clear the FloatingActionButton.extended so a scrolled row is never hidden behind it');
      }
    });

    testWidgets('pull-to-refresh triggers a refetch', (tester) async {
      _stubList(mockApi, [
        _tx(id: '1', type: TransactionType.expense, category: 'Groceries', merchantName: 'Woolworths', date: DateTime(2026, 8, 20)),
      ]);

      await pumpApp(
        tester,
        const TransactionsScreen(),
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
      );
      await tester.pumpAndSettle();

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      verify(() => mockApi.list(
            accountId: any(named: 'accountId'),
            transactionType: any(named: 'transactionType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            category: any(named: 'category'),
            offset: any(named: 'offset'),
          )).called(greaterThan(1));
    });
  });

  testWidgets('a failed load offers Retry, and Retry recovers (UX plan item 5)', (tester) async {
    var calls = 0;
    when(() => mockApi.list(
          accountId: any(named: 'accountId'),
          transactionType: any(named: 'transactionType'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          category: any(named: 'category'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const ApiError(statusCode: 0, message: 'Network error. Check your connection and try again.');
      return TransactionsPage(total: 1, items: [
        _tx(id: '1', type: TransactionType.expense, category: 'Groceries', merchantName: 'Woolworths', date: DateTime(2026, 8, 20)),
      ]);
    });

    await pumpApp(tester, const TransactionsScreen(), overrides: [transactionsApiProvider.overrideWithValue(mockApi)]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Network error'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Network error'), findsNothing);
    expect(find.text('Woolworths'), findsOneWidget);
  });

  group('Transactions tab actions (UX rework Step 2)', () {
    Future<void> pumpTab(WidgetTester tester, {int pending = 0}) async {
      _stubList(mockApi, [_tx(id: '1', type: TransactionType.expense, category: 'Groceries', merchantName: 'Woolworths')]);
      await pumpApp(
        tester,
        const TransactionsScreen(),
        overrides: [
          transactionsApiProvider.overrideWithValue(mockApi),
          pendingReviewCountProvider.overrideWith((ref) => pending),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Review shows the real pending count, plus the banner', (tester) async {
      await pumpTab(tester, pending: 3);
      final review = find.byKey(const Key('transactions-review'));
      expect(review, findsOneWidget);
      expect(find.descendant(of: review, matching: find.text('3')), findsOneWidget);
      expect(find.text('3 new transactions to review'), findsOneWidget);
    });

    testWidgets('Review and the banner are hidden when nothing is pending', (tester) async {
      await pumpTab(tester);
      expect(find.byKey(const Key('transactions-review')), findsNothing);
      expect(find.textContaining('to review'), findsNothing);
    });

    testWidgets('Insights is labelled', (tester) async {
      await pumpTab(tester);
      expect(find.byTooltip('Insights'), findsOneWidget);
    });

    testWidgets('the overflow holds Expenses summary, Import and Import history', (tester) async {
      await pumpTab(tester);
      await tester.tap(find.byKey(const Key('transactions-overflow')));
      await tester.pumpAndSettle();
      expect(find.text('Expenses summary'), findsOneWidget);
      expect(find.text('Import CSV / Scan receipt'), findsOneWidget);
      expect(find.text('Import history'), findsOneWidget);
    });

    testWidgets('the Filter chip opens the filter sheet', (tester) async {
      await pumpTab(tester);
      await tester.tap(find.byKey(const Key('transactions-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Clear all filters'), findsOneWidget);
    });
  });
}
