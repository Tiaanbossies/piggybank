import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/goals/data/goals_api.dart';
import 'package:piggybank/features/goals/models/goal.dart';
import 'package:piggybank/features/goals/providers/goals_provider.dart';
import 'package:piggybank/features/goals/screens/goals_screen.dart';
import 'package:piggybank/shared/widgets/progress_card.dart';

import '../../../test_helpers/pump_app.dart';

class _MockGoalsApi extends Mock implements GoalsApi {}

Goal _goal({
  required String id,
  required String name,
  required Decimal target,
  required Decimal current,
  required double progressPct,
}) =>
    Goal(
      id: id,
      name: name,
      targetAmount: target,
      currentAmount: current,
      targetDate: null,
      category: null,
      status: GoalStatus.active,
      notes: null,
      progressPct: progressPct,
    );

void main() {
  group('GoalsBody', () {
    testWidgets('renders a row per goal returned by the API', (tester) async {
      final mockApi = _MockGoalsApi();
      when(mockApi.list).thenAnswer((_) async => [
            _goal(id: 'g1', name: 'Emergency fund', target: Decimal.fromInt(10000), current: Decimal.fromInt(2500), progressPct: 25.0),
            _goal(id: 'g2', name: 'New laptop', target: Decimal.fromInt(20000), current: Decimal.fromInt(20000), progressPct: 100.0),
          ]);

      await pumpApp(
        tester,
        const Scaffold(body: GoalsBody()),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency fund'), findsOneWidget);
      expect(find.text('New laptop'), findsOneWidget);
      expect(find.byType(ProgressCard), findsNWidgets(2));
    });

    testWidgets('shows the empty state when the API returns no goals', (tester) async {
      final mockApi = _MockGoalsApi();
      when(mockApi.list).thenAnswer((_) async => []);

      await pumpApp(
        tester,
        const Scaffold(body: GoalsBody()),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('No goals yet.'), findsOneWidget);
      expect(find.byType(ProgressCard), findsNothing);
    });

    testWidgets('shows the error message when the API call fails', (tester) async {
      final mockApi = _MockGoalsApi();
      when(mockApi.list).thenThrow(Exception('boom'));

      await pumpApp(
        tester,
        const Scaffold(body: GoalsBody()),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load goals'), findsOneWidget);
    });

    testWidgets('passes progressPct/100 as the ProgressCard pct (saved/target percentage)', (tester) async {
      final mockApi = _MockGoalsApi();
      when(mockApi.list).thenAnswer((_) async => [
            _goal(id: 'g1', name: 'Car', target: Decimal.fromInt(100000), current: Decimal.fromInt(37000), progressPct: 37.0),
          ]);

      await pumpApp(
        tester,
        const Scaffold(body: GoalsBody()),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      final card = tester.widget<ProgressCard>(find.byType(ProgressCard));
      expect(card.pct, closeTo(0.37, 0.0001));
    });

    testWidgets('a completed goal (100% progress) renders a full progress bar', (tester) async {
      final mockApi = _MockGoalsApi();
      when(mockApi.list).thenAnswer((_) async => [
            _goal(id: 'g1', name: 'Holiday', target: Decimal.fromInt(5000), current: Decimal.fromInt(5000), progressPct: 100.0),
          ]);

      await pumpApp(
        tester,
        const Scaffold(body: GoalsBody()),
        overrides: [goalsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, 1.0);
    });
  });
}
