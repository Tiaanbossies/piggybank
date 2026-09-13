import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/summaries/data/summaries_api.dart';
import 'package:piggybank/features/summaries/models/summaries.dart';
import 'package:piggybank/features/summaries/providers/summaries_provider.dart';
import 'package:piggybank/features/trends/models/month_budget_usage.dart';
import 'package:piggybank/features/trends/providers/trends_provider.dart';

class _MockSummariesApi extends Mock implements SummariesApi {}

BudgetUsageSummary _usage({double budget = 5000, double spend = 2500}) => BudgetUsageSummary(
      budgetTotal: Decimal.parse(budget.toString()),
      actualSpend: Decimal.parse(spend.toString()),
      remaining: Decimal.parse((budget - spend).toString()),
      percentUsed: budget == 0 ? Decimal.zero : Decimal.parse((spend / budget * 100).toStringAsFixed(2)),
    );

void main() {
  late _MockSummariesApi api;
  late ProviderContainer container;

  setUp(() {
    api = _MockSummariesApi();
    container = ProviderContainer(overrides: [summariesApiProvider.overrideWithValue(api)]);
  });

  tearDown(() => container.dispose());

  group('trailingMonthKeys', () {
    test('returns the trailing window oldest-first, ending with the given month', () {
      expect(
        trailingMonthKeys(count: 6, now: DateTime(2026, 9, 13)),
        ['2026-04', '2026-05', '2026-06', '2026-07', '2026-08', '2026-09'],
      );
    });

    test('rolls back across a year boundary', () {
      expect(
        trailingMonthKeys(count: 3, now: DateTime(2026, 2, 1)),
        ['2025-12', '2026-01', '2026-02'],
      );
    });

    test('defaults to the trend window length', () {
      expect(trailingMonthKeys(), hasLength(trendWindowMonths));
      expect(trailingMonthKeys().last, currentMonthKey());
    });
  });

  group('budgetUsageProvider family', () {
    test('is keyed by month — each month fetches independently', () async {
      when(() => api.budgetUsage(month: '2026-07')).thenAnswer((_) async => _usage(budget: 1000, spend: 400));
      when(() => api.budgetUsage(month: '2026-08')).thenAnswer((_) async => _usage(budget: 2000, spend: 1800));

      final july = await container.read(budgetUsageProvider('2026-07').future);
      final august = await container.read(budgetUsageProvider('2026-08').future);

      expect(july.budgetTotal, Decimal.fromInt(1000));
      expect(august.budgetTotal, Decimal.fromInt(2000));
      verify(() => api.budgetUsage(month: '2026-07')).called(1);
      verify(() => api.budgetUsage(month: '2026-08')).called(1);
    });

    test('a month with no budget resolves to an explicit zero state, not an error', () async {
      when(() => api.budgetUsage(month: '2026-03')).thenAnswer((_) async => _usage(budget: 0, spend: 0));

      final usage = await container.read(budgetUsageProvider('2026-03').future);

      expect(usage.hasBudget, isFalse);
      expect(usage.budgetTotal, Decimal.zero);
      expect(usage.percentUsed, Decimal.zero);
    });

    test('maps a 404 to the empty state rather than failing the month', () async {
      when(() => api.budgetUsage(month: '2026-02'))
          .thenThrow(const ApiError(statusCode: 404, message: 'No budget'));

      final usage = await container.read(budgetUsageProvider('2026-02').future);

      expect(usage.hasBudget, isFalse);
    });

    test('still surfaces a genuine failure', () async {
      when(() => api.budgetUsage(month: '2026-01'))
          .thenThrow(const ApiError(statusCode: 500, message: 'boom'));

      await expectLater(container.read(budgetUsageProvider('2026-01').future), throwsA(isA<ApiError>()));
    });
  });

  group('budgetAdherenceTrendProvider', () {
    test('fans out one call per month and returns the window oldest-first', () async {
      final months = trailingMonthKeys();
      for (final month in months) {
        when(() => api.budgetUsage(month: month)).thenAnswer((_) async => _usage());
      }

      final trend = await container.read(budgetAdherenceTrendProvider.future);

      expect(trend, hasLength(trendWindowMonths));
      expect(trend.map((m) => m.monthKey).toList(), months);
      for (final month in months) {
        verify(() => api.budgetUsage(month: month)).called(1);
      }
    });

    test('keeps budget-less months in the series as empty slots', () async {
      final months = trailingMonthKeys();
      for (final month in months) {
        when(() => api.budgetUsage(month: month)).thenAnswer((_) async => _usage(budget: 0, spend: 0));
      }
      when(() => api.budgetUsage(month: months.last)).thenAnswer((_) async => _usage());

      final trend = await container.read(budgetAdherenceTrendProvider.future);

      expect(trend, hasLength(trendWindowMonths));
      expect(trend.where((m) => m.hasBudget), hasLength(1));
      expect(trend.last.hasBudget, isTrue);
    });

    test('labels each month readably', () {
      final entry = MonthBudgetUsage(monthKey: '2026-08', usage: BudgetUsageSummary.empty);
      expect(entry.label, 'Aug 2026');
      expect(entry.hasBudget, isFalse);
    });
  });

  group('recurring / high-cost providers', () {
    test('recurringExpensesProvider returns the API list', () async {
      when(() => api.recurringExpenses()).thenAnswer((_) async => [
            RecurringExpenseSummary(
              category: 'Groceries',
              occurrences: 3,
              avgAmount: Decimal.fromInt(1200),
              totalAmount: Decimal.fromInt(3600),
              lastDate: DateTime(2026, 8, 20),
            ),
          ]);

      final recurring = await container.read(recurringExpensesProvider.future);

      expect(recurring.single.category, 'Groceries');
    });

    test('highCostExpensesProvider returns the API list', () async {
      when(() => api.highCostExpenses()).thenAnswer((_) async => [
            HighCostExpenseSummary(
              category: 'Rent',
              count: 1,
              totalAmount: Decimal.fromInt(9000),
              maxSingleAmount: Decimal.fromInt(9000),
              avgAmount: Decimal.fromInt(9000),
              lastDate: DateTime(2026, 8, 1),
            ),
          ]);

      final top = await container.read(highCostExpensesProvider.future);

      expect(top.single.category, 'Rent');
    });

    test('an API failure surfaces as an error state', () async {
      when(() => api.recurringExpenses()).thenThrow(const ApiError(statusCode: 500, message: 'boom'));

      await expectLater(container.read(recurringExpensesProvider.future), throwsA(isA<ApiError>()));
    });
  });
}
