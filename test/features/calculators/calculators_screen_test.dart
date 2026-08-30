import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/calc/loan_calc.dart';
import 'package:piggybank/core/format/money.dart';
import 'package:piggybank/features/calculators/screens/calculators_screen.dart';

import '../../test_helpers/pump_app.dart';

/// Screen-wiring tests only. The underlying math (`calcPmt`,
/// `calcAcceleratedPayoff`, `calcPayoffMonths`, ...) is already covered by
/// `test/core/calc/loan_calc_test.dart` — these tests use the same pure
/// functions as an oracle to compute the expected displayed string, rather
/// than re-deriving loan math, so they only fail if the screen stops wiring
/// input -> calculation -> output correctly.
void main() {
  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.enterText(find.widgetWithText(TextField, label), value);
  }

  group('Loan Calculator tab', () {
    testWidgets('shows the correct monthly payment for known inputs', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      await enter(tester, 'Loan amount (ZAR)', '150000');
      await enter(tester, 'Annual interest rate (%)', '11.5');
      await enter(tester, 'Term (months)', '60');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      final expected = formatZAR(calcPmt(150000, 11.5, 60));
      expect(find.text('Monthly payment'), findsOneWidget);
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('rejects an empty loan amount instead of silently showing R0,00', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      await enter(tester, 'Annual interest rate (%)', '10');
      await enter(tester, 'Term (months)', '12');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a loan amount greater than zero.'), findsOneWidget);
      expect(find.text('Monthly payment'), findsNothing);
      expect(find.text('R 0,00'), findsNothing);
    });

    testWidgets('rejects a negative loan amount', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      await enter(tester, 'Loan amount (ZAR)', '-5000');
      await enter(tester, 'Annual interest rate (%)', '10');
      await enter(tester, 'Term (months)', '12');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a loan amount greater than zero.'), findsOneWidget);
      expect(find.text('Monthly payment'), findsNothing);
    });

    testWidgets('rejects a zero term', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      await enter(tester, 'Loan amount (ZAR)', '10000');
      await enter(tester, 'Annual interest rate (%)', '10');
      await enter(tester, 'Term (months)', '0');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a term greater than zero.'), findsOneWidget);
      expect(find.text('Monthly payment'), findsNothing);
    });

    testWidgets('a later valid calculation clears a previous error', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      await enter(tester, 'Annual interest rate (%)', '10');
      await enter(tester, 'Term (months)', '12');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a loan amount greater than zero.'), findsOneWidget);

      await enter(tester, 'Loan amount (ZAR)', '10000');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a loan amount greater than zero.'), findsNothing);
      expect(find.text('Monthly payment'), findsOneWidget);
    });
  });

  group('Loan Accelerator tab', () {
    testWidgets('shows the correct months saved and interest saved for known inputs', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      await tester.tap(find.text('Loan Accelerator'));
      await tester.pumpAndSettle();

      await enter(tester, 'Outstanding balance (ZAR)', '80000');
      await enter(tester, 'Annual interest rate (%)', '12');
      await enter(tester, 'Remaining term (months)', '48');
      await enter(tester, 'Extra monthly payment (ZAR)', '500');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      final expected = calcAcceleratedPayoff(80000, 12, 48, 500);
      expect(find.text('Interest saved'), findsOneWidget);
      expect(find.text(formatZAR(expected.interestSaved)), findsOneWidget);
      expect(find.text('${expected.monthsSaved.round()} months saved'), findsOneWidget);
    });

    testWidgets('rejects an empty outstanding balance', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      await tester.tap(find.text('Loan Accelerator'));
      await tester.pumpAndSettle();

      await enter(tester, 'Annual interest rate (%)', '12');
      await enter(tester, 'Remaining term (months)', '48');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      expect(find.text('Enter an outstanding balance greater than zero.'), findsOneWidget);
      expect(find.text('Interest saved'), findsNothing);
    });

    testWidgets('rejects a negative outstanding balance', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      await tester.tap(find.text('Loan Accelerator'));
      await tester.pumpAndSettle();

      await enter(tester, 'Outstanding balance (ZAR)', '-100');
      await enter(tester, 'Annual interest rate (%)', '12');
      await enter(tester, 'Remaining term (months)', '48');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      expect(find.text('Enter an outstanding balance greater than zero.'), findsOneWidget);
      expect(find.text('Months saved'), findsNothing);
    });
  });

  group('Navigation between calculator tools', () {
    testWidgets('the segmented control switches between Loan Calculator and Loan Accelerator', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      expect(find.text('Loan amount (ZAR)'), findsOneWidget);
      expect(find.text('Outstanding balance (ZAR)'), findsNothing);

      await tester.tap(find.text('Loan Accelerator'));
      await tester.pumpAndSettle();

      expect(find.text('Outstanding balance (ZAR)'), findsOneWidget);
      expect(find.text('Loan amount (ZAR)'), findsNothing);

      await tester.tap(find.text('Loan Calculator'));
      await tester.pumpAndSettle();

      expect(find.text('Loan amount (ZAR)'), findsOneWidget);
      expect(find.text('Outstanding balance (ZAR)'), findsNothing);
    });

    testWidgets('switching tabs does not carry over a previous error message', (tester) async {
      await pumpApp(tester, const CalculatorsScreen(), useAppTheme: true);

      await enter(tester, 'Annual interest rate (%)', '10');
      await enter(tester, 'Term (months)', '12');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a loan amount greater than zero.'), findsOneWidget);

      await tester.tap(find.text('Loan Accelerator'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a loan amount greater than zero.'), findsNothing);
    });
  });
}
