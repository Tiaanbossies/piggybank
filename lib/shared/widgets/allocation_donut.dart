import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/portfolios/asset_class_style.dart';
import '../../features/portfolios/models/holding.dart';
import '../../features/portfolios/models/investment_overview.dart';
import '../motion/chart_reveal.dart';
import 'app_card.dart';

/// Donut allocation-by-asset-class chart with a colour-swatch legend — the
/// Invest tab-root's allocation view per DESIGN.md §8 ("the mockup uses a
/// donut here, not the stacked bar"). See `AllocationBar` for the denser
/// per-portfolio stacked-bar variant used on Portfolio Detail instead.
class AllocationDonut extends StatelessWidget {
  const AllocationDonut({required this.items, super.key});
  final List<AllocationItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            // Sweeps in clockwise (M24); still under reduced motion.
            child: ChartReveal(
              style: ChartRevealStyle.sweep,
              child: PieChart(
                duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 28,
                  startDegreeOffset: -90,
                  sections: [
                    for (final item in items)
                      PieChartSectionData(
                        value: item.value.toDouble(),
                        color: assetClassColor(t, item.assetClass),
                        radius: 20,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items) _LegendRow(item: item, mutedColor: t.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.item, required this.mutedColor});
  final AllocationItem item;
  final Color? mutedColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: assetClassColor(context.tokens, item.assetClass), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(assetClassLabels[item.assetClass]!, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            '${_formatPercent(item.percent)}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: mutedColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPercent(Decimal pct) {
  final n = pct.toDouble();
  return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
}
