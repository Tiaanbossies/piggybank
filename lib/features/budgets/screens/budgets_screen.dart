import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_motion.dart';
import '../../../shared/widgets/progress_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../transactions/category_icons.dart';
import '../models/budget.dart';
import '../providers/budgets_provider.dart';

Future<void> showEditBudgetSheet(BuildContext context, BudgetProgress existing) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BudgetSheet(existing: existing),
  );
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Body content for the Budgets sub-view of the Budgets tab. Grouped-list
/// per DESIGN.md § Budgets: one group per top-level category, sub-categories
/// rendered as indented rows within their parent's group, over-budget rows
/// in the danger colour.
class BudgetsBody extends ConsumerWidget {
  const BudgetsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedBudgetMonthProvider);
    final progressAsync = ref.watch(budgetProgressProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
                onPressed: () => ref.read(selectedBudgetMonthProvider.notifier).previous(),
              ),
              Text('${_monthNames[month.month - 1]} ${month.year}', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
                onPressed: () => ref.read(selectedBudgetMonthProvider.notifier).next(),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(budgetProgressProvider.future),
            child: AnimatedSwitcher(
              duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
              switchInCurve: AppMotion.easeOut,
              switchOutCurve: AppMotion.easeOut,
              child: progressAsync.when(
                loading: () => const Center(key: ValueKey('loading'), child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  key: const ValueKey('error'),
                  child: InlineError(message: err is ApiError ? err.message : 'Failed to load budgets'),
                ),
                data: (budgets) {
                  if (budgets.isEmpty) {
                    return ListView(
                      key: const ValueKey('empty'),
                      padding: const EdgeInsets.all(16),
                      children: const [
                        EmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'No budgets for this month.',
                          hint: 'Tap "Add budget" below to set one up.',
                        ),
                      ],
                    );
                  }
                  return ListView(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _TotalSpentSummary(budgets: budgets),
                      const SizedBox(height: 4),
                      for (final budget in budgets) ...[
                        _BudgetProgressRow(progress: budget),
                        for (final child in budget.children) _BudgetProgressRow(progress: child, indented: true),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetProgressRow extends StatelessWidget {
  const _BudgetProgressRow({required this.progress, this.indented = false});
  final BudgetProgress progress;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    final pct = progress.pctUsed / 100;
    return InkWell(
      onTap: () => showEditBudgetSheet(context, progress),
      child: ProgressCard(
        title: progress.category ?? 'Total',
        pct: pct,
        overBudget: progress.overBudget,
        indented: indented,
        icon: progress.category == null ? null : categoryIcon(progress.category),
        footnote: progress.overBudget
            ? '${formatZAR(progress.remaining.abs())} over budget'
            : '${formatZAR(progress.spent)} / ${formatZAR(progress.budgetAmount)}',
      ),
    );
  }
}

/// "Total spent" summary card per the Stitch Budgets mockup, shown above the
/// per-category list. If the user has an explicit overall budget (a
/// category-null top-level entry, whose `spent` already equals total spend
/// across every category — see `budgets/router.py`'s `_make_progress`),
/// that row is used directly; otherwise this sums the top-level categories'
/// own figures, which don't overlap each other (only a parent + its own
/// children overlap, and that's not being double-summed here — each
/// top-level entry's `spent` already folds its children in).
class _TotalSpentSummary extends StatelessWidget {
  const _TotalSpentSummary({required this.budgets});
  final List<BudgetProgress> budgets;

  @override
  Widget build(BuildContext context) {
    final explicitTotal = budgets.where((b) => b.category == null).firstOrNull;
    final Decimal spent;
    final Decimal budgetAmount;
    if (explicitTotal != null) {
      spent = explicitTotal.spent;
      budgetAmount = explicitTotal.budgetAmount;
    } else {
      spent = budgets.fold(Decimal.zero, (sum, b) => sum + b.spent);
      budgetAmount = budgets.fold(Decimal.zero, (sum, b) => sum + b.budgetAmount);
    }
    final overBudget = budgetAmount > Decimal.zero && spent > budgetAmount;
    final pct = budgetAmount > Decimal.zero ? (spent / budgetAmount).toDouble() : 0.0;

    return ProgressCard(
      title: 'Total spent',
      pct: pct,
      overBudget: overBudget,
      icon: Icons.account_balance_wallet_outlined,
      footnote: overBudget
          ? '${formatZAR(spent - budgetAmount)} over budget'
          : '${formatZAR(spent)} / ${formatZAR(budgetAmount)}',
    );
  }
}

Future<void> showAddBudgetSheet(BuildContext context) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _BudgetSheet());
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.existing});
  final BudgetProgress? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  String? _parentBudgetId;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _categoryController = TextEditingController(text: existing?.category ?? '');
    _amountController = TextEditingController(text: existing != null ? existing.budgetAmount.toString() : '');
    _parentBudgetId = existing?.parentBudgetId;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final month = ref.read(selectedBudgetMonthProvider);
      final category = _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim();
      if (widget.existing == null) {
        await ref.read(budgetsApiProvider).create(
              month: month,
              totalBudget: _amountController.text.trim(),
              category: category,
              parentBudgetId: _parentBudgetId,
            );
      } else {
        await ref.read(budgetsApiProvider).update(
              widget.existing!.id,
              totalBudget: _amountController.text.trim(),
              category: category,
            );
      }
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(budgetsForMonthProvider);
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
      await ref.read(budgetsApiProvider).delete(existing.id);
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(budgetsForMonthProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final busy = _submitting || _deleting;
    final topLevelBudgetsAsync = ref.watch(budgetsForMonthProvider);

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isEdit ? 'Edit budget' : 'Add budget', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (ZAR)'),
          ),
          const SizedBox(height: 16),
          TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category (optional — leave blank for the overall total)')),
          if (!isEdit) ...[
            const SizedBox(height: 16),
            topLevelBudgetsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (budgets) {
                final topLevel = budgets.where((b) => b.parentBudgetId == null).toList();
                if (topLevel.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String?>(
                  initialValue: _parentBudgetId,
                  decoration: const InputDecoration(labelText: 'Parent budget (optional, for a sub-category)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None — top-level budget')),
                    for (final b in topLevel) DropdownMenuItem(value: b.id, child: Text(b.category ?? 'Total')),
                  ],
                  onChanged: (value) => setState(() => _parentBudgetId = value),
                );
              },
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: busy ? null : _submit,
            child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
          ),
          if (isEdit) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: busy ? null : _delete,
              child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ],
      ),
    );
  }
}
