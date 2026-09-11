import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/budgets/data/budgets_api.dart';
import 'package:piggybank/features/budgets/models/budget.dart';
import 'package:piggybank/features/budgets/providers/budgets_provider.dart';
import 'package:piggybank/features/budgets/screens/budgets_screen.dart';
import 'package:piggybank/shared/widgets/progress_card.dart';

import '../../../test_helpers/pump_app.dart';

class _MockBudgetsApi extends Mock implements BudgetsApi {}

BudgetProgress _progress({
  required String id,
  String? category,
  String? parentBudgetId,
  bool overBudget = false,
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
      pctUsed: overBudget ? 120.0 : 50.0,
      overBudget: overBudget,
      children: children,
    );

void main() {
  group('BudgetsBody', () {
    testWidgets('renders a row per budget returned by the API', (tester) async {
      final mockApi = _MockBudgetsApi();
      when(() => mockApi.progress(any())).thenAnswer((_) async => [
            _progress(id: 'b1', category: 'Groceries'),
            _progress(id: 'b2', category: 'Fuel'),
          ]);

      await pumpApp(
        tester,
        const Scaffold(body: BudgetsBody()),
        overrides: [budgetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);
      // +1 for the "Total spent" summary card shown above the category list.
      expect(find.text('Total spent'), findsOneWidget);
      expect(find.byType(ProgressCard), findsNWidgets(3));
    });

    testWidgets('shows the empty state when the API returns no budgets', (tester) async {
      final mockApi = _MockBudgetsApi();
      when(() => mockApi.progress(any())).thenAnswer((_) async => []);

      await pumpApp(
        tester,
        const Scaffold(body: BudgetsBody()),
        overrides: [budgetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('No budgets for this month.'), findsOneWidget);
      expect(find.text('Tap "Add budget" below to set one up.'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
      expect(find.byType(ProgressCard), findsNothing);
    });

    testWidgets('renders sub-category children indented beneath their parent', (tester) async {
      final mockApi = _MockBudgetsApi();
      when(() => mockApi.progress(any())).thenAnswer((_) async => [
            _progress(
              id: 'parent',
              category: 'Groceries',
              children: [_progress(id: 'child', category: 'Takeout', parentBudgetId: 'parent')],
            ),
          ]);

      await pumpApp(
        tester,
        const Scaffold(body: BudgetsBody()),
        overrides: [budgetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Takeout'), findsOneWidget);

      final cards = tester.widgetList<ProgressCard>(find.byType(ProgressCard)).toList();
      expect(cards.firstWhere((c) => c.title == 'Groceries').indented, isFalse);
      expect(cards.firstWhere((c) => c.title == 'Takeout').indented, isTrue);
    });

    testWidgets('shows the error message when the API call fails', (tester) async {
      final mockApi = _MockBudgetsApi();
      when(() => mockApi.progress(any())).thenThrow(Exception('boom'));

      await pumpApp(
        tester,
        const Scaffold(body: BudgetsBody()),
        overrides: [budgetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load budgets'), findsOneWidget);
    });

    testWidgets('month navigation arrows re-trigger a fetch for the new month', (tester) async {
      final mockApi = _MockBudgetsApi();
      when(() => mockApi.progress(any())).thenAnswer((_) async => [_progress(id: 'b1', category: 'Groceries')]);

      await pumpApp(
        tester,
        const Scaffold(body: BudgetsBody()),
        overrides: [budgetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      verify(() => mockApi.progress(any())).called(2);
    });
  });
}
