import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../expenses/screens/expenses_summary_screen.dart';
import '../models/transaction.dart';
import '../providers/transactions_provider.dart';

/// Grouped-list-cells pattern per DESIGN.md § Transactions: rows grouped by
/// date (newest first), tapping a row opens an edit sheet reusing the same
/// fields as create.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(transactionsProvider);
    final selectedType = ref.watch(transactionFiltersProvider).transactionType;

    // Trigger accumulator side effect to sync transactions
    ref.watch(transactionAccumulatorEffect);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
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
                  error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load transactions')),
                  data: (page) {
                    final accumulated = ref.watch(accumulatedTransactionsProvider);
                    
                    if (accumulated.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [Center(child: Padding(padding: EdgeInsets.only(top: 48), child: Text('No transactions match this filter.')))],
                      );
                    }
                    
                    final groups = _groupByDate(accumulated);
                    final hasMore = accumulated.length < page.total;
                    
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(_formatGroupDate(entry.key), style: Theme.of(context).textTheme.labelMedium),
                          ),
                          GroupCard(children: [for (final transaction in entry.value) _TransactionRow(transaction: transaction)]),
                        ],
                        if (hasMore) ...[
                          const SizedBox(height: 24),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: Text('Load more (${accumulated.length} of ${page.total})'),
                              onPressed: () => ref.read(transactionPaginationProvider.notifier).loadMore(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _TransactionSheet(),
        ),
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

  String _formatGroupDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = transaction.transactionType == TransactionType.expense;
    final signedAmount = isExpense ? -transaction.amount.toDouble() : transaction.amount.toDouble();

    // Ordinary amounts render in plain ink per the mockups — success/danger
    // is reserved for budget/goal progress and destructive actions only.
    return GroupRow(
      leadingIcon: isExpense ? Icons.arrow_upward : Icons.arrow_downward,
      title: transaction.merchantName ?? transaction.description ?? transaction.category,
      subtitle: transaction.category,
      trailing: Text(formatZAR(signedAmount), style: moneyTextStyle(context, fontSize: 15)),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _TransactionSheet(existing: transaction),
      ),
    );
  }
}

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({this.existing});
  final Transaction? existing;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _notesController;
  late TransactionType _type;
  late DateTime _date;
  String? _accountId;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _categoryController = TextEditingController(text: existing?.category ?? '');
    _amountController = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    _merchantController = TextEditingController(text: existing?.merchantName ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _type = existing?.transactionType ?? TransactionType.expense;
    _date = existing?.transactionDate ?? DateTime.now();
    _accountId = existing?.accountId;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(transactionsApiProvider);
      if (widget.existing == null) {
        await api.create(
          accountId: _accountId,
          transactionType: _type,
          category: _categoryController.text.trim(),
          amount: _amountController.text.trim(),
          transactionDate: _date,
          merchantName: _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        await api.update(
          widget.existing!.id,
          accountId: _accountId,
          transactionType: _type,
          category: _categoryController.text.trim(),
          amount: _amountController.text.trim(),
          transactionDate: _date,
          merchantName: _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }
      ref.invalidate(transactionsProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(transactionsApiProvider).delete(existing.id);
      ref.invalidate(transactionsProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final busy = _submitting || _deleting;

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Add transaction' : 'Edit transaction', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                ButtonSegment(value: TransactionType.income, label: Text('Income')),
                ButtonSegment(value: TransactionType.transfer, label: Text('Transfer')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (ZAR)'),
            ),
            const SizedBox(height: 16),
            TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category')),
            const SizedBox(height: 16),
            TextField(controller: _merchantController, decoration: const InputDecoration(labelText: 'Merchant (optional)')),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (accounts) => DropdownButtonFormField<String?>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: 'Account (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No account')),
                  for (final a in accounts.where((a) => a.isActive)) DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : _submit,
              child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : _delete,
                child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ],
        ),
      ),
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
