import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/accounts/models/account.dart';
import 'package:piggybank/features/accounts/screens/account_detail_screen.dart';
import 'package:piggybank/features/transactions/data/transactions_api.dart';
import 'package:piggybank/features/transactions/models/transaction.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';

import '../../../test_helpers/pump_app.dart';

class _MockTransactionsApi extends Mock implements TransactionsApi {}

void main() {
  late Account testAccount;
  late _MockTransactionsApi mockApi;

  setUp(() {
    testAccount = Account(
      id: 'acc-123',
      name: 'Test Account',
      accountType: 'bank',
      currency: 'ZAR',
      balance: Decimal.fromInt(5000),
      isActive: true,
      institutionName: 'Test Bank',
    );
    mockApi = _MockTransactionsApi();
  });

  group('AccountDetailScreen', () {
    testWidgets('shows account balance, type, institution, currency read-only', (tester) async {
      when(() => mockApi.list(accountId: any(named: 'accountId'), limit: any(named: 'limit')))
          .thenAnswer((_) async => const TransactionsPage(total: 0, items: []));

      await pumpApp(
        tester,
        AccountDetailScreen(account: testAccount),
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Account'), findsOneWidget);
      expect(find.text('R 5 000,00'), findsOneWidget);
      expect(find.text('bank'), findsOneWidget);
      expect(find.text('Test Bank'), findsOneWidget);
      expect(find.text('ZAR'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      // Read-only: no editable TextField on this screen.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows an empty state when the account has no transactions', (tester) async {
      when(() => mockApi.list(accountId: any(named: 'accountId'), limit: any(named: 'limit')))
          .thenAnswer((_) async => const TransactionsPage(total: 0, items: []));

      await pumpApp(
        tester,
        AccountDetailScreen(account: testAccount),
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('No transactions yet.'), findsOneWidget);
    });

    testWidgets('lists transactions scoped to this account', (tester) async {
      when(() => mockApi.list(accountId: any(named: 'accountId'), limit: any(named: 'limit'))).thenAnswer(
        (_) async => TransactionsPage(
          total: 1,
          items: [
            Transaction(
              id: 't1',
              accountId: 'acc-123',
              transactionType: TransactionType.expense,
              category: 'Groceries',
              description: null,
              amount: Decimal.fromInt(200),
              transactionDate: DateTime(2026, 5, 1),
              merchantName: 'Woolworths',
              notes: null,
              accountName: 'Test Account',
            ),
          ],
        ),
      );

      await pumpApp(
        tester,
        AccountDetailScreen(account: testAccount),
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Woolworths'), findsOneWidget);
      verify(() => mockApi.list(accountId: 'acc-123', limit: 20)).called(1);
    });
  });
}
