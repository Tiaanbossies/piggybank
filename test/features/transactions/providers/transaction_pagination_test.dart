import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/transactions/models/transaction.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';

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
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty list', () {
      final items = container.read(accumulatedTransactionsProvider);
      expect(items, isEmpty);
    });

    test('reset replaces accumulated items', () {
      final items = [
        _createTestTransaction(id: '1', category: 'Food', amount: Decimal.fromInt(10)),
        _createTestTransaction(id: '2', category: 'Transport', amount: Decimal.fromInt(20)),
      ];
      container.read(accumulatedTransactionsProvider.notifier).reset(items);
      expect(container.read(accumulatedTransactionsProvider), items);
      expect(container.read(accumulatedTransactionsProvider).length, 2);
    });

    test('loadMore appends new items', () {
      final initialItems = [
        _createTestTransaction(id: '1', category: 'Food', amount: Decimal.fromInt(10)),
      ];
      container.read(accumulatedTransactionsProvider.notifier).reset(initialItems);

      final newItems = [
        _createTestTransaction(id: '2', category: 'Transport', amount: Decimal.fromInt(20)),
      ];
      container.read(accumulatedTransactionsProvider.notifier).loadMore(newItems);

      final all = container.read(accumulatedTransactionsProvider);
      expect(all.length, 2);
      expect(all[0].id, '1');
      expect(all[1].id, '2');
    });

    test('count getter returns accumulated count', () {
      final items = [
        _createTestTransaction(id: '1', category: 'Food', amount: Decimal.fromInt(10)),
        _createTestTransaction(id: '2', category: 'Transport', amount: Decimal.fromInt(20)),
        _createTestTransaction(id: '3', category: 'Groceries', amount: Decimal.fromInt(30)),
      ];
      container.read(accumulatedTransactionsProvider.notifier).reset(items);
      expect(container.read(accumulatedTransactionsProvider.notifier).count, 3);
    });

    test('multiple loadMore calls accumulate correctly', () {
      final page1 = [
        _createTestTransaction(id: '1', category: 'Food', amount: Decimal.fromInt(10)),
      ];
      container.read(accumulatedTransactionsProvider.notifier).reset(page1);
      expect(container.read(accumulatedTransactionsProvider).length, 1);

      final page2 = [
        _createTestTransaction(id: '2', category: 'Transport', amount: Decimal.fromInt(20)),
      ];
      container.read(accumulatedTransactionsProvider.notifier).loadMore(page2);
      expect(container.read(accumulatedTransactionsProvider).length, 2);

      final page3 = [
        _createTestTransaction(id: '3', category: 'Groceries', amount: Decimal.fromInt(30)),
      ];
      container.read(accumulatedTransactionsProvider.notifier).loadMore(page3);
      expect(container.read(accumulatedTransactionsProvider).length, 3);
    });
  });
}

