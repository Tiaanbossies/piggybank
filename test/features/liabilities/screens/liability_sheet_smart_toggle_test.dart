import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/liabilities/data/liabilities_api.dart';
import 'package:piggybank/features/liabilities/models/liability.dart';
import 'package:piggybank/features/liabilities/providers/liabilities_provider.dart';
import 'package:piggybank/features/liabilities/screens/liabilities_screen.dart';

import '../../../test_helpers/pump_app.dart';

class MockLiabilitiesApi extends Mock implements LiabilitiesApi {}

/// The Add Liability sheet's "Amount owed" / "Loan details" `SegmentedButton`
/// per `liabilities_screen.dart`'s `_LiabilitySheet`: simple mode posts only
/// `outstanding_amount`, loan-detail mode posts `original_balance` +
/// `interest_rate` + `term_months` + `start_date` instead. This is a
/// client-only UI toggle (no separate provider/notifier backs it), so it's
/// exercised end-to-end through the widget.
void main() {
  setUpAll(() {
    registerFallbackValue(LiabilityType.personalLoan);
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  late MockLiabilitiesApi mockApi;

  setUp(() => mockApi = MockLiabilitiesApi());

  Liability liability() => Liability(
        id: 'l1',
        liabilityType: LiabilityType.personalLoan,
        name: 'Loan',
        outstandingAmount: Decimal.fromInt(1000),
        originalBalance: null,
        interestRate: null,
        termMonths: null,
        startDate: null,
      );

  Future<void> pumpSheet(WidgetTester tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showLiabilitySheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      overrides: [liabilitiesApiProvider.overrideWithValue(mockApi)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to "Amount owed" mode, showing only the outstanding-amount field', (tester) async {
    await pumpSheet(tester);

    expect(find.widgetWithText(TextField, 'Outstanding amount (ZAR)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Original loan amount (ZAR)'), findsNothing);
    expect(find.widgetWithText(TextField, 'Annual interest rate (%)'), findsNothing);
    expect(find.widgetWithText(TextField, 'Term (months)'), findsNothing);
  });

  testWidgets('switching to "Loan details" swaps in the loan-param fields and hides the simple amount field',
      (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Loan details'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Outstanding amount (ZAR)'), findsNothing);
    expect(find.widgetWithText(TextField, 'Original loan amount (ZAR)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Annual interest rate (%)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Term (months)'), findsOneWidget);
  });

  testWidgets('simple mode Save posts outstandingAmount and no loan params', (tester) async {
    when(() => mockApi.create(
          liabilityType: any(named: 'liabilityType'),
          name: any(named: 'name'),
          outstandingAmount: any(named: 'outstandingAmount'),
          originalBalance: any(named: 'originalBalance'),
          interestRate: any(named: 'interestRate'),
          termMonths: any(named: 'termMonths'),
          monthlyAmount: any(named: 'monthlyAmount'),
          startDate: any(named: 'startDate'),
        )).thenAnswer((_) async => liability());

    await pumpSheet(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Liability name'), 'Credit card');
    await tester.enterText(find.widgetWithText(TextField, 'Outstanding amount (ZAR)'), '3200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => mockApi.create(
          liabilityType: any(named: 'liabilityType'),
          name: 'Credit card',
          outstandingAmount: '3200',
          originalBalance: null,
          interestRate: null,
          termMonths: null,
          monthlyAmount: null,
          startDate: null,
        )).called(1);
  });

  testWidgets('loan-details mode Save posts loan params and no outstandingAmount', (tester) async {
    when(() => mockApi.create(
          liabilityType: any(named: 'liabilityType'),
          name: any(named: 'name'),
          outstandingAmount: any(named: 'outstandingAmount'),
          originalBalance: any(named: 'originalBalance'),
          interestRate: any(named: 'interestRate'),
          termMonths: any(named: 'termMonths'),
          monthlyAmount: any(named: 'monthlyAmount'),
          startDate: any(named: 'startDate'),
        )).thenAnswer((_) async => liability());

    await pumpSheet(tester);
    await tester.tap(find.text('Loan details'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Liability name'), 'Car loan');
    await tester.enterText(find.widgetWithText(TextField, 'Original loan amount (ZAR)'), '200000');
    await tester.enterText(find.widgetWithText(TextField, 'Annual interest rate (%)'), '11.5');
    await tester.enterText(find.widgetWithText(TextField, 'Term (months)'), '60');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => mockApi.create(
          liabilityType: any(named: 'liabilityType'),
          name: 'Car loan',
          outstandingAmount: null,
          originalBalance: '200000',
          interestRate: '11.5',
          termMonths: 60,
          monthlyAmount: null,
          startDate: any(named: 'startDate'),
        )).called(1);
  });

  testWidgets('editing an existing liability never shows the mode toggle (type is fixed after creation)',
      (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showLiabilitySheet(context, existing: liability()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      overrides: [liabilitiesApiProvider.overrideWithValue(mockApi)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Amount owed'), findsNothing);
    expect(find.text('Loan details'), findsNothing);
    expect(find.widgetWithText(TextField, 'Outstanding amount (ZAR)'), findsOneWidget);
  });
}
