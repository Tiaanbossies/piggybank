import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/motion/saved_highlight.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/completed_goal_card.dart';
import '../../../shared/widgets/deferred_delete.dart';
import '../../../shared/widgets/expand_section.dart';
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

  /// Clears the Add goal button.
  static const _padding =
      EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s8, AppSpace.gutter, AppSpace.s16 + AppSpace.fabInset);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return AppRefresh(
      onRefresh: () => ref.refresh(goalsProvider.future),
      child: AnimatedSwitcher(
        duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
        switchInCurve: AppMotion.easeOut,
        switchOutCurve: AppMotion.easeOut,
        child: goalsAsync.when(
          loading: () => const SkeletonPage(key: ValueKey('loading'), progressCards: true),
          error: (err, _) => Center(
            key: const ValueKey('error'),
            child: InlineError(
              message: err is ApiError ? err.message : 'Failed to load goals',
              onRetry: () => ref.invalidate(goalsProvider),
            ),
          ),
          data: (all) {
            final hidden = ref.watch(pendingDeletesProvider);
            final goals = all.where((g) => !hidden.contains(g.id)).toList();
            if (goals.isEmpty) {
              return ListView(
                key: const ValueKey('empty'),
                primary: true,
                padding: _padding,
                children: const [
                  EmptyState(
                    icon: Icons.flag_outlined,
                    title: 'No goals yet.',
                    mascot: true,
                    hint: 'Tap "Add goal" below to set one up.',
                  ),
                ],
              );
            }
            // Deleted goals stay in the list while they slide out (M15) and
            // grow back on Undo; only the empty check ignores them.
            final inProgress = all.where((g) => g.status != GoalStatus.completed).toList()..sort(_byTargetDate);
            final completed = all.where((g) => g.status == GoalStatus.completed).toList();
            final completedShown = completed.where((g) => !hidden.contains(g.id)).length;
            return ListView(
              key: const ValueKey('list'),
              primary: true,
              padding: _padding,
              children: [
                for (final goal in inProgress) DeleteExit(id: goal.id, child: _GoalRow(goal: goal)),
                if (completedShown > 0)
                  // Grows open with a size transition (M29).
                  ExpandSection(
                    key: const Key('goals-completed'),
                    title: 'Completed ($completedShown)',
                    child: Column(
                      children: [for (final goal in completed) DeleteExit(id: goal.id, child: _GoalRow(goal: goal))],
                    ),
                  ),
              ],
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
    void edit() => showEditGoalSheet(context, goal);
    final child = goal.status == GoalStatus.completed
        ? CompletedGoalCard(
            key: Key('goal-${goal.id}'),
            title: goal.name,
            footnote: footnote,
            goalId: goal.id,
            onTap: edit,
          )
        : ProgressCard(
            key: Key('goal-${goal.id}'),
            title: goal.name,
            pct: goal.progressPct / 100,
            footnote: footnote,
            onTap: edit,
          );
    return SavedHighlight(
      id: goal.id,
      radius: AppRadius.card,
      inset: const EdgeInsets.only(bottom: AppSpace.rowGap),
      child: child,
    );
  }
}

/// The goal you can still move comes first (spec §2.3, Y8): soonest target
/// date first, goals without a date last.
int _byTargetDate(Goal a, Goal b) {
  final da = a.targetDate;
  final db = b.targetDate;
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
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
    final now = clock.now();
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
        final created = await ref.read(goalsApiProvider).create(
              name: name,
              targetAmount: targetAmount,
              currentAmount: currentAmount,
              targetDate: _targetDate,
            );
        markSaved(ref, created.id);
      } else {
        await ref.read(goalsApiProvider).update(
              widget.existing!.id,
              name: name,
              targetAmount: targetAmount,
              currentAmount: currentAmount,
              targetDate: _targetDate,
            );
        markSaved(ref, widget.existing!.id);
      }
      ref.invalidate(goalsProvider);
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
      message: '${existing.name} deleted',
      commit: (c) async {
        await c.read(goalsApiProvider).delete(existing.id);
        c.invalidate(goalsProvider);
      },
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final busy = _submitting;
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
