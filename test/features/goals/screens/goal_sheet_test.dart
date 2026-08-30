import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/goals/data/goals_api.dart';
import 'package:piggybank/features/goals/models/goal.dart';
import 'package:piggybank/features/goals/providers/goals_provider.dart';
import 'package:piggybank/features/goals/screens/goals_screen.dart';

import '../../../test_helpers/pump_app.dart';

class _MockGoalsApi extends Mock implements GoalsApi {}

Goal _goal({DateTime? targetDate}) => Goal(
      id: 'g1',
      name: 'Emergency fund',
      targetAmount: Decimal.fromInt(10000),
      currentAmount: Decimal.fromInt(2500),
      targetDate: targetDate,
      category: null,
      status: GoalStatus.active,
      notes: null,
      progressPct: 25.0,
    );

void main() {
  group('Add Goal sheet', () {
    testWidgets('shows "None set" for target date before anything is picked', (tester) async {
      final mockApi = _MockGoalsApi();
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(onPressed: () => showAddGoalSheet(context), child: const Text('Add')),
          ),
        ),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Target date (optional)'), findsOneWidget);
      expect(find.text('None set'), findsOneWidget);
    });

    testWidgets('submitting without picking a date sends targetDate: null', (tester) async {
      final mockApi = _MockGoalsApi();
      when(() => mockApi.create(
            name: any(named: 'name'),
            targetAmount: any(named: 'targetAmount'),
            currentAmount: any(named: 'currentAmount'),
            targetDate: any(named: 'targetDate'),
          )).thenAnswer((_) async => _goal());

      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(onPressed: () => showAddGoalSheet(context), child: const Text('Add')),
          ),
        ),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Goal name'), 'Car');
      await tester.enterText(find.widgetWithText(TextField, 'Target amount (ZAR)'), '5000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured = verify(() => mockApi.create(
            name: 'Car',
            targetAmount: '5000',
            currentAmount: '0',
            targetDate: captureAny(named: 'targetDate'),
          )).captured;
      expect(captured.single, isNull);
    });
  });

  group('Edit Goal sheet', () {
    testWidgets('pre-fills the target date label from the existing goal', (tester) async {
      final mockApi = _MockGoalsApi();
      final goal = _goal(targetDate: DateTime(2027, 3, 1));

      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(onPressed: () => showEditGoalSheet(context, goal), child: const Text('Edit')),
          ),
        ),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('2027-03-01'), findsOneWidget);
    });
  });

  group('_GoalRow footnote', () {
    testWidgets('includes the target date when the goal has one', (tester) async {
      final mockApi = _MockGoalsApi();
      when(() => mockApi.list()).thenAnswer((_) async => [_goal(targetDate: DateTime(2027, 3, 1))]);

      await pumpApp(
        tester,
        const Scaffold(body: GoalsBody()),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('by 2027-03-01'), findsOneWidget);
    });

    testWidgets('omits the "by" suffix when the goal has no target date', (tester) async {
      final mockApi = _MockGoalsApi();
      when(() => mockApi.list()).thenAnswer((_) async => [_goal()]);

      await pumpApp(
        tester,
        const Scaffold(body: GoalsBody()),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('by '), findsNothing);
    });
  });
}
