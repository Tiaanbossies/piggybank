import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/motion/saved_highlight.dart';
import '../../../shared/motion/stagger_in.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_filter_chip.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/deferred_delete.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/shrinking_fab.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tab_app_bar.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../detection/widgets/review_banner.dart';
import '../../expenses/screens/expenses_summary_screen.dart';
import '../../imports/screens/imports_screen.dart';
import '../../settings/screens/import_history_screen.dart';
import '../../trends/screens/trends_screen.dart';
import '../category_icons.dart';
import '../models/transaction.dart';
import '../providers/transactions_provider.dart';
import '../widgets/signed_amount.dart';
import '../widgets/transaction_sheet.dart';

/// The Transactions tab's overflow menu items.
enum _TransactionsMenu { expenses, import, importHistory }

/// Grouped-list-cells pattern per DESIGN.md § Transactions: rows grouped by
/// date (newest first), tapping a row opens an edit sheet reusing the same
/// fields as create.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(transactionsProvider);
    // "Load more" keeps the list on screen and grows three skeleton rows at
    // its end (M13); a first load or a new filter shows the whole skeleton.
    final loadingMore = currentPage.isLoading && currentPage.hasValue && ref.watch(transactionPaginationProvider) > 0;
    final selectedType = ref.watch(transactionFiltersProvider).transactionType;
    final reviewCount = ref.watch(pendingReviewCountProvider);

    return Scaffold(
      appBar: TabAppBar(
        title: 'Transactions',
        // UX rework spec §2.2: Review (only when there's real pending work),
        // Insights, and the rarer data tools in the overflow menu.
        actions: [
          // Labelled, never icon-only (visual spec §4.3): the tooltip is also
          // what a screen reader says. Hidden when nothing is waiting.
          if (reviewCount > 0)
            IconButton(
              key: const Key('transactions-review'),
              icon: Badge(label: Text('$reviewCount'), child: const Icon(Icons.fact_check_outlined)),
              tooltip: reviewCount == 1 ? 'Review 1 detected transaction' : 'Review $reviewCount detected transactions',
              onPressed: () => openPendingReview(context),
            ),
          IconButton(
            key: const Key('transactions-insights'),
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Insights',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrendsScreen())),
          ),
          PopupMenuButton<_TransactionsMenu>(
            key: const Key('transactions-overflow'),
            tooltip: 'More',
            onSelected: (item) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => switch (item) {
                  _TransactionsMenu.expenses => const ExpensesSummaryScreen(),
                  _TransactionsMenu.import => const ImportsScreen(),
                  _TransactionsMenu.importHistory => const ImportHistoryScreen(),
                },
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _TransactionsMenu.expenses, child: Text('Expenses summary')),
              PopupMenuItem(value: _TransactionsMenu.import, child: Text('Import CSV / Scan receipt')),
              PopupMenuItem(value: _TransactionsMenu.importHistory, child: Text('Import history')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s8, AppSpace.gutter, 0),
              child: ReviewBanner(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s4, AppSpace.gutter, AppSpace.s4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in const {
                      null: 'All',
                      TransactionType.income: 'Income',
                      TransactionType.expense: 'Expense',
                      TransactionType.transfer: 'Transfer',
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpace.s8),
                        child: AppFilterChip(
                          key: Key('transactions-type-${entry.value.toLowerCase()}'),
                          label: entry.value,
                          selected: selectedType == entry.key,
                          onSelected: (_) =>
                              ref.read(transactionFiltersProvider.notifier).setTransactionType(entry.key),
                        ),
                      ),
                    // Moved out of the app bar (spec §2.2) to sit with the
                    // filters it belongs to.
                    ActionChip(
                      key: const Key('transactions-filter'),
                      avatar: const Icon(Icons.filter_list, size: 18),
                      label: const Text('Filter'),
                      onPressed: () => _showFilterSheet(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AppRefresh(
                onRefresh: () {
                  ref.read(transactionPaginationProvider.notifier).reset();
                  return ref.refresh(transactionsProvider.future);
                },
                child: SkeletonSwitcher(child: currentPage.when(
                  skipLoadingOnReload: loadingMore,
                  loading: () => const SkeletonPage(rows: 8),
                  // Was plain text inside a RefreshIndicator over a
                  // non-scrollable Center, so pull-to-refresh couldn't fire
                  // either — the shared treatment, with a way out.
                  error: (err, _) => Center(
                    child: InlineError(
                      message: err is ApiError ? err.message : 'Failed to load transactions',
                      onRetry: () {
                        ref.read(transactionPaginationProvider.notifier).reset();
                        ref.invalidate(transactionsProvider);
                      },
                    ),
                  ),
                  data: (page) {
                    final hidden = ref.watch(pendingDeletesProvider);
                    // Rows being deleted stay in the list so they can leave
                    // on screen (M15) and come back on Undo (M16).
                    final accumulated = ref.watch(accumulatedTransactionsProvider);

                    if (accumulated.isEmpty) {
                      final f = ref.watch(transactionFiltersProvider);
                      final unfiltered = f.accountId == null &&
                          f.transactionType == null &&
                          f.dateFrom == null &&
                          f.dateTo == null &&
                          f.category == null;
                      return ListView(
                        primary: true,
                        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s16, AppSpace.gutter, AppSpace.fabInset),
                        children: [
                          if (unfiltered)
                            const EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions yet.',
                              hint: 'Tap "Add transaction" below to log one.',
                              mascot: true,
                            )
                          else
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 48),
                                child: Text('No transactions match this filter.'),
                              ),
                            ),
                        ],
                      );
                    }

                    final groupEntries = _groupByDate(accumulated).entries.toList();
                    final hasMore = accumulated.length < page.total;
                    final itemCount = groupEntries.length + (hasMore ? 1 : 0);

                    // ListView.builder (not ListView(children:)) so groups are
                    // built lazily as they scroll into view, instead of every
                    // accumulated transaction's widget subtree being
                    // constructed up front on every rebuild — this list grows
                    // unboundedly via "Load more" (QA_PRODUCTION_AUDIT_2026-09-11.md M2).
                    return ListView.builder(
                      key: const Key('transactions-list'),
                      primary: true,
                      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s8, AppSpace.gutter, AppSpace.fabInset),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index < groupEntries.length) {
                          final entry = groupEntries[index];
                          final left = entry.value.where((t) => !hidden.contains(t.id)).toList();
                          return StaggerIn(
                            index: index,
                            // A day whose last row is deleted goes with it.
                            child: CollapseOut(
                              gone: left.isEmpty,
                              slide: false,
                              child: _DayGroup(
                                date: entry.key,
                                total: _dayTotal(left),
                                first: index == 0,
                                transactions: entry.value,
                              ),
                            ),
                          );
                        }
                        if (loadingMore) {
                          return const Padding(
                            key: Key('load-more-skeleton'),
                            padding: EdgeInsets.only(top: 16),
                            child: SkeletonRows(count: 3),
                          );
                        }
                        // Trailing "Load more" row — only reached once, after the last group.
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpace.sectionGap),
                          child: Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: Text('Load more (${accumulated.length} of ${page.total})'),
                              onPressed: () => ref.read(transactionPaginationProvider.notifier).loadMore(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                )),
              ),
            ),
          ],
        ),
      ),
      // Folds to its icon while the list scrolls down (M42).
      floatingActionButton: Builder(
        builder: (context) => ShrinkingFab(
          controller: PrimaryScrollController.of(context),
          icon: Icons.add,
          label: 'Add transaction',
          onPressed: () => showTransactionSheet(context),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TransactionFilterSheet(),
    );
  }

  Map<DateTime, List<Transaction>> _groupByDate(List<Transaction> items) {
    final groups = <DateTime, List<Transaction>>{};
    for (final t in items) {
      final key = DateTime(t.transactionDate.year, t.transactionDate.month, t.transactionDate.day);
      groups.putIfAbsent(key, () => []).add(t);
    }
    return groups;
  }

  /// The day's net movement: income in, spending out, transfers ignored.
  Decimal _dayTotal(List<Transaction> items) => items.fold(
        Decimal.zero,
        (sum, t) => switch (t.transactionType) {
          TransactionType.income => sum + t.amount,
          TransactionType.expense => sum - t.amount,
          TransactionType.transfer => sum,
        },
      );
}

/// One day of the list (visual spec §4.1): the date on the left and the
/// day's total on the right in `overline`, over one group card. Days are
/// separated by a hairline in `outline` at 30 %.
class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.date, required this.total, required this.first, required this.transactions});

  final DateTime date;
  final Decimal total;
  final bool first;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final overline = Theme.of(context).textTheme.labelSmall?.copyWith(color: t.muted);
    final totalText = total == Decimal.zero
        ? formatZAR(total)
        : SignedAmount.format(total.abs(), total < Decimal.zero ? TransactionType.expense : TransactionType.income);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) Divider(height: 1, thickness: 1, color: t.outline.withValues(alpha: 0.3)),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
          child: Row(
            children: [
              Expanded(child: Text(dayLabel(date), style: overline)),
              Text(
                totalText,
                key: ValueKey('day-total-${date.toIso8601String()}'),
                style: overline?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
        GroupCard(
          children: [
            for (final transaction in transactions)
              DeleteExit(
                id: transaction.id,
                child: SavedHighlight(id: transaction.id, child: _TransactionRow(transaction: transaction)),
              ),
          ],
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    // Only what the data has (visual spec §4.3): no invented times or tags.
    return GroupRow(
      key: ValueKey('transaction-${transaction.id}'),
      leadingIcon: categoryIcon(
        transaction.category,
        isExpense: transaction.transactionType == TransactionType.expense,
        isTransfer: transaction.transactionType == TransactionType.transfer,
      ),
      family: categoryFamily(transaction.category),
      title: transaction.merchantName ?? transaction.description ?? transaction.category,
      subtitle: transaction.category,
      trailing: SignedAmount.of(transaction),
      onTap: () => showTransactionSheet(context, existing: transaction),
    );
  }
}

/// Filter sheet for transactions — allows filtering by account, date range, and category.
class _TransactionFilterSheet extends ConsumerWidget {
  const _TransactionFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(transactionFiltersProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter transactions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            accountsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (accounts) => DropdownButtonFormField<String?>(
                initialValue: filters.accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All accounts')),
                  for (final a in accounts.where((a) => a.isActive)) DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (value) => ref.read(transactionFiltersProvider.notifier).setAccountId(value),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TransactionType?>(
              initialValue: filters.transactionType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All types')),
                DropdownMenuItem(value: TransactionType.income, child: Text('Income')),
                DropdownMenuItem(value: TransactionType.expense, child: Text('Expense')),
                DropdownMenuItem(value: TransactionType.transfer, child: Text('Transfer')),
              ],
              onChanged: (value) => ref.read(transactionFiltersProvider.notifier).setTransactionType(value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: filters.category ?? '',
              decoration: const InputDecoration(labelText: 'Category'),
              onChanged: (value) => ref.read(transactionFiltersProvider.notifier).setCategory(value.isEmpty ? null : value),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('From date'),
              subtitle: filters.dateFrom != null
                  ? Text('${filters.dateFrom!.year}-${filters.dateFrom!.month.toString().padLeft(2, '0')}-${filters.dateFrom!.day.toString().padLeft(2, '0')}')
                  : const Text('Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: filters.dateFrom ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  ref.read(transactionFiltersProvider.notifier).setDateFrom(picked);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('To date'),
              subtitle: filters.dateTo != null
                  ? Text('${filters.dateTo!.year}-${filters.dateTo!.month.toString().padLeft(2, '0')}-${filters.dateTo!.day.toString().padLeft(2, '0')}')
                  : const Text('Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: filters.dateTo ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  ref.read(transactionFiltersProvider.notifier).setDateTo(picked);
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(transactionFiltersProvider.notifier).clear();
                Navigator.of(context).pop();
              },
              child: const Text('Clear all filters'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
