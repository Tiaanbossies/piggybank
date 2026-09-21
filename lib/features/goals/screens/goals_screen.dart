import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/progress_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../models/goal.dart';
import '../providers/goals_provider.dart';

Future<void> showEditGoalSheet(BuildContext context, Goal existing) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GoalSheet(existing: existing),
  );
}

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
      child: AnimatedSwitcher(
        duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
        switchInCurve: AppMotion.easeOut,
        switchOutCurve: AppMotion.easeOut,
        child: goalsAsync.when(
          loading: () => const Center(key: ValueKey('loading'), child: CircularProgressIndicator()),
          error: (err, _) => Center(
            key: const ValueKey('error'),
            child: InlineError(message: err is ApiError ? err.message : 'Failed to load goals'),
          ),
          data: (goals) {
            if (goals.isEmpty) {
              return ListView(
                key: const ValueKey('empty'),
                padding: const EdgeInsets.all(16),
                children: const [
                  EmptyState(
                    icon: Icons.flag_outlined,
                    title: 'No goals yet.',
                    hint: 'Tap "Add goal" below to set one up.',
                  ),
                ],
              );
            }
            return ListView(
              key: const ValueKey('list'),
              padding: const EdgeInsets.all(16),
              children: [for (final goal in goals) _GoalRow(goal: goal)],
            );
          },
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final targetDate = goal.targetDate;
    final footnote = '${formatZAR(goal.currentAmount)} saved / ${formatZAR(goal.targetAmount)} goal'
        '${targetDate == null ? '' : ' / by ${_formatDate(targetDate)}'}';
    final child = goal.status == GoalStatus.completed
        ? _CompletedGoalCard(title: goal.name, footnote: footnote)
        : ProgressCard(
            title: goal.name,
            pct: goal.progressPct / 100,
            footnote: footnote,
          );
    return InkWell(onTap: () => showEditGoalSheet(context, goal), child: child);
  }
}

/// Row card for a goal that has hit `GoalStatus.completed`, shown instead of
/// the usual [ProgressCard] once there's nothing left to track progress
/// toward. Matches [ProgressCard]'s card/padding shell (no shared `RowCard`
/// widget exists to reuse) so it reads as the same list, not a new pattern.
class _CompletedGoalCard extends StatelessWidget {
  const _CompletedGoalCard({required this.title, required this.footnote});
  final String title;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/mascot_celebrating.jpg', width: 44, height: 44, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                      Text(
                        'Goal complete!',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(footnote, style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

Future<void> showAddGoalSheet(BuildContext context) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _GoalSheet());
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({this.existing});
  final Goal? existing;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _currentController;
  DateTime? _targetDate;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _targetController = TextEditingController(text: existing != null ? existing.targetAmount.toString() : '');
    _currentController = TextEditingController(text: existing != null ? existing.currentAmount.toString() : '0');
    _targetDate = existing?.targetDate;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 50),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

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
      final name = _nameController.text.trim();
      final targetAmount = _targetController.text.trim();
      final currentAmount = _currentController.text.trim().isEmpty ? null : _currentController.text.trim();
      if (widget.existing == null) {
        await ref.read(goalsApiProvider).create(
              name: name,
              targetAmount: targetAmount,
              currentAmount: currentAmount,
              targetDate: _targetDate,
            );
      } else {
        await ref.read(goalsApiProvider).update(
              widget.existing!.id,
              name: name,
              targetAmount: targetAmount,
              currentAmount: currentAmount,
              targetDate: _targetDate,
            );
      }
      ref.invalidate(goalsProvider);
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
      await ref.read(goalsApiProvider).delete(existing.id);
      ref.invalidate(goalsProvider);
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
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isEdit ? 'Edit goal' : 'Add goal', style: Theme.of(context).textTheme.titleLarge),
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Target date (optional)'),
            subtitle: Text(_targetDate == null ? 'None set' : _formatDate(_targetDate!)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
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
