import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/goals/data/goals_api.dart';
import 'package:piggybank/features/goals/models/goal.dart';
import 'package:piggybank/features/goals/providers/goals_provider.dart';

class _MockGoalsApi extends Mock implements GoalsApi {}

Goal _goal({
  String id = 'goal-1',
  String name = 'Emergency fund',
  Decimal? target,
  Decimal? current,
  GoalStatus status = GoalStatus.active,
  double progressPct = 50.0,
}) =>
    Goal(
      id: id,
      name: name,
      targetAmount: target ?? Decimal.fromInt(10000),
      currentAmount: current ?? Decimal.fromInt(5000),
      targetDate: null,
      category: null,
      status: status,
      notes: null,
      progressPct: progressPct,
    );

void main() {
  setUpAll(() {
    // GoalStatus is passed via `any(named: 'status')` below; mocktail needs
    // a registered fallback instance for any non-primitive type used with
    // `any()`. Registered locally rather than in the shared
    // test_helpers/mocktail_setup.dart, which this QA step doesn't own.
    registerFallbackValue(GoalStatus.active);
  });

  group('goalsProvider', () {
    late _MockGoalsApi mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = _MockGoalsApi();
      container = ProviderContainer(overrides: [goalsApiProvider.overrideWithValue(mockApi)]);
    });

    tearDown(() => container.dispose());

    test('fetches the goal list from the API', () async {
      final goals = [_goal()];
      when(() => mockApi.list()).thenAnswer((_) async => goals);

      final result = await container.read(goalsProvider.future);

      expect(result, goals);
      verify(() => mockApi.list()).called(1);
    });

    test('propagates API errors through the AsyncValue', () async {
      when(() => mockApi.list()).thenThrow(Exception('network down'));

      await expectLater(container.read(goalsProvider.future), throwsA(isA<Exception>()));
    });
  });

  group('GoalsApi CRUD via mocked calls', () {
    late _MockGoalsApi mockApi;

    setUp(() {
      mockApi = _MockGoalsApi();
    });

    test('create() sends the provided fields', () async {
      final created = _goal(id: 'new-goal');
      when(() => mockApi.create(
            name: any(named: 'name'),
            targetAmount: any(named: 'targetAmount'),
            currentAmount: any(named: 'currentAmount'),
            targetDate: any(named: 'targetDate'),
            category: any(named: 'category'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => created);

      final result = await mockApi.create(name: 'New laptop', targetAmount: '20000', currentAmount: '0');

      expect(result.id, 'new-goal');
      verify(() => mockApi.create(name: 'New laptop', targetAmount: '20000', currentAmount: '0')).called(1);
    });

    test('update() sends the goal id and changed fields, including status transitions', () async {
      final updated = _goal(status: GoalStatus.completed, progressPct: 100.0);
      when(() => mockApi.update(
            any(),
            name: any(named: 'name'),
            targetAmount: any(named: 'targetAmount'),
            currentAmount: any(named: 'currentAmount'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => updated);

      final result = await mockApi.update('goal-1', currentAmount: '10000', status: GoalStatus.completed);

      expect(result.status, GoalStatus.completed);
      verify(() => mockApi.update('goal-1', currentAmount: '10000', status: GoalStatus.completed)).called(1);
    });

    test('delete() is invoked with the goal id', () async {
      when(() => mockApi.delete(any())).thenAnswer((_) async {});

      await mockApi.delete('goal-1');

      verify(() => mockApi.delete('goal-1')).called(1);
    });
  });
}
