import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
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
    this.onTap,
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

  /// Makes the whole card the button, pressing on a spring (M4).
  final VoidCallback? onTap;

  @override
  State<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<ProgressCard> {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final pctLabel = (widget.pct * 100).round();
    final reduced = context.reducedMotion;
    return Semantics(
      label:
          '${widget.title}, $pctLabel percent${widget.overBudget ? ', over budget' : ''}. ${widget.footnote}',
      button: widget.onTap != null,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: AppCard(
          margin: EdgeInsets.only(left: widget.indented ? AppSpace.s24 : 0, bottom: AppSpace.rowGap),
          onTap: widget.onTap,
          // Crossing into over budget is one calm cue (M40): the bar and the
          // figures crossfade to danger over 400 ms and "Over by" fades in.
          // No shake. Only a change animates; the first frame is final.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.overBudget ? 1 : 0),
            duration: reduced ? Duration.zero : AppMotion.valueTransition,
            curve: AppMotion.easeOut,
            builder: (context, over, _) {
              Color toward(Color calm) => over <= 0 ? calm : (over >= 1 ? t.danger : Color.lerp(calm, t.danger, over)!);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.icon != null) ...[
                        IconChip(icon: widget.icon!, danger: widget.overBudget, family: widget.family, size: 40),
                        const SizedBox(width: AppSpace.s12),
                      ],
                      Expanded(child: Text(widget.title, style: text.titleMedium)),
                      AnimatedSwitcher(
                        duration: reduced ? Duration.zero : AppMotion.valueTransition,
                        child: PercentPill(
                          key: ValueKey(widget.overBudget),
                          pct: pctLabel,
                          danger: widget.overBudget,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s12),
                  PillBar(
                    value: widget.pct,
                    // Red only when a budget is over (J4); a goal past 100 %
                    // is good news and stays primary.
                    color: toward(t.primary),
                    track: t.sunk,
                    onReached: widget.onReached,
                  ),
                  const SizedBox(height: AppSpace.s8),
                  AnimatedSwitcher(
                    duration: reduced ? Duration.zero : AppMotion.valueTransition,
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                    child: Text(
                      widget.footnote,
                      key: ValueKey(widget.footnote),
                      style: text.bodySmall?.copyWith(color: toward(t.muted), fontSize: 13),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
