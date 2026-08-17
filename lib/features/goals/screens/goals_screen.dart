import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../shared/widgets/progress_card.dart';
import '../models/goal.dart';
import '../providers/goals_provider.dart';

/// Body content for the Goals sub-view of the Budgets tab (per the Phase 2
/// scope grouping Budgets and Goals together; DESIGN.md has no dedicated
/// nav slot for Goals, so it lives as a second view alongside Budgets
/// rather than adding a 6th bottom-nav destination).
class GoalsBody extends ConsumerWidget {
  const GoalsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(goalsProvider.future),
      child: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load goals')),
        data: (goals) {
          if (goals.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [Center(child: Padding(padding: EdgeInsets.only(top: 48), child: Text('No goals yet.')))],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final goal in goals) _GoalRow(goal: goal)],
          );
        },
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return ProgressCard(
      title: goal.name,
      pct: goal.progressPct / 100,
      footnote: '${formatZAR(goal.currentAmount)} / ${formatZAR(goal.targetAmount)} goal',
    );
  }
}

Future<void> showAddGoalSheet(BuildContext context) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _GoalSheet());
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet();

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController(text: '0');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(goalsApiProvider).create(
            name: _nameController.text.trim(),
            targetAmount: _targetController.text.trim(),
            currentAmount: _currentController.text.trim().isEmpty ? null : _currentController.text.trim(),
          );
      ref.invalidate(goalsProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add goal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Goal name')),
          const SizedBox(height: 16),
          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Target amount (ZAR)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _currentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Starting amount (ZAR)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
