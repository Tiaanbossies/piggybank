import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/budgets/data/budgets_api.dart';
import 'package:piggybank/features/budgets/models/budget.dart';
import 'package:piggybank/features/budgets/providers/budgets_provider.dart';

class _MockBudgetsApi extends Mock implements BudgetsApi {}

BudgetProgress _progress({
  String id = 'bud-1',
  String? category = 'Groceries',
  String? parentBudgetId,
  bool overBudget = false,
  double pctUsed = 50.0,
  List<BudgetProgress> children = const [],
}) =>
    BudgetProgress(
      id: id,
      month: DateTime(2026, 8, 1),
      category: category,
      parentBudgetId: parentBudgetId,
      budgetAmount: Decimal.fromInt(1000),
      spent: Decimal.fromInt(500),
      remaining: Decimal.fromInt(500),
      pctUsed: pctUsed,
      overBudget: overBudget,
      children: children,
    );

Budget _budget({
  String id = 'bud-1',
  DateTime? month,
  String? category = 'Groceries',
  String? parentBudgetId,
}) =>
    Budget(
      id: id,
      month: month ?? DateTime(2026, 8, 1),
      totalBudget: Decimal.fromInt(1000),
      category: category,
      parentBudgetId: parentBudgetId,
    );

void main() {
  group('SelectedMonthNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('starts at the first of the current month', () {
      final now = DateTime.now();
      final selected = container.read(selectedBudgetMonthProvider);
      expect(selected, DateTime(now.year, now.month, 1));
    });

    test('next() advances to the first of the following month', () {
      final start = container.read(selectedBudgetMonthProvider);
      container.read(selectedBudgetMonthProvider.notifier).next();
      final after = container.read(selectedBudgetMonthProvider);
      expect(after.month, start.month == 12 ? 1 : start.month + 1);
      expect(after.day, 1);
    });

    test('previous() steps back to the first of the prior month', () {
      final start = container.read(selectedBudgetMonthProvider);
      container.read(selectedBudgetMonthProvider.notifier).previous();
      final after = container.read(selectedBudgetMonthProvider);
      expect(after.month, start.month == 1 ? 12 : start.month - 1);
      expect(after.day, 1);
    });

    test('next() then previous() returns to the original month', () {
      final start = container.read(selectedBudgetMonthProvider);
      container.read(selectedBudgetMonthProvider.notifier)
        ..next()
        ..previous();
      expect(container.read(selectedBudgetMonthProvider), start);
    });

    test('next() correctly rolls over the year boundary', () {
      // Not directly settable, but December -> January rollover is exercised
      // by repeatedly calling next() from "now" up to 12 times and checking
      // no exception is thrown and the year increments appropriately.
      final notifier = container.read(selectedBudgetMonthProvider.notifier);
      for (var i = 0; i < 12; i++) {
        notifier.next();
      }
      final start = DateTime.now();
      final expectedMonth = DateTime(start.year, start.month, 1);
      final after = container.read(selectedBudgetMonthProvider);
      expect(after.year, expectedMonth.year + 1);
      expect(after.month, expectedMonth.month);
    });
  });

  group('budgetProgressProvider', () {
    late _MockBudgetsApi mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = _MockBudgetsApi();
      container = ProviderContainer(
        overrides: [budgetsApiProvider.overrideWithValue(mockApi)],
      );
    });

    tearDown(() => container.dispose());

    test('fetches progress for the selected month from the API', () async {
      final items = [_progress()];
      when(() => mockApi.progress(any())).thenAnswer((_) async => items);

      final result = await container.read(budgetProgressProvider.future);

      expect(result, items);
      verify(() => mockApi.progress(any())).called(1);
    });

    test('re-fetches when the selected month changes', () async {
      when(() => mockApi.progress(any())).thenAnswer((_) async => [_progress()]);

      await container.read(budgetProgressProvider.future);
      container.read(selectedBudgetMonthProvider.notifier).next();
      await container.read(budgetProgressProvider.future);

      verify(() => mockApi.progress(any())).called(2);
    });

    test('propagates API errors through the AsyncValue', () async {
      when(() => mockApi.progress(any())).thenThrow(Exception('network down'));

      await expectLater(
        container.read(budgetProgressProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('budgetsForMonthProvider', () {
    late _MockBudgetsApi mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = _MockBudgetsApi();
      container = ProviderContainer(
        overrides: [budgetsApiProvider.overrideWithValue(mockApi)],
      );
    });

    tearDown(() => container.dispose());

    test('filters the full budget list down to the selected month', () async {
      final selectedMonth = container.read(selectedBudgetMonthProvider);
      final otherMonth = DateTime(selectedMonth.year, selectedMonth.month == 1 ? 12 : selectedMonth.month - 1, 1);
      when(() => mockApi.list()).thenAnswer((_) async => [
            _budget(id: 'in-month', month: selectedMonth),
            _budget(id: 'other-month', month: otherMonth),
          ]);

      final result = await container.read(budgetsForMonthProvider.future);

      expect(result.map((b) => b.id), ['in-month']);
    });

    test('returns an empty list when nothing matches the month', () async {
      when(() => mockApi.list()).thenAnswer((_) async => [
            _budget(id: 'far-future', month: DateTime(2099, 1, 1)),
          ]);

      final result = await container.read(budgetsForMonthProvider.future);

      expect(result, isEmpty);
    });
  });

  group('BudgetsApi CRUD via mocked calls', () {
    late _MockBudgetsApi mockApi;

    setUp(() {
      mockApi = _MockBudgetsApi();
    });

    test('create() is invoked with the expected arguments', () async {
      final created = _budget(id: 'new-bud');
      when(() => mockApi.create(
            month: any(named: 'month'),
            totalBudget: any(named: 'totalBudget'),
            category: any(named: 'category'),
            parentBudgetId: any(named: 'parentBudgetId'),
          )).thenAnswer((_) async => created);

      final result = await mockApi.create(month: DateTime(2026, 8, 1), totalBudget: '500', category: 'Fuel');

      expect(result.id, 'new-bud');
      verify(() => mockApi.create(
            month: DateTime(2026, 8, 1),
            totalBudget: '500',
            category: 'Fuel',
            parentBudgetId: null,
          )).called(1);
    });

    test('update() is invoked with the budget id and changed fields', () async {
      final updated = _budget(id: 'bud-1', category: 'Groceries (updated)');
      when(() => mockApi.update(any(), totalBudget: any(named: 'totalBudget'), category: any(named: 'category')))
          .thenAnswer((_) async => updated);

      final result = await mockApi.update('bud-1', totalBudget: '2000', category: 'Groceries (updated)');

      expect(result.category, 'Groceries (updated)');
      verify(() => mockApi.update('bud-1', totalBudget: '2000', category: 'Groceries (updated)')).called(1);
    });

    test('delete() is invoked with the budget id', () async {
      when(() => mockApi.delete(any())).thenAnswer((_) async {});

      await mockApi.delete('bud-1');

      verify(() => mockApi.delete('bud-1')).called(1);
    });
  });
}
