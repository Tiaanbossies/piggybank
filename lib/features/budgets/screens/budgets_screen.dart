import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/motion/saved_highlight.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/deferred_delete.dart';
import '../../../shared/widgets/progress_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../categories/models/user_category.dart';
import '../../categories/providers/categories_provider.dart';
import '../../categories/widgets/category_field.dart';
import '../../summaries/providers/summaries_provider.dart';
import '../../transactions/category_icons.dart';
import '../../trends/screens/trends_screen.dart';
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

/// Body content for the Budgets segment of Plan: the "Total spent" summary
/// card above one progress card per budget, sub-categories indented under
/// their parent. Red appears only on a card that is over (J4, M40).
class BudgetsBody extends ConsumerWidget {
  const BudgetsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(budgetProgressProvider);
    const padding = EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s8, AppSpace.gutter, AppSpace.s16 + AppSpace.fabInset);

    return AppRefresh(
      onRefresh: () => ref.refresh(budgetProgressProvider.future),
      // A month change slides the content the way the month moved (M26).
      child: _MonthSlide(
        month: ref.watch(selectedBudgetMonthProvider),
        child: AnimatedSwitcher(
          duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
          switchInCurve: AppMotion.easeOut,
          switchOutCurve: AppMotion.easeOut,
          child: progressAsync.when(
            loading: () => const SkeletonPage(key: ValueKey('loading'), progressCards: true),
            error: (err, _) => Center(
              key: const ValueKey('error'),
              child: InlineError(
                message: err is ApiError ? err.message : 'Failed to load budgets',
                onRetry: () => ref.invalidate(budgetProgressProvider),
              ),
            ),
            data: (all) {
              final hidden = ref.watch(pendingDeletesProvider);
              final budgets = all.where((b) => !hidden.contains(b.id)).toList();
              if (budgets.isEmpty) {
                return ListView(
                  key: const ValueKey('empty'),
                  primary: true,
                  padding: padding,
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
                primary: true,
                padding: padding,
                children: [
                  _TotalSpentSummary(budgets: budgets),
                  const SizedBox(height: AppSpace.s12),
                  // A deleted budget stays in the list while it slides out
                  // (M15), and grows back on Undo.
                  for (final budget in all) ...[
                    DeleteExit(id: budget.id, child: _BudgetProgressRow(progress: budget)),
                    for (final child in budget.children)
                      DeleteExit(id: child.id, child: _BudgetProgressRow(progress: child, indented: true)),
                  ],
                  // A second way into Trends (spec §2.3): budget vs actual
                  // lives there, next to the budgets it explains.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('budgets-see-trends'),
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrendsScreen())),
                      child: const Text('See trends ›'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Slides its content in from 24 dp on the side the month moved towards
/// and fades it up (M26: 200 ms). Under reduced motion it's a 150 ms fade.
/// Only the arriving month moves: the leaving one is already loading.
class _MonthSlide extends StatefulWidget {
  const _MonthSlide({required this.month, required this.child});
  final DateTime month;
  final Widget child;

  static const distance = 24.0;

  @override
  State<_MonthSlide> createState() => _MonthSlideState();
}

class _MonthSlideState extends State<_MonthSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _arrive = AnimationController(vsync: this, duration: AppMotion.stateChange, value: 1);

  /// 1 when the month went forward (content arrives from the right), -1
  /// when it went back.
  double _direction = 1;

  @override
  void didUpdateWidget(_MonthSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month == widget.month) return;
    _direction = widget.month.isAfter(oldWidget.month) ? 1 : -1;
    _arrive
      ..duration = context.reducedMotion ? AppMotion.feedback : AppMotion.stateChange
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _arrive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _arrive,
      child: widget.child,
      builder: (context, child) {
        final v = AppMotion.easeOut.transform(_arrive.value);
        final dx = context.reducedMotion ? 0.0 : _direction * _MonthSlide.distance * (1 - v);
        return Opacity(
          opacity: v,
          child: Transform.translate(key: const Key('month-slide'), offset: Offset(dx, 0), child: child),
        );
      },
    );
  }
}

/// Previous / month / next, shown under the Plan app bar while the Budgets
/// segment is open (spec §2.3), so it no longer competes with the segment
/// control for the same row. Each step ticks once (M26).
class BudgetMonthSwitcher extends ConsumerWidget implements PreferredSizeWidget {
  const BudgetMonthSwitcher({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedBudgetMonthProvider);
    final notifier = ref.read(selectedBudgetMonthProvider.notifier);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
              onPressed: () {
                unawaited(AppHaptics.selection());
                notifier.previous();
              },
            ),
            // With a salary day, the dates it covers sit under the name:
            // "October 2026 · 25 Sep – 24 Oct" (QA pass 1).
            Builder(builder: (context) {
              final range = ref.watch(payPeriodForLabelProvider(month)).rangeLabel;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_monthNames[month.month - 1]} ${month.year}', style: Theme.of(context).textTheme.titleMedium),
                  if (range.isNotEmpty)
                    Text(
                      range,
                      key: const Key('budget-period-range'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
                    ),
                ],
              );
            }),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
              onPressed: () {
                unawaited(AppHaptics.selection());
                notifier.next();
              },
            ),
          ],
        ),
      ),
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
    return SavedHighlight(
      id: progress.id,
      radius: AppRadius.card,
      inset: EdgeInsets.only(left: indented ? AppSpace.s24 : 0, bottom: AppSpace.rowGap),
      child: ProgressCard(
        key: Key('budget-${progress.id}'),
        title: progress.category ?? 'Total',
        pct: pct,
        overBudget: progress.overBudget,
        indented: indented,
        icon: progress.category == null ? null : categoryIcon(progress.category),
        footnote: progress.overBudget
            ? overByLabel(progress.remaining.abs())
            : '${formatZAR(progress.spent)} / ${formatZAR(progress.budgetAmount)}',
        onTap: () => showEditBudgetSheet(context, progress),
      ),
    );
  }
}

/// The one line an over budget gets (M40): "Over by R 150,00".
String overByLabel(Decimal amount) => 'Over by ${formatZAR(amount)}';

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
          ? overByLabel(spent - budgetAmount)
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
  String? _category;
  late final TextEditingController _amountController;
  String? _parentBudgetId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _category = existing?.category;
    _amountController = TextEditingController(text: existing != null ? existing.budgetAmount.toString() : '');
    _parentBudgetId = existing?.parentBudgetId;
  }

  @override
  void dispose() {
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
      final category = (_category == null || _category!.trim().isEmpty) ? null : _category!.trim();
      if (widget.existing == null) {
        final created = await ref.read(budgetsApiProvider).create(
              month: month,
              totalBudget: _amountController.text.trim(),
              category: category,
              parentBudgetId: _parentBudgetId,
            );
        markSaved(ref, created.id);
      } else {
        await ref.read(budgetsApiProvider).update(
              widget.existing!.id,
              totalBudget: _amountController.text.trim(),
              category: category,
            );
        markSaved(ref, widget.existing!.id);
      }
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(budgetsForMonthProvider);
      ref.invalidate(categoriesProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Undo instead of a confirm (spec §5).
  void _delete() {
    final existing = widget.existing;
    if (existing == null) return;
    deferDelete(
      context,
      id: existing.id,
      message: '${existing.category ?? 'Total'} budget deleted',
      commit: (c) async {
        await c.read(budgetsApiProvider).delete(existing.id);
        c
          ..invalidate(budgetProgressProvider)
          ..invalidate(budgetsForMonthProvider);
      },
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final busy = _submitting;
    final topLevelBudgetsAsync = ref.watch(budgetsForMonthProvider);

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      // Scrolls once the keyboard and the category field don't both fit.
      child: SingleChildScrollView(
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
          // The same list as transactions (QA E2), so a budget's spend is
          // matched against a name transactions can actually carry.
          CategoryField(
            key: const Key('budget-category'),
            value: _category,
            kind: CategoryKind.expense,
            noneLabel: 'Overall total (no category)',
            onChanged: (value) => setState(() => _category = value),
          ),
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
      ),
    );
  }
}
