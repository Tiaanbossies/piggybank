import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/savings/data/savings_api.dart';
import 'package:piggybank/features/savings/models/savings.dart';
import 'package:piggybank/features/savings/providers/savings_provider.dart';
import 'package:piggybank/features/savings/screens/savings_plan_screen.dart';

import '../../test_helpers/pump_app.dart';

class _MockSavingsApi extends Mock implements SavingsApi {}

SavingsOverview _overview({
  SavingsTarget? target,
  OverviewBasis basis = OverviewBasis.fullMonths,
  int months = 2,
  String leftOver = '7500.00',
  String? gap,
  bool met = false,
  String found = '0.00',
  bool override = false,
}) =>
    SavingsOverview(
      target: target,
      basis: basis,
      monthsOfData: months,
      income: Decimal.parse('20000'),
      incomeIsOverride: override,
      fixedCosts: Decimal.parse('2000'),
      everydaySpending: Decimal.parse('10500'),
      leftOver: Decimal.parse(leftOver),
      gap: gap == null ? null : Decimal.parse(gap),
      targetMet: met,
      savingsFound: Decimal.parse(found),
      confirmedCount: 0,
      suggestedCount: 0,
    );

final _rent = SavingsTarget(
  id: 't1',
  label: 'Rent',
  monthlyAmount: Decimal.fromInt(9000),
  targetDate: null,
  incomeOverride: null,
);

RecurringCost _cost(
  String id,
  String name, {
  RecurringCostKind kind = RecurringCostKind.subscription,
  RecurringCostDecision decision = RecurringCostDecision.undecided,
  String amount = '199.00',
  String? saved,
}) =>
    RecurringCost(
      id: id,
      name: name,
      kind: kind,
      monthlyAmount: Decimal.parse(amount),
      status: RecurringCostStatus.confirmed,
      decision: decision,
      savedAmount: saved == null ? null : Decimal.parse(saved),
      cutOn: null,
    );

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late _MockSavingsApi api;

  setUpAll(() {
    registerFallbackValue(RecurringCostKind.other);
    registerFallbackValue(RecurringCostDecision.undecided);
  });

  setUp(() {
    api = _MockSavingsApi();
    when(() => api.overview()).thenAnswer((_) async => _overview());
    when(() => api.listRecurring()).thenAnswer((_) async => const []);
  });

  Future<void> pump(WidgetTester tester) async {
    _useTallView(tester);
    await pumpApp(
      tester,
      const SavingsPlanScreen(),
      overrides: [savingsApiProvider.overrideWithValue(api)],
      useAppTheme: true,
    );
    await tester.pumpAndSettle();
  }

  group('Target card', () {
    testWidgets('without a target, invites one and still shows the breakdown', (tester) async {
      await pump(tester);
      expect(find.text('Set a monthly target'), findsOneWidget);
      expect(find.text('R 20 000,00'), findsOneWidget);
      expect(find.text('Left over each month'), findsOneWidget);
      expect(find.text('R 7 500,00'), findsOneWidget);
    });

    testWidgets('with a target, leads with the gap', (tester) async {
      when(() => api.overview()).thenAnswer((_) async => _overview(target: _rent, gap: '1500.00'));
      await pump(tester);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Gap R 1 500,00'), findsOneWidget);
      expect(find.text('Target R 9 000,00 a month'), findsOneWidget);
    });

    testWidgets('says when the target is met', (tester) async {
      when(() => api.overview()).thenAnswer((_) async => _overview(target: _rent, gap: '0.00', met: true));
      await pump(tester);
      expect(find.text('Target met'), findsOneWidget);
    });

    testWidgets('shows savings found once something is cut', (tester) async {
      when(() => api.overview()).thenAnswer((_) async => _overview(target: _rent, gap: '900.00', found: '600.00'));
      await pump(tester);
      expect(find.text('Savings found so far'), findsOneWidget);
      expect(find.text('R 600,00 a month'), findsOneWidget);
    });

    testWidgets('marks a typed-in income', (tester) async {
      when(() => api.overview()).thenAnswer((_) async => _overview(override: true));
      await pump(tester);
      expect(find.text('Income (your figure)'), findsOneWidget);
    });

    testWidgets('a failed load recovers via Retry', (tester) async {
      var calls = 0;
      when(() => api.overview()).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const ApiError(statusCode: 500, message: 'Server error');
        return _overview();
      });
      await pump(tester);
      expect(find.text('Server error'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Server error'), findsNothing);
      expect(find.text('Left over each month'), findsOneWidget);
    });
  });

  group('basisNote', () {
    test('is honest about thin data', () {
      expect(basisNote(_overview(basis: OverviewBasis.monthToDate, months: 0)), contains('this month so far'));
      expect(basisNote(_overview(months: 1)), contains("last month's"));
      expect(basisNote(_overview(months: 3)), 'Averaged over your last 3 months of transactions.');
    });
  });

  group('Recurring costs', () {
    testWidgets('empty list explains what to add', (tester) async {
      await pump(tester);
      expect(find.text('No recurring costs yet.'), findsOneWidget);
    });

    testWidgets('rows show type, decision and amount', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [
            _cost('c1', 'Showmax', decision: RecurringCostDecision.cutCandidate),
            _cost('c2', 'Gym',
                kind: RecurringCostKind.debitOrder,
                decision: RecurringCostDecision.cut,
                amount: '450.00',
                saved: '450.00'),
          ]);
      await pump(tester);
      expect(find.text('Showmax'), findsOneWidget);
      expect(find.text('Subscription · Maybe cut'), findsOneWidget);
      expect(find.text('Debit order · Cut, saves R 450,00'), findsOneWidget);
      expect(find.text('R 199,00'), findsOneWidget);
    });

    testWidgets('adding a cost validates, parses SA amounts and refreshes', (tester) async {
      when(() => api.createRecurring(
            name: any(named: 'name'),
            monthlyAmount: any(named: 'monthlyAmount'),
            kind: any(named: 'kind'),
            decision: any(named: 'decision'),
            savedAmount: any(named: 'savedAmount'),
          )).thenAnswer((_) async => _cost('c9', 'Car insurance'));
      await pump(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add cost'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('cost-name')), 'Car insurance');
      await tester.enterText(find.byKey(const Key('cost-amount')), '1 200,50');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      verify(() => api.createRecurring(
            name: 'Car insurance',
            monthlyAmount: '1200.5',
            kind: RecurringCostKind.subscription,
            decision: RecurringCostDecision.undecided,
            savedAmount: null,
          )).called(1);
      expect(find.byType(RecurringCostSheet), findsNothing);
      // The overview is refetched after the write, not just the list.
      verify(() => api.overview()).called(2);
    });

    testWidgets('marking a cost cut pre-fills the whole amount as the saving', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [_cost('c1', 'Gym', amount: '450.00')]);
      when(() => api.updateRecurring(
            any(),
            name: any(named: 'name'),
            monthlyAmount: any(named: 'monthlyAmount'),
            kind: any(named: 'kind'),
            decision: any(named: 'decision'),
            savedAmount: any(named: 'savedAmount'),
          )).thenAnswer((_) async => _cost('c1', 'Gym', amount: '450.00', decision: RecurringCostDecision.cut));
      await pump(tester);

      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cut'));
      await tester.pumpAndSettle();

      final saved = tester.widget<TextField>(find.byKey(const Key('cost-saved')));
      expect(saved.controller!.text, '450');

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      verify(() => api.updateRecurring(
            'c1',
            name: 'Gym',
            monthlyAmount: '450',
            kind: RecurringCostKind.subscription,
            decision: RecurringCostDecision.cut,
            savedAmount: '450',
          )).called(1);
    });

    testWidgets('a saving larger than the cost is refused before sending', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [_cost('c1', 'Gym', amount: '450.00')]);
      await pump(tester);

      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cut'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cost-saved')), '500');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text("The saving can't be more than the cost."), findsOneWidget);
      verifyNever(() => api.updateRecurring(
            any(),
            name: any(named: 'name'),
            monthlyAmount: any(named: 'monthlyAmount'),
            kind: any(named: 'kind'),
            decision: any(named: 'decision'),
            savedAmount: any(named: 'savedAmount'),
          ));
    });
  });

  group('Target sheet', () {
    testWidgets('validates, then saves amount and label', (tester) async {
      when(() => api.putTarget(
            monthlyAmount: any(named: 'monthlyAmount'),
            label: any(named: 'label'),
            targetDate: any(named: 'targetDate'),
            incomeOverride: any(named: 'incomeOverride'),
          )).thenAnswer((_) async => _rent);
      await pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Set target'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the amount you need each month.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('target-amount')), '9000');
      await tester.enterText(find.byKey(const Key('target-label')), 'Rent');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      verify(() => api.putTarget(monthlyAmount: '9000', label: 'Rent', targetDate: null, incomeOverride: null))
          .called(1);
      expect(find.byType(TargetSheet), findsNothing);
    });
  });

  group('parseAmount', () {
    test('accepts SA and plain formats, rejects zero and junk', () {
      expect(parseAmount('1 200,50'), Decimal.parse('1200.50'));
      expect(parseAmount('1200.50'), Decimal.parse('1200.50'));
      expect(parseAmount('0'), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount(''), isNull);
    });
  });
}
