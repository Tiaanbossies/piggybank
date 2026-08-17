import 'package:flutter/material.dart';

import '../../goals/screens/goals_screen.dart';
import 'budgets_screen.dart';

/// Hosts the Budgets tab: a segmented toggle between Budgets and Goals
/// (grouped together per the Phase 2 plan scope; DESIGN.md's 5-tab nav has
/// no dedicated Goals slot).
class BudgetsHomeScreen extends StatefulWidget {
  const BudgetsHomeScreen({super.key});

  @override
  State<BudgetsHomeScreen> createState() => _BudgetsHomeScreenState();
}

class _BudgetsHomeScreenState extends State<BudgetsHomeScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_segment == 0 ? 'Budgets' : 'Goals')),
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
