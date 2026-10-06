import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../accounts/models/account.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../summaries/providers/summaries_provider.dart';
import '../models/transaction.dart';
import '../providers/quick_add_providers.dart';
import '../providers/transactions_provider.dart';

/// Opens the add/edit sheet — from the Transactions list (its FAB, or a
/// row) and from Home's Add button, which is why it lives outside either
/// screen (UX plan item 2).
Future<void> showTransactionSheet(BuildContext context, {Transaction? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => TransactionSheet(existing: existing),
  );
}

/// How many most-used categories show as one-tap chips; the rest stay in
/// the dropdown underneath.
const _chipCount = 6;

class TransactionSheet extends ConsumerStatefulWidget {
  const TransactionSheet({this.existing, super.key});
  final Transaction? existing;

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _notesController;
  late String _category;
  late TransactionType _type;
  late DateTime _date;
  String? _accountId;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;

  bool get _isAdding => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _category = existing?.category ?? '';
    _amountController = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    _merchantController = TextEditingController(text: existing?.merchantName ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _type = existing?.transactionType ?? TransactionType.expense;
    _date = existing?.transactionDate ?? DateTime.now();
    _accountId = existing != null ? existing.accountId : ref.read(lastUsedAccountProvider);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// A remembered or stored account can since have been deactivated; the
  /// dropdown asserts on a value missing from its items, and the backend
  /// rejects it — so it falls back to "No account" rather than either.
  String? _validAccountId(List<Account>? accounts) {
    if (accounts == null || _accountId == null) return null;
    return accounts.any((a) => a.id == _accountId && a.isActive) ? _accountId : null;
  }

  Future<void> _submit() async {
    final amount = _amountController.text.trim();
    if (amount.isEmpty) {
      setState(() => _error = 'Enter an amount.');
      return;
    }
    if (_category.trim().isEmpty) {
      setState(() => _error = 'Pick a category.');
      return;
    }
    final accountId = _validAccountId(ref.read(accountsProvider).valueOrNull);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(transactionsApiProvider);
      final merchant = _merchantController.text.trim();
      final notes = _notesController.text.trim();
      if (_isAdding) {
        await api.create(
          accountId: accountId,
          transactionType: _type,
          category: _category.trim(),
          amount: amount,
          transactionDate: _date,
          merchantName: merchant.isEmpty ? null : merchant,
          notes: notes.isEmpty ? null : notes,
        );
        await ref.read(lastUsedAccountProvider.notifier).remember(accountId);
      } else {
        await api.update(
          widget.existing!.id,
          accountId: accountId,
          transactionType: _type,
          category: _category.trim(),
          amount: amount,
          transactionDate: _date,
          merchantName: merchant.isEmpty ? null : merchant,
          notes: notes.isEmpty ? null : notes,
        );
      }
      _refreshAfterWrite();
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
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
      _refreshAfterWrite();
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// Everything a written transaction shows up in — the list, and Home's
  /// today/month/recent figures now that the sheet also opens from there.
  void _refreshAfterWrite() {
    ref
      ..invalidate(transactionsProvider)
      ..invalidate(recentTransactionsProvider)
      ..invalidate(todaySpendProvider)
      ..invalidate(cashflowProvider)
      ..invalidate(categoryUsageProvider);
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
    final used = ref.watch(categoryUsageProvider(_type)).valueOrNull ?? const <String>[];
    final busy = _submitting || _deleting;

    // Chips: what this user actually files things under, most-used first;
    // the stock list only until they have history.
    final chips = (used.isNotEmpty ? used : commonCategories).take(_chipCount).toList();
    // Dropdown: everything — used, stock, and whatever this transaction
    // already carries (an edit can hold a category neither list has).
    final allCategories = <String>{...used, ...commonCategories, if (_category.isNotEmpty) _category}.toList();

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Save sits up here, not at the foot of the form: with the
            // keyboard open the foot is off-screen, and reaching it costs a
            // scroll on every add.
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isAdding ? 'Add transaction' : 'Edit transaction',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ElevatedButton(
                  onPressed: busy ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
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
              autofocus: _isAdding,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (ZAR)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in chips)
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // Re-keyed on the category so a chip tap shows up here too —
              // `initialValue` is otherwise only read once.
              key: ValueKey('category-$_category'),
              initialValue: _category.isEmpty ? null : _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in allCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
              isExpanded: true,
            ),
            const SizedBox(height: 16),
            TextField(controller: _merchantController, decoration: const InputDecoration(labelText: 'Merchant (optional)')),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (accounts) => DropdownButtonFormField<String?>(
                initialValue: _validAccountId(accounts),
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
              subtitle: Text(
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (!_isAdding) ...[
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
