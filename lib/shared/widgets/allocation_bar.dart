import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/portfolios/asset_class_style.dart';
import '../../features/portfolios/models/holding.dart';
import '../../features/portfolios/models/investment_overview.dart';

/// Horizontal stacked-bar allocation-by-asset-class view with a compact
/// legend beneath it — Portfolio Detail's denser variant per DESIGN.md §9
/// ("a simple allocation block (horizontal stacked bar, not a donut, for
/// mobile-width legibility)"). See `AllocationDonut` for the Invest
/// tab-root's donut variant instead. Renders nothing if [items] is empty —
/// per DESIGN.md §9, no empty-state placeholder is needed here.
class AllocationBar extends StatelessWidget {
  const AllocationBar({required this.items, super.key});
  final List<AllocationItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    flex: (item.percent.toDouble() * 100).round().clamp(1, 100000),
                    child: Container(color: assetClassColors[item.assetClass]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final item in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: assetClassColors[item.assetClass], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${assetClassLabels[item.assetClass]} · ${_formatPercent(item.percent)}%',
                    style: TextStyle(color: semantic?.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

String _formatPercent(Decimal pct) {
  final n = pct.toDouble();
  return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
}
