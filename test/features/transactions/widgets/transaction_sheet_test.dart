import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/accounts/data/accounts_api.dart';
import 'package:piggybank/features/accounts/models/account.dart';
import 'package:piggybank/features/accounts/providers/accounts_provider.dart';
import 'package:piggybank/features/transactions/data/transactions_api.dart';
import 'package:piggybank/features/transactions/models/transaction.dart';
import 'package:piggybank/features/transactions/providers/quick_add_providers.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';
import 'package:piggybank/features/transactions/widgets/transaction_sheet.dart';

import '../../../test_helpers/mocktail_setup.dart';
import '../../../test_helpers/pump_app.dart';

class _MockTransactionsApi extends Mock implements TransactionsApi {}

class _MockAccountsApi extends Mock implements AccountsApi {}

Transaction _tx(String category, {String id = 'x'}) => Transaction(
      id: id,
      accountId: null,
      transactionType: TransactionType.expense,
      category: category,
      description: null,
      amount: Decimal.parse('10'),
      transactionDate: DateTime(2026, 10, 1),
      merchantName: null,
      notes: null,
      accountName: null,
    );

final _cash = Account(
  id: 'acc-cash',
  name: 'Cash',
  accountType: 'cash',
  currency: 'ZAR',
  balance: Decimal.zero,
  isActive: true,
);

/// Stands in for Home: one button that opens the sheet, like its FAB.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: () => showTransactionSheet(context), child: const Text('Open')),
        ),
      );
}

void main() {
  late _MockTransactionsApi mockApi;
  late _MockAccountsApi mockAccountsApi;

  setUpAll(() {
    registerCommonFallbackValues();
    registerFallbackValue(DateTime(2026));
  });

  List<Override> overrides() => [
        transactionsApiProvider.overrideWithValue(mockApi),
        accountsApiProvider.overrideWithValue(mockAccountsApi),
      ];

  void stubCreate() {
    when(() => mockApi.create(
          transactionType: any(named: 'transactionType'),
          category: any(named: 'category'),
          amount: any(named: 'amount'),
          transactionDate: any(named: 'transactionDate'),
          accountId: any(named: 'accountId'),
          merchantName: any(named: 'merchantName'),
          notes: any(named: 'notes'),
        )).thenAnswer((_) async => _tx('Coffee'));
  }

  setUp(() {
    mockApi = _MockTransactionsApi();
    mockAccountsApi = _MockAccountsApi();
    when(() => mockAccountsApi.list(includeInactive: any(named: 'includeInactive'))).thenAnswer((_) async => [_cash]);
    // History the chips rank from: Groceries ×3, Coffee ×2, Fuel ×1.
    when(() => mockApi.list(transactionType: any(named: 'transactionType'), limit: 200)).thenAnswer(
      (_) async => TransactionsPage(total: 6, items: [
        _tx('Fuel', id: '1'),
        _tx('Coffee', id: '2'),
        _tx('Groceries', id: '3'),
        _tx('Coffee', id: '4'),
        _tx('Groceries', id: '5'),
        _tx('Groceries', id: '6'),
      ]),
    );
  });

  Future<void> openSheet(WidgetTester tester) async {
    await pumpApp(tester, const _Host(), overrides: overrides());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('adding focuses Amount straight away', (tester) async {
    await openSheet(tester);

    final amount = tester.widget<EditableText>(
      find.descendant(of: find.widgetWithText(TextField, 'Amount (ZAR)'), matching: find.byType(EditableText)),
    );
    expect(amount.focusNode.hasFocus, isTrue);
  });

  testWidgets('chips are the categories you actually use, most-used first', (tester) async {
    await openSheet(tester);

    final labels = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((chip) => (chip.label as Text).data)
        .toList();
    expect(labels, ['Groceries', 'Coffee', 'Fuel']);
  });

  testWidgets('amount, chip, Save adds it — three taps, no dropdowns', (tester) async {
    stubCreate();
    await openSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Amount (ZAR)'), '38.50');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Coffee'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    verify(() => mockApi.create(
          transactionType: TransactionType.expense,
          category: 'Coffee',
          amount: '38.50',
          transactionDate: any(named: 'transactionDate'),
          accountId: null,
          merchantName: null,
          notes: null,
        )).called(1);
    expect(find.text('Add transaction'), findsNothing); // sheet closed
  });

  testWidgets('Save without a category says so instead of calling the API', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Amount (ZAR)'), '38.50');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a category.'), findsOneWidget);
    verifyNever(() => mockApi.create(
          transactionType: any(named: 'transactionType'),
          category: any(named: 'category'),
          amount: any(named: 'amount'),
          transactionDate: any(named: 'transactionDate'),
          accountId: any(named: 'accountId'),
          merchantName: any(named: 'merchantName'),
          notes: any(named: 'notes'),
        ));
  });

  testWidgets('the account you used last is pre-selected next time', (tester) async {
    stubCreate();
    await openSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Amount (ZAR)'), '20');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Fuel'));
    await tester.tap(find.text('No account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(_Host)));
    expect(container.read(lastUsedAccountProvider), 'acc-cash');

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('No account'), findsNothing);
  });

  testWidgets("accounts failing to load says so, with Retry, instead of hiding the field", (tester) async {
    var calls = 0;
    when(() => mockAccountsApi.list(includeInactive: any(named: 'includeInactive'))).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return [_cash];
    });
    await openSheet(tester);

    expect(find.text("Couldn't load your accounts"), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your accounts"), findsNothing);
    expect(find.text('No account'), findsOneWidget);
  });
}
