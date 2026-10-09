import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_motion.dart';
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

  /// Whether the last segment change went leftwards, so the shared axis
  /// slides the way the segment control moved.
  bool _reverse = false;

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
    ref.listen(planSegmentProvider, (previous, next) {
      if (previous != null) _reverse = next.index < previous.index;
    });
    return Scaffold(
      appBar: TabAppBar(
        title: 'Plan',
        bottom: segment == PlanSegment.budgets ? const BudgetMonthSwitcher() : null,
      ),
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
              // Shared axis X (spec §3.1), in segment order.
              child: PageTransitionSwitcher(
                duration: context.reducedMotion ? Duration.zero : AppMotion.pageTransition,
                reverse: _reverse,
                transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
                  animation: primary,
                  secondaryAnimation: secondary,
                  transitionType: SharedAxisTransitionType.horizontal,
                  fillColor: Colors.transparent,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey(segment),
                  child: switch (segment) {
                    PlanSegment.budgets => const BudgetsBody(),
                    PlanSegment.goals => const GoalsBody(),
                    PlanSegment.savings => const SavingsPlanBody(),
                  },
                ),
              ),
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
