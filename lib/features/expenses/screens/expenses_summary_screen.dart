import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../providers/expenses_provider.dart';

/// Read-model over transactions per the parity matrix — category/total
/// breakdown, with a date-range filter, no CRUD of its own. Uses a
/// horizontal stacked bar (not a donut) per `stitch-design-brief.md` §8's
/// "Expenses summary" — resolving its open donut-vs-bar question in favour
/// of the bar, consistent with Portfolio detail's own allocation treatment
/// ("not a donut, for mobile-width legibility").
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
                HeroMetricCard(label: 'Total', value: formatZAR(summary.total)),
                const SizedBox(height: 24),
                _ExpenseAllocationBar(categories: summary.byCategory, colors: _chartColors(summary.byCategory.length)),
                const SizedBox(height: 24),
                const SizedBox(height: 12),
                Text('By category', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 12),
                GroupCard(
                  children: [
                    for (var i = 0; i < summary.byCategory.length; i++)
                      _CategoryRow(
                        bucket: summary.byCategory[i],
                        color: _chartColors(summary.byCategory.length)[i],
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

/// Horizontal stacked-bar allocation view for expense categories — the
/// same visual language as Portfolio detail's `AllocationBar`, but built
/// inline here since categories are freeform user text (no fixed enum like
/// [AssetClass] for `AllocationBar` to key off), sized by each category's
/// share of the period total. The "By category" [GroupCard] list beneath
/// already carries the per-category legend (colour dot, name, amount), so
/// this bar has no legend of its own.
class _ExpenseAllocationBar extends StatelessWidget {
  const _ExpenseAllocationBar({required this.categories, required this.colors});
  final List<dynamic> categories;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final total = categories.fold(0.0, (sum, bucket) => sum + bucket.total.toDouble());
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (var i = 0; i < categories.length; i++)
              Expanded(
                flex: (categories[i].total.toDouble() / total * 1000).round().clamp(1, 100000),
                child: Container(color: colors[i]),
              ),
          ],
        ),
      ),
    );
  }
}

/// A brand-derived qualitative palette for the pie chart and category list —
/// lightness steps around the accent hue rather than an arbitrary rainbow,
/// per DESIGN.md's "one confident green accent" identity (a categorical data
/// palette stays in-hue even where individual UI chrome wouldn't).
List<Color> _chartColors(int count) {
  if (count <= 0) return const [];
  final hsl = HSLColor.fromColor(AppColors.lightAccent);
  return List.generate(count, (i) {
    final t = count == 1 ? 0.0 : i / (count - 1);
    final lightness = (0.28 + t * 0.45).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  });
}

/// Category row tying its leading dot to the same colour as its pie slice —
/// replaces [GroupRow]'s fixed accent [IconChip], which can't vary colour
/// per row; categories are freeform user text, not a fixed enum, so a
/// type-icon map (as used for [AssetType]/[LiabilityType]) doesn't apply.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.bucket, required this.color});
  final dynamic bucket;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bucket.category.isEmpty ? 'Uncategorised' : bucket.category,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${bucket.count} transaction${bucket.count == 1 ? '' : 's'}',
                  style: TextStyle(color: semantic?.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatZAR(bucket.total), style: moneyTextStyle(context, fontSize: 15)),
        ],
      ),
    );
  }
}
