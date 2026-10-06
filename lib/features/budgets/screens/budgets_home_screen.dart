import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../goals/screens/goals_screen.dart';
import '../providers/budgets_provider.dart';
import 'budgets_screen.dart';

/// Hosts the Budgets tab: a segmented toggle between Budgets and Goals
/// (grouped together per the Phase 2 plan scope; DESIGN.md's 5-tab nav has
/// no dedicated Goals slot).
class BudgetsHomeScreen extends ConsumerStatefulWidget {
  const BudgetsHomeScreen({super.key});

  @override
  ConsumerState<BudgetsHomeScreen> createState() => _BudgetsHomeScreenState();
}

class _BudgetsHomeScreenState extends ConsumerState<BudgetsHomeScreen> {
  int _segment = 0;

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
    return Scaffold(
      // Tab-root app bar (avatar/title/bell) per DESIGN.md § Navigation —
      // Budgets is listed as a tab-root screen, was shipped with a bare
      // title and no avatar/bell, matching neither Dashboard nor Invest.
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: CircleAvatar(child: Icon(Icons.person_outline, size: 18)),
        ),
        title: Text(_segment == 0 ? 'Budgets' : 'Goals'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Budgets')),
                  ButtonSegment(value: 1, label: Text('Goals')),
                ],
                selected: {_segment},
                onSelectionChanged: (selection) => setState(() => _segment = selection.first),
              ),
            ),
            Expanded(child: _segment == 0 ? const BudgetsBody() : const GoalsBody()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _segment == 0 ? showAddBudgetSheet(context) : showAddGoalSheet(context),
        label: Text(_segment == 0 ? 'Add budget' : 'Add goal'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
