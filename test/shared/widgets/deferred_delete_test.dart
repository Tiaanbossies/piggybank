import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/goals/data/goals_api.dart';
import 'package:piggybank/features/goals/models/goal.dart';
import 'package:piggybank/features/goals/providers/goals_provider.dart';
import 'package:piggybank/features/goals/screens/goals_screen.dart';
import 'package:piggybank/shared/widgets/deferred_delete.dart';

import '../../test_helpers/pump_app.dart';

class _MockGoalsApi extends Mock implements GoalsApi {}

Goal _goal(String id, String name) => Goal(
      id: id,
      name: name,
      targetAmount: Decimal.fromInt(10000),
      currentAmount: Decimal.fromInt(2500),
      targetDate: null,
      category: null,
      status: GoalStatus.active,
      notes: null,
      progressPct: 25.0,
    );

void main() {
  group('deferDelete', () {
    late int commits;
    late bool fail;

    Future<void> pumpTrigger(WidgetTester tester) async {
      commits = 0;
      await pumpApp(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Column(
              children: [
                Text('hidden: ${ref.watch(pendingDeletesProvider).join(',')}'),
                ElevatedButton(
                  onPressed: () => deferDelete(
                    context,
                    id: 'x1',
                    message: 'Row deleted',
                    commit: (_) async {
                      commits++;
                      if (fail) throw const ApiError(statusCode: 500, message: 'Server said no');
                    },
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete'));
      // The snackbar's timer starts once it has slid in.
      await tester.pumpAndSettle();
    }

    setUp(() => fail = false);

    testWidgets('hides the row and offers Undo before anything is sent', (tester) async {
      await pumpTrigger(tester);

      expect(find.text('hidden: x1'), findsOneWidget);
      expect(find.text('Row deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(commits, 0);
    });

    testWidgets('Undo inside the window sends nothing and brings the row back', (tester) async {
      await pumpTrigger(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      expect(commits, 0);
      expect(find.text('hidden: '), findsOneWidget);
    });

    testWidgets('letting the window run out sends the delete exactly once', (tester) async {
      await pumpTrigger(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(commits, 1);
      // Stays hidden: the refetch no longer has it.
      expect(find.text('hidden: x1'), findsOneWidget);
    });

    testWidgets('a failed delete brings the row back and says why', (tester) async {
      fail = true;
      await pumpTrigger(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(commits, 1);
      expect(find.text('hidden: '), findsOneWidget);
      expect(find.text('Server said no'), findsOneWidget);
    });
  });

  group('Goal delete (spec §5, A4)', () {
    late _MockGoalsApi api;

    setUp(() {
      api = _MockGoalsApi();
      when(() => api.list()).thenAnswer((_) async => [_goal('g1', 'Emergency fund'), _goal('g2', 'Holiday')]);
      when(() => api.delete(any())).thenAnswer((_) async {});
    });

    Future<void> deleteEmergencyFund(WidgetTester tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: GoalsBody()),
        overrides: [goalsApiProvider.overrideWithValue(api)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('closes the sheet with no dialog and hides the goal', (tester) async {
      await deleteEmergencyFund(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Emergency fund deleted'), findsOneWidget);
      expect(find.text('Emergency fund'), findsNothing);
      expect(find.text('Holiday'), findsOneWidget);
      verifyNever(() => api.delete(any()));
    });

    testWidgets('Undo puts it back without calling the API', (tester) async {
      await deleteEmergencyFund(tester);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Emergency fund'), findsOneWidget);
      verifyNever(() => api.delete(any()));
    });

    testWidgets('after the window, deletes once', (tester) async {
      await deleteEmergencyFund(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      verify(() => api.delete('g1')).called(1);
    });
  });
}
