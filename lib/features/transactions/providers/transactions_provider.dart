import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/transactions_api.dart';
import '../models/transaction.dart';

final transactionsApiProvider = Provider<TransactionsApi>((ref) => TransactionsApi(ref.watch(apiClientProvider)));

/// Filter state for the transactions list. Held as a single immutable
/// object behind a [StateNotifier] (not separate loose variables per
/// filter) so that a `watch`ing [FutureProvider] always sees every active
/// filter together on each rebuild — the mobile equivalent of the web
/// app's `transactions-filter.spec.ts` stale-closure fix, where setting one
/// filter after another had dropped the first from the request.
class TransactionFilters {
  const TransactionFilters({this.accountId, this.transactionType, this.dateFrom, this.dateTo, this.category});

  final String? accountId;
  final TransactionType? transactionType;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? category;

  TransactionFilters copyWith({
    String? Function()? accountId,
    TransactionType? Function()? transactionType,
    DateTime? Function()? dateFrom,
    DateTime? Function()? dateTo,
    String? Function()? category,
  }) {
    return TransactionFilters(
      accountId: accountId != null ? accountId() : this.accountId,
      transactionType: transactionType != null ? transactionType() : this.transactionType,
      dateFrom: dateFrom != null ? dateFrom() : this.dateFrom,
      dateTo: dateTo != null ? dateTo() : this.dateTo,
      category: category != null ? category() : this.category,
    );
  }
}

class TransactionFiltersNotifier extends StateNotifier<TransactionFilters> {
  TransactionFiltersNotifier() : super(const TransactionFilters());

  void setAccountId(String? value) => state = state.copyWith(accountId: () => value);
  void setTransactionType(TransactionType? value) => state = state.copyWith(transactionType: () => value);
  void setDateFrom(DateTime? value) => state = state.copyWith(dateFrom: () => value);
  void setDateTo(DateTime? value) => state = state.copyWith(dateTo: () => value);
  void setCategory(String? value) => state = state.copyWith(category: () => value);
  void clear() => state = const TransactionFilters();
}

final transactionFiltersProvider = StateNotifierProvider<TransactionFiltersNotifier, TransactionFilters>(
  (ref) => TransactionFiltersNotifier(),
);

final transactionsProvider = FutureProvider.autoDispose<TransactionsPage>((ref) {
  final filters = ref.watch(transactionFiltersProvider);
  return ref.watch(transactionsApiProvider).list(
        accountId: filters.accountId,
        transactionType: filters.transactionType,
        dateFrom: filters.dateFrom,
        dateTo: filters.dateTo,
        category: filters.category,
      );
});

/// Dashboard's "recent transactions" preview (DESIGN.md § Dashboard/Home) —
/// independent of [transactionFiltersProvider] so the Dashboard's preview
/// never reflects filters set on the full Transactions screen.
final recentTransactionsProvider = FutureProvider.autoDispose<TransactionsPage>((ref) {
  return ref.watch(transactionsApiProvider).list(limit: 5);
});
