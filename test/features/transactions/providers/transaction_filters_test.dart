import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/transactions/models/transaction.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';

void main() {
  group('TransactionFiltersNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is all filters cleared', () {
      final filters = container.read(transactionFiltersProvider);
      expect(filters.accountId, isNull);
      expect(filters.transactionType, isNull);
      expect(filters.category, isNull);
      expect(filters.dateFrom, isNull);
      expect(filters.dateTo, isNull);
    });

    test('setAccountId updates accountId', () {
      container.read(transactionFiltersProvider.notifier).setAccountId('acc-123');
      final filters = container.read(transactionFiltersProvider);
      expect(filters.accountId, 'acc-123');
    });

    test('setTransactionType updates transactionType', () {
      container.read(transactionFiltersProvider.notifier).setTransactionType(TransactionType.income);
      final filters = container.read(transactionFiltersProvider);
      expect(filters.transactionType, TransactionType.income);
    });

    test('setCategory updates category', () {
      container.read(transactionFiltersProvider.notifier).setCategory('Food');
      final filters = container.read(transactionFiltersProvider);
      expect(filters.category, 'Food');
    });

    test('setDateFrom updates dateFrom', () {
      final date = DateTime(2024, 1, 1);
      container.read(transactionFiltersProvider.notifier).setDateFrom(date);
      final filters = container.read(transactionFiltersProvider);
      expect(filters.dateFrom, date);
    });

    test('setDateTo updates dateTo', () {
      final date = DateTime(2024, 12, 31);
      container.read(transactionFiltersProvider.notifier).setDateTo(date);
      final filters = container.read(transactionFiltersProvider);
      expect(filters.dateTo, date);
    });

    test('clear resets all filters to null', () {
      // Set multiple filters
      container.read(transactionFiltersProvider.notifier).setAccountId('acc-123');
      container.read(transactionFiltersProvider.notifier).setTransactionType(TransactionType.expense);
      container.read(transactionFiltersProvider.notifier).setCategory('Food');
      container.read(transactionFiltersProvider.notifier).setDateFrom(DateTime(2024, 1, 1));
      container.read(transactionFiltersProvider.notifier).setDateTo(DateTime(2024, 12, 31));

      // Clear all
      container.read(transactionFiltersProvider.notifier).clear();

      // Verify all filters are cleared
      final filters = container.read(transactionFiltersProvider);
      expect(filters.accountId, isNull);
      expect(filters.transactionType, isNull);
      expect(filters.category, isNull);
      expect(filters.dateFrom, isNull);
      expect(filters.dateTo, isNull);
    });

    test('multiple updates work correctly', () {
      final date1 = DateTime(2024, 1, 1);
      final date2 = DateTime(2024, 12, 31);

      container.read(transactionFiltersProvider.notifier).setAccountId('acc-123');
      container.read(transactionFiltersProvider.notifier).setTransactionType(TransactionType.expense);
      container.read(transactionFiltersProvider.notifier).setCategory('Groceries');
      container.read(transactionFiltersProvider.notifier).setDateFrom(date1);
      container.read(transactionFiltersProvider.notifier).setDateTo(date2);

      final filters = container.read(transactionFiltersProvider);
      expect(filters.accountId, 'acc-123');
      expect(filters.transactionType, TransactionType.expense);
      expect(filters.category, 'Groceries');
      expect(filters.dateFrom, date1);
      expect(filters.dateTo, date2);
    });

    test('can set filter to null', () {
      container.read(transactionFiltersProvider.notifier).setAccountId('acc-123');
      expect(container.read(transactionFiltersProvider).accountId, 'acc-123');

      container.read(transactionFiltersProvider.notifier).setAccountId(null);
      expect(container.read(transactionFiltersProvider).accountId, isNull);
    });
  });
}
