import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/theme/app_tokens.dart';
import 'package:piggybank/features/budgets/data/budgets_api.dart';
import 'package:piggybank/features/budgets/models/budget.dart';
import 'package:piggybank/features/budgets/providers/budgets_provider.dart';
import 'package:piggybank/features/goals/data/goals_api.dart';
import 'package:piggybank/features/goals/models/goal.dart';
import 'package:piggybank/features/goals/providers/goals_provider.dart';
import 'package:piggybank/features/plan/screens/plan_screen.dart';
import 'package:piggybank/features/savings/data/savings_api.dart';
import 'package:piggybank/features/savings/providers/savings_provider.dart';
import 'package:piggybank/shared/widgets/completed_goal_card.dart';

import '../../test_helpers/pump_app.dart';

class _MockBudgetsApi extends Mock implements BudgetsApi {}

class _MockGoalsApi extends Mock implements GoalsApi {}

class _MockSavingsApi extends Mock implements SavingsApi {}

BudgetProgress _budget(String id, {required int spent, int amount = 1000}) => BudgetProgress(
      id: id,
      month: DateTime(2026, 10),
      category: id == 'b1' ? 'Groceries' : 'Dining Out',
      parentBudgetId: null,
      budgetAmount: Decimal.fromInt(amount),
      spent: Decimal.fromInt(spent),
      remaining: Decimal.fromInt(amount - spent),
      pctUsed: spent / amount * 100,
      overBudget: spent > amount,
      children: const [],
    );

Goal _goal(String id, String name, {required bool done}) => Goal(
      id: id,
      name: name,
      targetAmount: Decimal.fromInt(10000),
      currentAmount: Decimal.fromInt(done ? 10000 : 4000),
      targetDate: null,
      category: null,
      status: done ? GoalStatus.completed : GoalStatus.active,
      notes: null,
      progressPct: done ? 100 : 40,
    );

const _light = AppTokens.light;

void main() {
  late _MockBudgetsApi budgets;
  late _MockGoalsApi goals;
  late _MockSavingsApi savings;
  late List<Object?> haptics;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    budgets = _MockBudgetsApi();
    goals = _MockGoalsApi();
    savings = _MockSavingsApi();
    when(() => budgets.progress(any())).thenAnswer((_) async => [
          _budget('b1', spent: 840),
          _budget('b2', spent: 1050),
        ]);
    when(() => budgets.list()).thenAnswer((_) async => const []);
    when(() => goals.list()).thenAnswer((_) async => [
          _goal('g1', 'Holiday', done: false),
          _goal('g2', 'Emergency fund', done: true),
        ]);
    when(() => savings.overview()).thenThrow(Exception('not needed'));
    when(() => savings.listRecurring()).thenAnswer((_) async => const []);
  });

  void recordHaptics(WidgetTester tester) {
    haptics = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  Future<void> pumpPlan(WidgetTester tester, {PlanSegment? start, bool reduced = false}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: const PlanScreen(),
        ),
      ),
      overrides: [
        budgetsApiProvider.overrideWithValue(budgets),
        goalsApiProvider.overrideWithValue(goals),
        savingsApiProvider.overrideWithValue(savings),
        if (start != null) planSegmentProvider.overrideWith((ref) => start),
      ],
      useAppTheme: true,
    );
    await tester.pumpAndSettle();
  }

  double slideX(WidgetTester tester) =>
      tester.widget<Transform>(find.byKey(const Key('month-slide'))).transform.getTranslation().x;

  double slideOpacity(WidgetTester tester) => tester
      .widget<Opacity>(find.ancestor(of: find.byKey(const Key('month-slide')), matching: find.byType(Opacity)).first)
      .opacity;

  Color barOf(WidgetTester tester, String key) => tester
      .widget<LinearProgressIndicator>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(LinearProgressIndicator)),
      )
      .color!;

  group('Plan shell (M25)', () {
    testWidgets('a segment switch ticks once and the thumb slides on a spring', (tester) async {
      await pumpPlan(tester);
      recordHaptics(tester);
      final start = tester.getTopLeft(find.byKey(const Key('segment-thumb'))).dx;

      await tester.tap(find.byKey(const Key('segment-Goals')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getTopLeft(find.byKey(const Key('segment-thumb'))).dx;
      await tester.pumpAndSettle();
      final end = tester.getTopLeft(find.byKey(const Key('segment-thumb'))).dx;

      expect(haptics, ['HapticFeedbackType.selectionClick']);
      expect(mid, inExclusiveRange(start, end));
      // Tapping the open segment does nothing.
      await tester.tap(find.byKey(const Key('segment-Goals')));
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1));
    });

    testWidgets('reduced motion: the thumb cuts across', (tester) async {
      await pumpPlan(tester, reduced: true);
      await tester.tap(find.byKey(const Key('segment-Savings')));
      await tester.pump();
      final x = tester.getTopLeft(find.byKey(const Key('segment-thumb'))).dx;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const Key('segment-thumb'))).dx, x);
    });
  });

  group('Month change (M26)', () {
    testWidgets('next month arrives from the right with one tick, previous from the left', (tester) async {
      await pumpPlan(tester);
      recordHaptics(tester);

      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(slideX(tester), greaterThan(0));
      expect(slideOpacity(tester), lessThan(1));
      await tester.pumpAndSettle();
      expect(slideX(tester), 0);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(slideX(tester), lessThan(0));
      await tester.pumpAndSettle();

      expect(haptics, ['HapticFeedbackType.selectionClick', 'HapticFeedbackType.selectionClick']);
    });

    testWidgets('reduced motion: a 150 ms crossfade, no slide', (tester) async {
      await pumpPlan(tester, reduced: true);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(slideX(tester), 0);
      expect(slideOpacity(tester), lessThan(1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(slideOpacity(tester), 1);
    });
  });

  group('Budgets (M40)', () {
    testWidgets('84 % stays primary; 105 % is danger with "Over by" on its card only', (tester) async {
      await pumpPlan(tester);
      expect(barOf(tester, 'budget-b1'), _light.primary);
      expect(barOf(tester, 'budget-b2'), _light.danger);
      expect(
        find.descendant(of: find.byKey(const Key('budget-b2')), matching: find.textContaining('Over by R')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('budget-b1')), matching: find.textContaining('Over by')),
        findsNothing,
      );
    });

    testWidgets('crossing into over budget crossfades over 400 ms, with no shake', (tester) async {
      await pumpPlan(tester);
      when(() => budgets.progress(any())).thenAnswer((_) async => [
            _budget('b1', spent: 1100),
            _budget('b2', spent: 1050),
          ]);
      final container = ProviderScope.containerOf(tester.element(find.byType(PlanScreen)));
      container.invalidate(budgetProgressProvider);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = barOf(tester, 'budget-b1');
      expect(mid, isNot(_light.primary));
      expect(mid, isNot(_light.danger));
      // Nothing moves sideways: the card's left edge holds.
      expect(tester.getTopLeft(find.byKey(const Key('budget-b1'))).dx, 16);
      await tester.pumpAndSettle();
      expect(barOf(tester, 'budget-b1'), _light.danger);
      // Both budgets, and now the total too (R 2 150 of R 2 000).
      expect(find.textContaining('Over by R'), findsNWidgets(3));
    });
  });

  group('Goals (M29, M39, M23)', () {
    testWidgets('Completed (n) opens with a size transition; the goal pops and pulses once ever', (tester) async {
      await pumpPlan(tester, start: PlanSegment.goals);
      recordHaptics(tester);
      // Closed, the completed card isn't built, so nothing pops unseen.
      expect(find.byType(CompletedGoalCard), findsNothing);

      await tester.tap(find.text('Completed (1)'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('mascot-pop')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(barOf(tester, 'goal-pulse'), isNot(_light.primary));
      await tester.pumpAndSettle();
      expect(barOf(tester, 'goal-pulse'), _light.primary);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      expect(
        tester.getSize(find.descendant(of: find.byType(CompletedGoalCard), matching: find.byType(Image))).width,
        CompletedGoalCard.pennySize,
      );

      // Leave and come back: the moment is spent.
      await tester.tap(find.byKey(const Key('segment-Budgets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('segment-Goals')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed (1)'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('mascot-pop')), findsNothing);
      await tester.pumpAndSettle();
      expect(haptics, hasLength(3), reason: 'the pop, then only the two segment ticks');
      expect(haptics.where((h) => h == 'HapticFeedbackType.mediumImpact'), hasLength(1));
    });

    testWidgets('the last goal clears the Add goal button', (tester) async {
      await pumpPlan(tester, start: PlanSegment.goals);
      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView).last);
      expect((list.padding! as EdgeInsets).bottom, greaterThanOrEqualTo(AppSpace.fabInset));
    });
  });
}
