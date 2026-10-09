import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tab_app_bar.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../expenses/screens/expenses_summary_screen.dart';
import '../../imports/screens/imports_screen.dart';
import '../category_icons.dart';
import '../models/transaction.dart';
import '../providers/transactions_provider.dart';
import '../widgets/transaction_sheet.dart';

/// Grouped-list-cells pattern per DESIGN.md § Transactions: rows grouped by
/// date (newest first), tapping a row opens an edit sheet reusing the same
/// fields as create.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  // FloatingActionButton.extended's own height (56) plus its default margin
  // from the screen edge (kFloatingActionButtonMargin, 16) plus a little
  // breathing room, reserved as extra bottom padding so the last row(s) of
  // the list never sit underneath the FAB (QA_PRODUCTION_AUDIT_2026-09-11.md
  // M3 — a transaction's amount was fully hidden behind the FAB at certain
  // scroll depths).
  static const double _kFabClearance = 88;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(transactionsProvider);
    final selectedType = ref.watch(transactionFiltersProvider).transactionType;

    return Scaffold(
      appBar: TabAppBar(
        title: 'Transactions',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter transactions',
            onPressed: () => _showFilterSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Expenses summary',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpensesSummaryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Import CSV / Scan receipt',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: selectedType == entry.key,
                          onSelected: (_) =>
                              ref.read(transactionFiltersProvider.notifier).setTransactionType(entry.key),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () {
                  ref.read(transactionPaginationProvider.notifier).reset();
                  return ref.refresh(transactionsProvider.future);
                },
                child: currentPage.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
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
                    final accumulated = ref.watch(accumulatedTransactionsProvider);
                    
                    if (accumulated.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + _kFabClearance),
                        children: const [Center(child: Padding(padding: EdgeInsets.only(top: 48), child: Text('No transactions match this filter.')))],
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + _kFabClearance),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index < groupEntries.length) {
                          final entry = groupEntries[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 8),
                                child: Text(_formatGroupDate(entry.key), style: Theme.of(context).textTheme.labelMedium),
                              ),
                              GroupCard(children: [for (final transaction in entry.value) _TransactionRow(transaction: transaction)]),
                            ],
                          );
                        }
                        // Trailing "Load more" row — only reached once, after the last group.
                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
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
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionSheet(context),
        label: const Text('Add transaction'),
        icon: const Icon(Icons.add),
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

  String _formatGroupDate(DateTime date) => dayLabel(date);
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = transaction.transactionType == TransactionType.expense;
    final isIncome = transaction.transactionType == TransactionType.income;
    final signedAmount = isExpense ? -transaction.amount.toDouble() : transaction.amount.toDouble();

    // Per DESIGN.md § Transactions (superseded 2026-09-01): amount trailing
    // tinted success/danger by direction, matching the Dashboard preview.
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return GroupRow(
      leadingIcon: categoryIcon(
        transaction.category,
        isExpense: isExpense,
        isTransfer: transaction.transactionType == TransactionType.transfer,
      ),
      title: transaction.merchantName ?? transaction.description ?? transaction.category,
      subtitle: transaction.category,
      trailing: Text(
        formatZAR(signedAmount),
        style: moneyTextStyle(
          context,
          fontSize: 15,
          color: isIncome ? semantic?.success : (isExpense ? semantic?.danger : null),
        ),
      ),
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
