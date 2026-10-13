import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/categories/data/categories_api.dart';
import 'package:piggybank/features/categories/models/user_category.dart';
import 'package:piggybank/features/categories/providers/categories_provider.dart';
import 'package:piggybank/features/categories/screens/manage_categories_screen.dart';
import 'package:piggybank/features/categories/widgets/category_field.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';

import '../../test_helpers/pump_app.dart';

class _MockCategoriesApi extends Mock implements CategoriesApi {}

const _groceries = UserCategory(id: 'c1', name: 'Groceries', kind: CategoryKind.expense);
const _pets = UserCategory(id: 'c2', name: 'Pets', kind: CategoryKind.expense);
const _salary = UserCategory(id: 'c3', name: 'Salary', kind: CategoryKind.income);
const _uncategorised = UserCategory(id: 'c4', name: 'Uncategorised', kind: CategoryKind.expense);

/// A CategoryField that remembers what it was given, like a sheet does.
class _FieldHost extends StatefulWidget {
  const _FieldHost({this.kind, this.noneLabel});
  final CategoryKind? kind;
  final String? noneLabel;

  @override
  State<_FieldHost> createState() => _FieldHostState();
}

class _FieldHostState extends State<_FieldHost> {
  String? value;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            CategoryField(
              value: value,
              kind: widget.kind,
              noneLabel: widget.noneLabel,
              onChanged: (v) => setState(() => value = v),
            ),
            Text('picked: ${value ?? '-'}'),
          ],
        ),
      );
}

void main() {
  late _MockCategoriesApi api;

  setUpAll(() => registerFallbackValue(CategoryKind.expense));

  setUp(() {
    api = _MockCategoriesApi();
    when(() => api.list()).thenAnswer((_) async => [_groceries, _pets, _salary, _uncategorised]);
  });

  group('categoryChoices', () {
    test('lists the given kind first, then the rest', () {
      expect(
        categoryChoices([_groceries, _salary, _pets], kind: CategoryKind.income),
        ['Salary', 'Groceries', 'Pets'],
      );
    });

    test('keeps a value the list does not have', () {
      expect(categoryChoices([_groceries], include: 'Old Name'), ['Old Name', 'Groceries']);
    });

    test('stands in the stock list until the user list loads', () {
      expect(categoryChoices(null), commonCategories);
    });
  });

  group('CategoryField', () {
    testWidgets('offers the user list, with the type first', (tester) async {
      await pumpApp(tester, const _FieldHost(kind: CategoryKind.income),
          overrides: [categoriesApiProvider.overrideWithValue(api)]);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<Text>(find.descendant(of: find.byType(DropdownMenuItem<String>), matching: find.byType(Text)))
          .map((t) => t.data)
          .toList();
      expect(labels.take(2), ['Salary', 'Groceries']);
      expect(labels, contains('New category'));
    });

    testWidgets('"New category" adds it and selects it (QA E1)', (tester) async {
      when(() => api.create('Kids', kind: any(named: 'kind')))
          .thenAnswer((_) async => const UserCategory(id: 'c9', name: 'Kids', kind: CategoryKind.expense));
      await pumpApp(tester, const _FieldHost(), overrides: [categoriesApiProvider.overrideWithValue(api)]);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('new-category-name')), 'Kids');
      await tester.tap(find.byKey(const Key('new-category-save')));
      await tester.pumpAndSettle();

      verify(() => api.create('Kids', kind: CategoryKind.expense)).called(1);
      expect(find.text('picked: Kids'), findsOneWidget);
    });

    testWidgets('the "none" entry reports null', (tester) async {
      await pumpApp(tester, const _FieldHost(noneLabel: 'All categories'),
          overrides: [categoriesApiProvider.overrideWithValue(api)]);
      await tester.pumpAndSettle();

      expect(find.text('All categories'), findsOneWidget);
      expect(find.text('picked: -'), findsOneWidget);
    });
  });

  group('ManageCategoriesScreen', () {
    testWidgets('groups spending and income', (tester) async {
      await pumpApp(tester, const ManageCategoriesScreen(), overrides: [categoriesApiProvider.overrideWithValue(api)]);
      await tester.pumpAndSettle();

      expect(find.text('Spending'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Pets'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
    });

    testWidgets('a rename goes to the API', (tester) async {
      when(() => api.update('c2', name: 'Pet Care', kind: any(named: 'kind')))
          .thenAnswer((_) async => const UserCategory(id: 'c2', name: 'Pet Care', kind: CategoryKind.expense));
      await pumpApp(tester, const ManageCategoriesScreen(), overrides: [categoriesApiProvider.overrideWithValue(api)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pets'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('category-rename')), 'Pet Care');
      await tester.tap(find.byKey(const Key('category-rename-save')));
      await tester.pumpAndSettle();

      verify(() => api.update('c2', name: 'Pet Care', kind: null)).called(1);
    });

    testWidgets('a delete moves items to Uncategorised by default', (tester) async {
      when(() => api.delete('c2', reassignTo: any(named: 'reassignTo'))).thenAnswer((_) async {});
      await pumpApp(tester, const ManageCategoriesScreen(), overrides: [categoriesApiProvider.overrideWithValue(api)]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('category-delete-c2')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Pets?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-destroy')));
      await tester.pumpAndSettle();

      verify(() => api.delete('c2', reassignTo: 'Uncategorised')).called(1);
    });
  });
}
