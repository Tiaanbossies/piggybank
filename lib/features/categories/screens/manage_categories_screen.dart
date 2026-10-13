import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../../transactions/category_icons.dart';
import '../../transactions/providers/quick_add_providers.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../models/user_category.dart';
import '../providers/categories_provider.dart';
import '../widgets/category_field.dart';

/// Transactions → More → Manage categories (QA pass 1): add, rename and
/// delete the user's categories. A rename or delete rewrites every
/// transaction, budget and goal filed under it, server-side.
class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  static const fallback = 'Uncategorised';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('categories-add'),
        onPressed: () => showNewCategoryDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: SafeArea(
        child: AppRefresh(
          onRefresh: () => ref.refresh(categoriesProvider.future),
          child: SkeletonSwitcher(
            child: categoriesAsync.when(
              loading: () => const SkeletonRows(count: 8),
              error: (err, _) => ListView(children: [
                InlineError(
                  message: err is ApiError ? err.message : "Couldn't load your categories",
                  onRetry: () => ref.invalidate(categoriesProvider),
                ),
              ]),
              data: (categories) {
                final groups = [
                  ('Spending', categories.where((c) => c.kind == CategoryKind.expense).toList()),
                  ('Income', categories.where((c) => c.kind == CategoryKind.income).toList()),
                ];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s16, AppSpace.gutter, 96),
                  children: [
                    for (final (title, group) in groups)
                      if (group.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s8, top: AppSpace.s8),
                          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        GroupCard(
                          children: [
                            for (final c in group)
                              GroupRow(
                                key: ValueKey('category-${c.id}'),
                                leadingIcon: categoryIcon(c.name, isExpense: c.kind == CategoryKind.expense),
                                family: categoryFamily(c.name),
                                title: c.name,
                                onTap: () => _rename(context, ref, c),
                                trailing: IconButton(
                                  key: ValueKey('category-delete-${c.id}'),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete ${c.name}',
                                  onPressed: () => _delete(context, ref, c, categories),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s16),
                      ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Everything that shows a category name, once a rename or delete has
  /// rewritten them.
  static void _refreshAll(WidgetRef ref) {
    ref
      ..invalidate(categoriesProvider)
      ..invalidate(transactionsProvider)
      ..invalidate(recentTransactionsProvider)
      ..invalidate(categoryUsageProvider)
      ..invalidate(budgetsForMonthProvider)
      ..invalidate(budgetProgressProvider)
      ..invalidate(currentMonthBudgetProgressProvider)
      ..invalidate(goalsProvider);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, UserCategory category) async {
    final result = await showDialog<(String, CategoryKind)>(
      context: context,
      builder: (_) => _EditCategoryDialog(category: category),
    );
    if (result == null) return;
    final (name, newKind) = result;
    if (name.isEmpty || (name == category.name && newKind == category.kind)) return;
    try {
      await ref.read(categoriesApiProvider).update(
            category.id,
            name: name == category.name ? null : name,
            kind: newKind == category.kind ? null : newKind,
          );
      _refreshAll(ref);
    } on ApiError catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, UserCategory category, List<UserCategory> all) async {
    final others = [for (final c in all) if (c.id != category.id) c.name];
    if (category.name != fallback && !others.contains(fallback)) others.insert(0, fallback);
    if (others.isEmpty) return;
    final target = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteCategoryDialog(category: category, others: others),
    );
    if (target == null) return;
    try {
      await ref.read(categoriesApiProvider).delete(category.id, reassignTo: target);
      _refreshAll(ref);
    } on ApiError catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Rename and spending/income, returned as `(name, kind)`.
class _EditCategoryDialog extends StatefulWidget {
  const _EditCategoryDialog({required this.category});
  final UserCategory category;

  @override
  State<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<_EditCategoryDialog> {
  late final _controller = TextEditingController(text: widget.category.name);
  late CategoryKind _kind = widget.category.kind;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('category-rename'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              helperText: 'Renames it on every transaction, budget and goal.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<CategoryKind>(
            segments: const [
              ButtonSegment(value: CategoryKind.expense, label: Text('Spending')),
              ButtonSegment(value: CategoryKind.income, label: Text('Income')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const Key('category-rename-save'),
          onPressed: () => Navigator.of(context).pop((_controller.text.trim(), _kind)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Confirms a delete and picks where its items go; returns that name.
class _DeleteCategoryDialog extends StatefulWidget {
  const _DeleteCategoryDialog({required this.category, required this.others});
  final UserCategory category;
  final List<String> others;

  @override
  State<_DeleteCategoryDialog> createState() => _DeleteCategoryDialogState();
}

class _DeleteCategoryDialogState extends State<_DeleteCategoryDialog> {
  late String _target = widget.others.contains(ManageCategoriesScreen.fallback)
      ? ManageCategoriesScreen.fallback
      : widget.others.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete ${widget.category.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Anything filed under it moves to:'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('category-reassign'),
            initialValue: _target,
            isExpanded: true,
            items: [for (final n in widget.others) DropdownMenuItem(value: n, child: Text(n))],
            onChanged: (v) => setState(() => _target = v ?? _target),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          key: const Key('confirm-destroy'),
          style: TextButton.styleFrom(foregroundColor: context.tokens.danger),
          onPressed: () => Navigator.of(context).pop(_target),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
