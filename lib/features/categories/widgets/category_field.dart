import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../models/user_category.dart';
import '../providers/categories_provider.dart';

const _newCategory = '\u0000new';
const _noCategory = '\u0000none';

/// The one category picker (QA pass 1): the user's own list, with
/// "+ New category" at the foot. Used by the transaction sheet, the
/// Transactions filter and the budget and goal sheets, so a category made
/// in any of them is there in all of them.
///
/// [noneLabel], when set, adds a first "no category" entry (the filter's
/// "All categories", a budget's overall total) that reports `null`.
class CategoryField extends ConsumerWidget {
  const CategoryField({
    required this.value,
    required this.onChanged,
    this.kind,
    this.label = 'Category',
    this.noneLabel,
    this.allowNew = true,
    this.enabled = true,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final CategoryKind? kind;
  final String label;
  final String? noneLabel;
  final bool allowNew;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull;
    final current = (value == null || value!.trim().isEmpty) ? null : value;
    final names = categoryChoices(categories, kind: kind, include: current);
    final selected = current == null
        ? (noneLabel != null ? _noCategory : null)
        : names.firstWhere((n) => n.toLowerCase() == current.toLowerCase(), orElse: () => current);

    return DropdownButtonFormField<String>(
      // Re-keyed on the value so an outside change (a chip tap, a new
      // category) shows here too: `initialValue` is otherwise read once.
      key: ValueKey('category-field-$selected-${names.length}'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (noneLabel != null) DropdownMenuItem(value: _noCategory, child: Text(noneLabel!)),
        for (final n in names) DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis)),
        if (allowNew)
          const DropdownMenuItem(
            value: _newCategory,
            child: Row(children: [Icon(Icons.add, size: 18), SizedBox(width: 8), Text('New category')]),
          ),
      ],
      onChanged: !enabled
          ? null
          : (picked) async {
              if (picked == _newCategory) {
                final created = await showNewCategoryDialog(context, ref, kind: kind ?? CategoryKind.expense);
                // Back to what it was if cancelled; the re-key resets the field.
                onChanged(created ?? current);
                return;
              }
              onChanged(picked == _noCategory ? null : picked);
            },
    );
  }
}

/// Asks for a name, adds it to the list, and returns it (null if cancelled).
Future<String?> showNewCategoryDialog(
  BuildContext context,
  WidgetRef ref, {
  CategoryKind kind = CategoryKind.expense,
}) {
  return showDialog<String>(context: context, builder: (_) => _NewCategoryDialog(kind: kind));
}

class _NewCategoryDialog extends ConsumerStatefulWidget {
  const _NewCategoryDialog({required this.kind});
  final CategoryKind kind;

  @override
  ConsumerState<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends ConsumerState<_NewCategoryDialog> {
  final _controller = TextEditingController();
  late CategoryKind _kind = widget.kind;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ref.read(categoriesApiProvider).create(name, kind: _kind);
      ref.invalidate(categoriesProvider);
      if (mounted) Navigator.of(context).pop(created.name);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('new-category-name'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
            onSubmitted: (_) => _save(),
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
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const Key('new-category-save'),
          onPressed: _saving ? null : _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
