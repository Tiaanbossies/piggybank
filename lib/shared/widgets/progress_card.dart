import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'app_card.dart';
import 'hero_metric_card.dart';
import 'icon_chip.dart';
import 'percent_pill.dart';

/// Budget/goal progress row: an [AppCard] holding a title + [PercentPill],
/// the 8 dp [PillBar] on a sunk track (never a ring), and a muted footnote
/// line. Used by Budgets, Goals, and the Dashboard progress block.
class ProgressCard extends StatefulWidget {
  const ProgressCard({
    required this.title,
    required this.pct,
    required this.footnote,
    this.overBudget = false,
    this.indented = false,
    this.icon,
    this.family,
    this.onReached,
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

  /// The category's tile family, when [icon] is a category's.
  final CategoryFamily? family;

  /// Fires once the bar lands on 100 % — the goal step's pulse hook (M23).
  final VoidCallback? onReached;

  @override
  State<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<ProgressCard> {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final pctLabel = (widget.pct * 100).round();
    return Semantics(
      label:
          '${widget.title}, $pctLabel percent${widget.overBudget ? ', over budget' : ''}. ${widget.footnote}',
      child: ExcludeSemantics(
        child: AppCard(
          margin: EdgeInsets.only(left: widget.indented ? 24 : 0, bottom: AppSpace.rowGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.icon != null) ...[
                    IconChip(icon: widget.icon!, danger: widget.overBudget, family: widget.family, size: 40),
                    const SizedBox(width: AppSpace.s12),
                  ],
                  Expanded(child: Text(widget.title, style: text.titleMedium)),
                  PercentPill(pct: pctLabel, danger: widget.overBudget),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              PillBar(
                value: widget.pct,
                // Red only when a budget is over (J4); a goal past 100 % is
                // good news and stays primary.
                color: widget.overBudget ? t.danger : t.primary,
                track: t.sunk,
                onReached: widget.onReached,
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                widget.footnote,
                style: text.bodySmall?.copyWith(color: widget.overBudget ? t.danger : t.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
