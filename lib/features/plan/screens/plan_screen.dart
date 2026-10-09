import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/tab_app_bar.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../budgets/screens/budgets_screen.dart';
import '../../goals/screens/goals_screen.dart';
import '../../savings/screens/savings_plan_screen.dart';

/// The three things Plan holds, in segment order.
enum PlanSegment { budgets, goals, savings }

/// Which Plan segment is showing. UI-only state: a Home card sets it before
/// switching to the tab (`context.go('/plan')`), so "Rent: gap R 3 967"
/// lands on Savings even when the tab was last left on Budgets.
final planSegmentProvider = StateProvider<PlanSegment>((ref) => PlanSegment.budgets);

/// The Plan tab (UX rework spec §2.3): Budgets, Goals and the Savings plan
/// behind one segmented control. It replaces the Budgets tab's two-segment
/// host and the Savings plan's pushed screen.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  /// The tab stays alive in the shell's IndexedStack for as long as the
  /// app process does — days, on a phone — so "open the app" is usually a
  /// resume, not a rebuild. That's the moment a turned month must show.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(selectedBudgetMonthProvider.notifier).syncToCurrentMonth(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segment = ref.watch(planSegmentProvider);
    return Scaffold(
      appBar: const TabAppBar(title: 'Plan'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<PlanSegment>(
                segments: const [
                  ButtonSegment(value: PlanSegment.budgets, label: Text('Budgets')),
                  ButtonSegment(value: PlanSegment.goals, label: Text('Goals')),
                  ButtonSegment(value: PlanSegment.savings, label: Text('Savings')),
                ],
                selected: {segment},
                onSelectionChanged: (selection) => ref.read(planSegmentProvider.notifier).state = selection.first,
              ),
            ),
            Expanded(
              child: switch (segment) {
                PlanSegment.budgets => const BudgetsBody(),
                PlanSegment.goals => const GoalsBody(),
                PlanSegment.savings => const SavingsPlanBody(),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: switch (segment) {
        PlanSegment.budgets => FloatingActionButton.extended(
            onPressed: () => showAddBudgetSheet(context),
            label: const Text('Add budget'),
            icon: const Icon(Icons.add),
          ),
        PlanSegment.goals => FloatingActionButton.extended(
            onPressed: () => showAddGoalSheet(context),
            label: const Text('Add goal'),
            icon: const Icon(Icons.add),
          ),
        PlanSegment.savings => FloatingActionButton.extended(
            onPressed: () => showRecurringCostSheet(context),
            label: const Text('Add cost'),
            icon: const Icon(Icons.add),
          ),
      },
    );
  }
}
