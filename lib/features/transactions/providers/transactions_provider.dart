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

/// Pagination state: tracks current offset for "Load more" functionality.
class TransactionPaginationNotifier extends StateNotifier<int> {
  TransactionPaginationNotifier() : super(0);

  void reset() => state = 0;
  void loadMore() => state += 50;
}

final transactionPaginationProvider = StateNotifierProvider<TransactionPaginationNotifier, int>(
  (ref) => TransactionPaginationNotifier(),
);

final transactionsProvider = FutureProvider.autoDispose<TransactionsPage>((ref) {
  final filters = ref.watch(transactionFiltersProvider);
  final offset = ref.watch(transactionPaginationProvider);

  // Reset pagination when filters change (since filter results may be smaller)
  ref.listen(transactionFiltersProvider, (_, _) {
    ref.read(transactionPaginationProvider.notifier).reset();
  });

  return ref.watch(transactionsApiProvider).list(
        accountId: filters.accountId,
        transactionType: filters.transactionType,
        dateFrom: filters.dateFrom,
        dateTo: filters.dateTo,
        category: filters.category,
        offset: offset,
      );
});

/// Dashboard's "recent transactions" preview (DESIGN.md § Dashboard/Home) —
/// independent of [transactionFiltersProvider] so the Dashboard's preview
/// never reflects filters set on the full Transactions screen.
final recentTransactionsProvider = FutureProvider.autoDispose<TransactionsPage>((ref) {
  return ref.watch(transactionsApiProvider).list(limit: 5);
});

/// One account's recent transactions, for the read-only Account detail
/// screen (fix-it Step 6, L4). Independent of [transactionFiltersProvider]
/// for the same reason as [recentTransactionsProvider] — this screen's own
/// scoped fetch, not a reflection of whatever filters are set elsewhere.
final accountTransactionsProvider = FutureProvider.autoDispose.family<TransactionsPage, String>((ref, accountId) {
  return ref.watch(transactionsApiProvider).list(accountId: accountId, limit: 20);
});

/// Accumulated transactions: holds all transactions loaded so far across pages.
/// This is a StateNotifier that accumulates items as the user loads more.
///
/// Syncs itself off [transactionsProvider] via `ref.listen` in its own
/// constructor (with `fireImmediately: true` to also pick up whatever page
/// is already resolved at construction time) rather than requiring some
/// widget to relay updates in. A prior version relied on a separate
/// `FutureProvider` that mutated this notifier as a side effect of being
/// `ref.watch`ed during another widget's `build()` — mutating provider state
/// as a direct consequence of a widget build throws in Riverpod, and because
/// nothing ever inspected that provider's resulting `AsyncError`, this list
/// silently stayed stuck at its initial `[]` forever, so the Transactions
/// screen always showed "No transactions match this filter" regardless of
/// what filters (if any) were set.
class AccumulatedTransactionsNotifier extends StateNotifier<List<Transaction>> {
  AccumulatedTransactionsNotifier(this._ref) : super([]) {
    _ref.listen<AsyncValue<TransactionsPage>>(transactionsProvider, (_, next) {
      next.whenData(_sync);
    }, fireImmediately: true);
  }

  final Ref _ref;

  void _sync(TransactionsPage page) {
    final offset = _ref.read(transactionPaginationProvider);
    state = offset == 0 ? page.items : [...state, ...page.items];
  }

  /// Get total items accumulated so far.
  int get count => state.length;
}

final accumulatedTransactionsProvider = StateNotifierProvider.autoDispose<AccumulatedTransactionsNotifier, List<Transaction>>(
  AccumulatedTransactionsNotifier.new,
);

/// Common transaction categories (defaults for picker), sorted alphabetically.
const commonCategories = [
  'Dining',
  'Entertainment',
  'Food',
  'Gas',
  'Groceries',
  'Gym',
  'Healthcare',
  'Insurance',
  'Rent',
  'Shopping',
  'Transport',
  'Utilities',
];

/// Extract unique categories from all accumulated transactions.
/// Falls back to common categories if no transactions yet.
final transactionCategoriesProvider = Provider<List<String>>((ref) {
  final accumulated = ref.watch(accumulatedTransactionsProvider);
  
  if (accumulated.isEmpty) {
    return commonCategories;
  }
  
  // Extract unique non-empty categories from accumulated transactions
  final categories = accumulated
      .map((t) => t.category)
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  
  // Merge with common categories, removing duplicates
  final merged = <String>{...categories, ...commonCategories}.toList()..sort();
  return merged;
});
