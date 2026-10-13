import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/liabilities/data/liabilities_api.dart';
import 'package:piggybank/features/liabilities/models/liability.dart';
import 'package:piggybank/features/liabilities/models/liability_payment.dart';
import 'package:piggybank/features/liabilities/providers/liabilities_provider.dart';
import 'package:piggybank/features/liabilities/screens/liabilities_screen.dart';
import 'package:piggybank/features/liabilities/screens/liability_detail_screen.dart';

import '../../../test_helpers/pump_app.dart';

class MockLiabilitiesApi extends Mock implements LiabilitiesApi {}

/// Loans source of truth (plans/loans-source-of-truth.md, D1c-D4i): the
/// server keeps a loan's balance from an anchor, so the app logs only extra
/// payments on a scheduled loan, sends a balance only when it changes, and
/// shows the "check this balance" flag.
void main() {
  setUpAll(() {
    registerFallbackValue(LiabilityType.personalLoan);
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  late MockLiabilitiesApi mockApi;

  setUp(() => mockApi = MockLiabilitiesApi());

  Liability loan({bool needsReview = false}) => Liability(
        id: 'l1',
        liabilityType: LiabilityType.vehicleLoan,
        name: 'Car',
        outstandingAmount: Decimal.parse('168941.95'),
        originalBalance: Decimal.fromInt(200000),
        interestRate: Decimal.fromInt(12),
        termMonths: 60,
        startDate: DateTime(2025, 10, 13),
        anchorDate: DateTime(2026, 10, 13),
        isAmortising: true,
        needsReview: needsReview,
      );

  void stubUpdate() {
    when(() => mockApi.update(
          any(),
          liabilityType: any(named: 'liabilityType'),
          name: any(named: 'name'),
          outstandingAmount: any(named: 'outstandingAmount'),
          balanceAsOf: any(named: 'balanceAsOf'),
          needsReview: any(named: 'needsReview'),
        )).thenAnswer((_) async => loan());
  }

  group('fromJson', () {
    test('reads the anchor fields', () {
      final l = Liability.fromJson({
        'id': 'l1',
        'liability_type': 'vehicle_loan',
        'name': 'Car',
        'outstanding_amount': '168941.95',
        'original_balance': '200000.00',
        'interest_rate': '12.00',
        'term_months': 60,
        'start_date': '2025-10-13',
        'anchor_date': '2026-10-13',
        'is_amortising': true,
        'needs_review': true,
      });
      expect(l.anchorDate, DateTime(2026, 10, 13));
      expect(l.isAmortising, isTrue);
      expect(l.needsReview, isTrue);
    });

    test('defaults safely when an older server leaves the anchor fields out', () {
      final l = Liability.fromJson({
        'id': 'l1',
        'liability_type': 'credit_card',
        'name': 'Card',
        'outstanding_amount': '1000.00',
        'original_balance': null,
        'interest_rate': null,
        'term_months': null,
        'start_date': null,
      });
      expect(l.anchorDate, isNull);
      expect(l.isAmortising, isFalse);
      expect(l.needsReview, isFalse);

      final p = LiabilityPayment.fromJson({
        'id': 'p1',
        'liability_id': 'l1',
        'payment_date': '2026-10-13',
        'amount': '100.00',
        'principal_portion': '100.00',
        'interest_portion': '0.00',
        'notes': null,
        'created_at': '2026-10-13T08:00:00Z',
      });
      expect(p.isExtra, isTrue);
    });
  });

  group('edit sheet', () {
    Future<void> openEdit(WidgetTester tester, Liability existing) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showLiabilitySheet(context, existing: existing),
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

    testWidgets('a rename does not send the balance back as a new statement', (tester) async {
      stubUpdate();
      await openEdit(tester, loan());

      await tester.enterText(find.widgetWithText(TextField, 'Liability name'), 'Polo');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(() => mockApi.update(
            'l1',
            liabilityType: any(named: 'liabilityType'),
            name: 'Polo',
            outstandingAmount: null,
            balanceAsOf: null,
            needsReview: any(named: 'needsReview'),
          )).called(1);
    });

    testWidgets('a changed statement balance is sent with its date', (tester) async {
      stubUpdate();
      await openEdit(tester, loan());

      expect(find.text('Statement date'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Balance on your latest statement (ZAR)'), '150000');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured = verify(() => mockApi.update(
            'l1',
            liabilityType: any(named: 'liabilityType'),
            name: any(named: 'name'),
            outstandingAmount: '150000',
            balanceAsOf: captureAny(named: 'balanceAsOf'),
            needsReview: any(named: 'needsReview'),
          )).captured;
      expect(captured.single, isA<DateTime>());
    });
  });

  group('detail screen', () {
    Future<void> openDetail(WidgetTester tester, Liability l) async {
      when(() => mockApi.list()).thenAnswer((_) async => [l]);
      when(() => mockApi.listPayments(any())).thenAnswer((_) async => []);
      when(() => mockApi.getProgress(any())).thenAnswer((_) async => LiabilityProgress(
            liabilityId: l.id,
            originalBalance: l.originalBalance,
            currentBalance: l.outstandingAmount,
            totalPrincipalPaid: Decimal.zero,
            totalInterestPaid: Decimal.zero,
            percentPaid: Decimal.parse('15.53'),
            paymentCount: 0,
            projectedPayoffDate: null,
          ));
      await pumpApp(
        tester,
        LiabilityDetailScreen(liability: l),
        overrides: [liabilitiesApiProvider.overrideWithValue(mockApi)],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a scheduled loan logs extra payments only', (tester) async {
      await openDetail(tester, loan());

      expect(find.text('Log extra payment'), findsOneWidget);
      await tester.tap(find.text('Log extra payment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('regular instalments are counted automatically'), findsOneWidget);
    });

    testWidgets('a flagged loan shows the review banner, and confirming clears it', (tester) async {
      stubUpdate();
      await openDetail(tester, loan(needsReview: true));

      expect(find.textContaining('Check this balance'), findsOneWidget);
      await tester.tap(find.text('Balance is right'));
      await tester.pumpAndSettle();

      verify(() => mockApi.update(
            'l1',
            liabilityType: any(named: 'liabilityType'),
            name: any(named: 'name'),
            outstandingAmount: any(named: 'outstandingAmount'),
            balanceAsOf: any(named: 'balanceAsOf'),
            needsReview: false,
          )).called(1);
    });

    testWidgets('an unflagged loan shows no banner', (tester) async {
      await openDetail(tester, loan());
      expect(find.textContaining('Check this balance'), findsNothing);
    });
  });
}
