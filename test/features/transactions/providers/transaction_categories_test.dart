import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/transactions/data/transactions_api.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';

class _MockTransactionsApi extends Mock implements TransactionsApi {}

void main() {
  group('Transaction Categories Provider', () {
    late _MockTransactionsApi mockApi;
    late ProviderContainer container;

    setUp(() {
      // transactionCategoriesProvider watches accumulatedTransactionsProvider,
      // whose notifier (AccumulatedTransactionsNotifier) listens to
      // transactionsProvider in its own constructor -- which in turn watches
      // transactionsApiProvider -> apiClientProvider -> authControllerProvider
      // -> sharedPreferencesProvider. A bare `ProviderContainer()` (as the
      // original version of this test used) therefore throws as soon as
      // transactionCategoriesProvider is read, because sharedPreferencesProvider
      // has no default and throws UnimplementedError unless overridden (see
      // test/test_helpers/pump_app.dart doc comment). Overriding
      // transactionsApiProvider directly (the pattern used throughout
      // test/features/transactions/providers/transaction_pagination_test.dart)
      // short-circuits that whole chain before it ever reaches the auth/prefs
      // providers, without needing a fake SharedPreferences instance here.
      mockApi = _MockTransactionsApi();
      when(() => mockApi.list(
            accountId: any(named: 'accountId'),
            transactionType: any(named: 'transactionType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            category: any(named: 'category'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => const TransactionsPage(total: 0, items: []));
      container = ProviderContainer(
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
      );
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
