import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';

void main() {
  group('Transaction Categories Provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('returns common categories when no transactions', () {
      // Accumulated transactions are empty by default
      final categories = container.read(transactionCategoriesProvider);

      expect(categories, isNotEmpty);
      expect(categories, containsAll(['Food', 'Transport', 'Groceries', 'Entertainment']));
    });

    test('common categories are sorted alphabetically', () {
      final categories = container.read(transactionCategoriesProvider);

      // Verify they're in sorted order
      final sorted = List<String>.from(categories)..sort();
      expect(categories, sorted);
    });

    test('includes common categories', () {
      final categories = container.read(transactionCategoriesProvider);

      expect(categories, contains('Food'));
      expect(categories, contains('Transport'));
      expect(categories, contains('Entertainment'));
      expect(categories, contains('Utilities'));
      expect(categories, contains('Rent'));
      expect(categories, contains('Healthcare'));
    });

    test('common categories list is not empty', () {
      expect(commonCategories, isNotEmpty);
      expect(commonCategories.length, greaterThanOrEqualTo(5));
    });

    test('common categories are unique', () {
      final uniqueCategories = commonCategories.toSet();
      expect(uniqueCategories.length, commonCategories.length);
    });

    test('common categories have no empty strings', () {
      final hasEmpty = commonCategories.any((c) => c.isEmpty);
      expect(hasEmpty, false);
    });
  });
}
