import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import 'icon_chip.dart';
import 'percent_pill.dart';

/// Budget/goal progress row per DESIGN.md § Signature components — a
/// [RowCard]-shell card holding a title + [PercentPill], a linear progress
/// bar (never a ring — resolved by the delivered mockups), and a muted
/// footnote line. Used by Budgets, Goals, and the Dashboard progress block.
class ProgressCard extends StatefulWidget {
  const ProgressCard({
    required this.title,
    required this.pct,
    required this.footnote,
    this.overBudget = false,
    this.indented = false,
    this.icon,
    super.key,
  });

  final String title;

  /// 0.0-1.0+ (clamped for the bar; the pill shows the unclamped percentage).
  final double pct;
  final String footnote;
  final bool overBudget;
  final bool indented;

  /// Optional leading category icon per the Stitch Budgets mockup, which
  /// gives each category row a distinct icon rather than none at all. Null
  /// for rows with no natural category (e.g. Goals, the "Total" fallback
  /// row) — omitted rather than shown as a generic placeholder.
  final IconData? icon;

  @override
  State<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<ProgressCard> {
  late double _displayedPct = widget.pct;

  @override
  void didUpdateWidget(ProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pct != widget.pct) _displayedPct = oldWidget.pct;
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final barColor = widget.overBudget ? semantic?.danger : Theme.of(context).colorScheme.primary;
    final pctLabel = (widget.pct * 100).round();
    return Semantics(
      label:
          '${widget.title}, $pctLabel percent${widget.overBudget ? ', over budget' : ''}. ${widget.footnote}',
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.only(left: widget.indented ? 24 : 0, bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.icon != null) ...[
                      IconChip(icon: widget.icon!, danger: widget.overBudget),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium)),
                    PercentPill(pct: (widget.pct * 100).round(), danger: widget.overBudget),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: _displayedPct, end: widget.pct),
                    duration: AppMotion.valueTransition,
                    curve: AppMotion.easeOut,
                    onEnd: () => _displayedPct = widget.pct,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0),
                      minHeight: 8,
                      color: barColor,
                      backgroundColor: semantic?.accentChipBg,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.footnote,
                  style: TextStyle(color: widget.overBudget ? semantic?.danger : semantic?.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
