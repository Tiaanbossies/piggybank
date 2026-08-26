import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/transactions/data/transactions_api.dart';
import 'package:piggybank/features/transactions/models/transaction.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';

class _MockTransactionsApi extends Mock implements TransactionsApi {}

// Helper to create test transactions easily
Transaction _createTestTransaction({
  required String id,
  required String category,
  required Decimal amount,
  TransactionType transactionType = TransactionType.expense,
  DateTime? transactionDate,
}) =>
    Transaction(
      id: id,
      accountId: null,
      transactionType: transactionType,
      category: category,
      description: null,
      amount: amount,
      transactionDate: transactionDate ?? DateTime(2024, 1, 1),
      merchantName: null,
      notes: null,
      accountName: null,
    );

void main() {
  group('TransactionPaginationNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial offset is 0', () {
      final offset = container.read(transactionPaginationProvider);
      expect(offset, 0);
    });

    test('loadMore increments offset by 50', () {
      container.read(transactionPaginationProvider.notifier).loadMore();
      expect(container.read(transactionPaginationProvider), 50);

      container.read(transactionPaginationProvider.notifier).loadMore();
      expect(container.read(transactionPaginationProvider), 100);
    });

    test('reset resets offset to 0', () {
      container.read(transactionPaginationProvider.notifier).loadMore();
      container.read(transactionPaginationProvider.notifier).loadMore();
      expect(container.read(transactionPaginationProvider), 100);

      container.read(transactionPaginationProvider.notifier).reset();
      expect(container.read(transactionPaginationProvider), 0);
    });
  });

  group('AccumulatedTransactionsNotifier', () {
    // Regression coverage for the 2026-08-25 fix: this notifier must sync
    // itself off `transactionsProvider` via `ref.listen` in its own
    // constructor (fireImmediately: true), not rely on some widget calling
    // public mutation methods during build. The previous version of this
    // test group asserted a `reset(items)`/`loadMore(items)` public API that
    // no longer exists anywhere in `lib/` (confirmed via grep) — it was
    // testing a pre-fix shape and had been silently broken since the fix
    // shipped, because nobody re-ran `flutter test` after that refactor.
    late _MockTransactionsApi mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = _MockTransactionsApi();
      container = ProviderContainer(
        overrides: [transactionsApiProvider.overrideWithValue(mockApi)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('syncs from transactionsProvider automatically at construction (fireImmediately)', () async {
      final items = [
        _createTestTransaction(id: '1', category: 'Food', amount: Decimal.fromInt(10)),
        _createTestTransaction(id: '2', category: 'Transport', amount: Decimal.fromInt(20)),
      ];
      when(() => mockApi.list(
            accountId: any(named: 'accountId'),
            transactionType: any(named: 'transactionType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            category: any(named: 'category'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => TransactionsPage(total: 2, items: items));

      // This is the exact assertion that would have caught the pre-fix bug:
      // before the fix, this list stayed stuck at `[]` forever regardless
      // of what the (mocked) backend returned, because the sync path threw
      // silently inside a widget-build-time `ref.watch`.
      await container.read(transactionsProvider.future);
      expect(container.read(accumulatedTransactionsProvider), items);
      expect(container.read(accumulatedTransactionsProvider), isNotEmpty);
    });

    test('does not stay stuck at empty when the backend returns data', () async {
      when(() => mockApi.list(
            accountId: any(named: 'accountId'),
            transactionType: any(named: 'transactionType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            category: any(named: 'category'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => TransactionsPage(total: 1, items: [
                _createTestTransaction(id: '1', category: 'Food', amount: Decimal.fromInt(10)),
              ]));

      await container.read(transactionsProvider.future);

      expect(container.read(accumulatedTransactionsProvider), isNot(isEmpty));
    });

    test('count getter reflects accumulated length after a sync', () async {
      final items = [
        _createTestTransaction(id: '1', category: 'Food', amount: Decimal.fromInt(10)),
        _createTestTransaction(id: '2', category: 'Transport', amount: Decimal.fromInt(20)),
        _createTestTransaction(id: '3', category: 'Groceries', amount: Decimal.fromInt(30)),
      ];
      when(() => mockApi.list(
            accountId: any(named: 'accountId'),
            transactionType: any(named: 'transactionType'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            category: any(named: 'category'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => TransactionsPage(total: 3, items: items));

      await container.read(transactionsProvider.future);
      expect(container.read(accumulatedTransactionsProvider.notifier).count, 3);
    });
  });
}

