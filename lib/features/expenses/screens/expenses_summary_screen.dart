import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../providers/expenses_provider.dart';

/// Read-model over transactions per the parity matrix — category/total
/// breakdown, with a date-range filter, no CRUD of its own.
class ExpensesSummaryScreen extends ConsumerWidget {
  const ExpensesSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(expensesSummaryProvider);
    final range = ref.watch(expensesDateRangeProvider);
    final hasFilter = range.dateFrom != null || range.dateTo != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by date',
            onPressed: () => _pickDateRange(context, ref),
          ),
          if (hasFilter)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear filter',
              onPressed: () => ref.read(expensesDateRangeProvider.notifier).clear(),
            ),
        ],
      ),
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load expenses')),
          data: (summary) {
            if (summary.byCategory.isEmpty) {
              return const Center(child: Text('No expenses in this period.'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Total', style: Theme.of(context).textTheme.labelMedium),
                Text(formatZAR(summary.total), style: moneyTextStyle(context, fontSize: 28)),
                const SizedBox(height: 24),
                const SizedBox(height: 8),
                Text('By category', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 12),
                GroupCard(
                  children: [
                    for (final bucket in summary.byCategory)
                      GroupRow(
                        leadingIcon: Icons.donut_small_outlined,
                        title: bucket.category.isEmpty ? 'Uncategorised' : bucket.category,
                        subtitle: '${bucket.count} transaction${bucket.count == 1 ? '' : 's'}',
                        trailing: Text(formatZAR(bucket.total), style: moneyTextStyle(context, fontSize: 15)),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(expensesDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: current.dateFrom != null && current.dateTo != null
          ? DateTimeRange(start: current.dateFrom!, end: current.dateTo!)
          : null,
    );
    if (picked != null) {
      ref.read(expensesDateRangeProvider.notifier)
        ..setDateFrom(picked.start)
        ..setDateTo(picked.end);
    }
  }
}
