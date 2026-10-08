import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/chatbot/providers/chatbot_provider.dart';
import 'package:piggybank/features/savings/data/savings_api.dart';
import 'package:piggybank/features/savings/models/savings.dart';
import 'package:piggybank/features/savings/providers/savings_provider.dart';
import 'package:piggybank/features/savings/screens/policy_screen.dart';
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
  RecurringCostStatus status = RecurringCostStatus.confirmed,
  DateTime? lastSeen,
  bool stillCharged = false,
  String? policyId,
}) =>
    RecurringCost(
      id: id,
      name: name,
      kind: kind,
      monthlyAmount: Decimal.parse(amount),
      status: status,
      decision: decision,
      savedAmount: saved == null ? null : Decimal.parse(saved),
      cutOn: null,
      lastSeenOn: lastSeen,
      stillCharged: stillCharged,
      policyId: policyId,
    );

RecurringCost _suggestion(String id, String name, {String amount = '199.00'}) =>
    _cost(id, name, amount: amount, status: RecurringCostStatus.suggested, lastSeen: DateTime(2026, 9, 28));

/// Longer than the screen's 4s Undo snackbar, so its `closed` future has
/// resolved and the change has been sent.
const _undoWindow = Duration(seconds: 5);

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
    registerFallbackValue(RecurringCostStatus.confirmed);
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
      expect(find.text('R\u00A020\u00A0000,00'), findsOneWidget);
      expect(find.text('Left over each month'), findsOneWidget);
      expect(find.text('R\u00A07\u00A0500,00'), findsOneWidget);
    });

    testWidgets('with a target, leads with the gap', (tester) async {
      when(() => api.overview()).thenAnswer((_) async => _overview(target: _rent, gap: '1500.00'));
      await pump(tester);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Gap R\u00A01\u00A0500,00'), findsOneWidget);
      expect(find.text('Target R\u00A09\u00A0000,00 a month'), findsOneWidget);
    });

    testWidgets('the progress bar says what it measures to a screen reader', (tester) async {
      when(() => api.overview()).thenAnswer((_) async => _overview(target: _rent, gap: '1500.00'));
      await pump(tester);
      final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.semanticsLabel, 'Progress to Rent');
      expect(bar.semanticsValue, endsWith('%'));
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
      expect(find.text('R\u00A0600,00 a month'), findsOneWidget);
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
      expect(find.text('Debit order · Cut, saves R\u00A0450,00'), findsOneWidget);
      expect(find.text('R\u00A0199,00'), findsOneWidget);
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

  group('Suggestions', () {
    void stubStatusUpdate() {
      when(() => api.updateRecurring(any(), status: any(named: 'status')))
          .thenAnswer((_) async => _cost('s1', 'Netflix'));
    }

    testWidgets('sit above the confirmed costs with one-tap actions', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [
            _suggestion('s1', 'Netflix'),
            _suggestion('s2', 'Discovery Insure', amount: '1450.00'),
            _cost('c1', 'Gym', amount: '450.00'),
          ]);
      await pump(tester);

      expect(find.text('Found 2 recurring costs'), findsOneWidget);
      expect(find.text('Subscription · last charged 28 Sep'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Confirm'), findsNWidgets(2));
      expect(find.widgetWithText(TextButton, 'Dismiss'), findsNWidgets(2));
      // The confirmed cost renders below the suggestions.
      final gymY = tester.getTopLeft(find.text('Gym')).dy;
      expect(gymY, greaterThan(tester.getTopLeft(find.text('Discovery Insure')).dy));
    });

    testWidgets('Confirm hides the card, then sends once the Undo window closes', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [_suggestion('s1', 'Netflix')]);
      stubStatusUpdate();
      await pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Found 1 recurring cost'), findsNothing);
      expect(find.text('Confirmed · Netflix'), findsOneWidget);
      verifyNever(() => api.updateRecurring(any(), status: any(named: 'status')));

      await tester.pump(_undoWindow);
      await tester.pumpAndSettle();
      verify(() => api.updateRecurring('s1', status: RecurringCostStatus.confirmed)).called(1);
      // Confirming moves fixed costs, so the overview is refetched too.
      verify(() => api.overview()).called(2);
    });

    testWidgets('Undo puts the card back and sends nothing', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [_suggestion('s1', 'Netflix')]);
      stubStatusUpdate();
      await pump(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('Dismissed · Netflix'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.pump(_undoWindow);
      await tester.pumpAndSettle();

      expect(find.text('Found 1 recurring cost'), findsOneWidget);
      verifyNever(() => api.updateRecurring(any(), status: any(named: 'status')));
    });

    testWidgets('swipe right confirms, swipe left dismisses', (tester) async {
      when(() => api.listRecurring())
          .thenAnswer((_) async => [_suggestion('s1', 'Netflix'), _suggestion('s2', 'Showmax')]);
      stubStatusUpdate();
      await pump(tester);

      await tester.drag(find.byKey(const ValueKey('dismiss-s1')), const Offset(600, 0));
      await tester.pumpAndSettle();
      // The second action closes the first snackbar, which commits it.
      await tester.drag(find.byKey(const ValueKey('dismiss-s2')), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.pump(_undoWindow);
      await tester.pumpAndSettle();

      verify(() => api.updateRecurring('s1', status: RecurringCostStatus.confirmed)).called(1);
      verify(() => api.updateRecurring('s2', status: RecurringCostStatus.dismissed)).called(1);
    });

    testWidgets('a failed send brings the card back with the error', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [_suggestion('s1', 'Netflix')]);
      when(() => api.updateRecurring(any(), status: any(named: 'status')))
          .thenThrow(const ApiError(statusCode: 500, message: 'Server error'));
      await pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      await tester.pump(_undoWindow);
      await tester.pumpAndSettle();

      expect(find.text('Server error'), findsOneWidget);
      expect(find.text('Found 1 recurring cost'), findsOneWidget);
    });

    testWidgets('saving a corrected suggestion confirms it', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [_suggestion('s1', 'NETFLIX.COM')]);
      when(() => api.updateRecurring(
            any(),
            name: any(named: 'name'),
            monthlyAmount: any(named: 'monthlyAmount'),
            kind: any(named: 'kind'),
            status: any(named: 'status'),
            decision: any(named: 'decision'),
            savedAmount: any(named: 'savedAmount'),
          )).thenAnswer((_) async => _cost('s1', 'Netflix'));
      await pump(tester);

      await tester.tap(find.text('NETFLIX.COM'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cost-name')), 'Netflix');
      await tester.tap(find.widgetWithText(FilledButton, 'Save and confirm'));
      await tester.pumpAndSettle();

      verify(() => api.updateRecurring(
            's1',
            name: 'Netflix',
            monthlyAmount: '199',
            kind: RecurringCostKind.subscription,
            status: RecurringCostStatus.confirmed,
            decision: RecurringCostDecision.undecided,
            savedAmount: null,
          )).called(1);
    });

    testWidgets('fit a narrow phone without overflow', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [
            _suggestion('s1', 'Discovery Insure Vehicle Comprehensive Policy', amount: '12450.00'),
          ]);
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        const SavingsPlanScreen(),
        overrides: [savingsApiProvider.overrideWithValue(api)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Find costs'), findsOneWidget);
    });

    testWidgets('a cancelled cost charged again is flagged', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [
            _cost('c1', 'Showmax',
                decision: RecurringCostDecision.cut,
                saved: '199.00',
                lastSeen: DateTime(2026, 10, 2),
                stillCharged: true),
            _cost('c2', 'Gym', decision: RecurringCostDecision.cut, saved: '199.00'),
          ]);
      await pump(tester);

      expect(find.text('Still charged · 2 Oct'), findsOneWidget);
      expect(find.textContaining('Still charged'), findsOneWidget);
    });
  });

  group('Find costs', () {
    testWidgets('runs detection, refetches and says what it found', (tester) async {
      when(() => api.detectRecurring())
          .thenAnswer((_) async => const DetectResult(suggested: 3, linked: 0, updated: 1));
      await pump(tester);

      await tester.tap(find.byKey(const Key('find-costs')));
      await tester.pumpAndSettle();

      verify(() => api.detectRecurring()).called(1);
      expect(find.text('Found 3 new recurring costs to review.'), findsOneWidget);
      verify(() => api.listRecurring()).called(2);
    });

    testWidgets('shows the error when detection fails', (tester) async {
      when(() => api.detectRecurring())
          .thenThrow(const ApiError(statusCode: 429, message: 'Too many requests. Try again in a minute.'));
      await pump(tester);

      await tester.tap(find.byKey(const Key('find-costs')));
      await tester.pumpAndSettle();
      expect(find.text('Too many requests. Try again in a minute.'), findsOneWidget);
    });

    test('detectMessage covers found, linked and nothing new', () {
      expect(detectMessage(const DetectResult(suggested: 1, linked: 0, updated: 0)),
          'Found 1 new recurring cost to review.');
      expect(detectMessage(const DetectResult(suggested: 0, linked: 2, updated: 0)),
          'Matched 2 of your costs to their bank charges.');
      expect(detectMessage(const DetectResult(suggested: 0, linked: 0, updated: 4)), contains('two months'));
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

  group('Insurance costs', () {
    testWidgets('only insurance gets the policy button, worded by whether details exist', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [
            _cost('c1', 'Car insurance', kind: RecurringCostKind.insurance),
            _cost('c2', 'Funeral plan', kind: RecurringCostKind.insurance, policyId: 'p2'),
            _cost('c3', 'Netflix'),
          ]);
      await pump(tester);

      expect(find.byKey(const Key('policy-c1')), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Add policy details'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Policy check'), findsOneWidget);
      expect(find.byKey(const Key('policy-c3')), findsNothing);
    });

    testWidgets('the button opens the policy screen, not the edit sheet', (tester) async {
      when(() => api.listRecurring()).thenAnswer((_) async => [
            _cost('c1', 'Car insurance', kind: RecurringCostKind.insurance),
          ]);
      when(() => api.getPolicy('c1')).thenAnswer((_) async => null);
      await pump(tester);

      await tester.tap(find.byKey(const Key('policy-c1')));
      await tester.pumpAndSettle();

      expect(find.byType(PolicyScreen), findsOneWidget);
      expect(find.byType(RecurringCostSheet), findsNothing);
    });
  });

  testWidgets('"Where should I cut?" leaves the question waiting for Penny', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('where-to-cut')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(SavingsPlanScreen)));
    expect(container.read(chatDraftProvider), whereToCutQuestion);
  });

  group('parseAmount', () {
    test('accepts SA and plain formats, rejects zero and junk', () {
      expect(parseAmount('1 200,50'), Decimal.parse('1200.50'));
      expect(parseAmount('1200.50'), Decimal.parse('1200.50'));
      // An amount copied from the app carries formatZAR's no-break spaces.
      expect(parseAmount('1 200,50'), Decimal.parse('1200.50'));
      expect(parseAmount('0'), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount(''), isNull);
    });
  });
}
