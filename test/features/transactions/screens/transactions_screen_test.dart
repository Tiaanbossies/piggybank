import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/transactions/data/transactions_api.dart';
import 'package:piggybank/features/transactions/models/transaction.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';
import 'package:piggybank/features/transactions/screens/transactions_screen.dart';

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

      expect(find.text('No transactions match this filter.'), findsOneWidget);
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
}
