import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/budgets/data/budgets_api.dart';
import 'package:piggybank/features/budgets/providers/budgets_provider.dart';
import 'package:piggybank/features/budgets/screens/budgets_screen.dart';
import 'package:piggybank/features/goals/data/goals_api.dart';
import 'package:piggybank/features/goals/providers/goals_provider.dart';
import 'package:piggybank/features/goals/screens/goals_screen.dart';
import 'package:piggybank/features/plan/screens/plan_screen.dart';
import 'package:piggybank/features/savings/data/savings_api.dart';
import 'package:piggybank/features/savings/providers/savings_provider.dart';
import 'package:piggybank/features/savings/screens/savings_plan_screen.dart';

import '../../test_helpers/pump_app.dart';

class _MockBudgetsApi extends Mock implements BudgetsApi {}

class _MockGoalsApi extends Mock implements GoalsApi {}

class _MockSavingsApi extends Mock implements SavingsApi {}

void main() {
  late _MockBudgetsApi budgets;
  late _MockGoalsApi goals;
  late _MockSavingsApi savings;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    budgets = _MockBudgetsApi();
    goals = _MockGoalsApi();
    savings = _MockSavingsApi();
    when(() => budgets.progress(any())).thenAnswer((_) async => const []);
    when(() => budgets.list()).thenAnswer((_) async => const []);
    when(() => goals.list()).thenAnswer((_) async => const []);
    when(() => savings.overview()).thenThrow(Exception('not needed'));
    when(() => savings.listRecurring()).thenAnswer((_) async => const []);
  });

  Future<void> pumpPlan(WidgetTester tester, {PlanSegment? start}) async {
    await pumpApp(
      tester,
      const PlanScreen(),
      overrides: [
        budgetsApiProvider.overrideWithValue(budgets),
        goalsApiProvider.overrideWithValue(goals),
        savingsApiProvider.overrideWithValue(savings),
        if (start != null) planSegmentProvider.overrideWith((ref) => start),
      ],
    );
    await tester.pump();
  }

  testWidgets('opens on Budgets with Add budget', (tester) async {
    await pumpPlan(tester);
    expect(find.byType(BudgetsBody), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Add budget'), findsOneWidget);
  });

  testWidgets('switching segments swaps the body and the FAB', (tester) async {
    await pumpPlan(tester);

    await tester.tap(find.text('Goals'));
    await tester.pump();
    expect(find.byType(GoalsBody), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Add goal'), findsOneWidget);

    await tester.tap(find.text('Savings'));
    await tester.pump();
    expect(find.byType(SavingsPlanBody), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Add cost'), findsOneWidget);
  });

  testWidgets('a segment set from elsewhere (Home card) is the one shown', (tester) async {
    await pumpPlan(tester, start: PlanSegment.savings);
    expect(find.byType(SavingsPlanBody), findsOneWidget);
  });

  testWidgets('the segment survives a rebuild of the tab', (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('Goals'));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(PlanScreen)));
    expect(container.read(planSegmentProvider), PlanSegment.goals);
  });
}
