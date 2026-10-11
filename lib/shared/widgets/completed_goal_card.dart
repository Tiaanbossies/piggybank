import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';
import 'app_card.dart';
import 'hero_metric_card.dart';
import 'mascot_moment.dart';

/// Row card for a goal that has hit `GoalStatus.completed`, in place of the
/// usual progress card: celebrating Penny at 64 dp beside the name, a full
/// bar and the footnote (visual spec §4.1, M39).
///
/// The first time a goal is seen complete Penny pops on [AppMotion.springPop]
/// with one medium tap, and the bar gives one soft brightness pulse (M23).
/// That happens once ever per goal; after it, and under reduced motion, the
/// card is still.
class CompletedGoalCard extends StatefulWidget {
  const CompletedGoalCard({required this.title, required this.footnote, this.goalId, this.onTap, super.key});
  final String title;
  final String footnote;

  /// When given, Penny pops the first time this goal is seen complete
  /// (spec §3.3), and only ever that once.
  final String? goalId;

  /// Makes the whole card the button.
  final VoidCallback? onTap;

  static const pennySize = 64.0;

  @override
  State<CompletedGoalCard> createState() => _CompletedGoalCardState();
}

class _CompletedGoalCardState extends State<CompletedGoalCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: AppMotion.valueTransition);

  void _popped() {
    // Penny claims the moment while she's being built; the bar joins in on
    // the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pulse.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final goalId = widget.goalId;
    final bright = HSLColor.fromColor(t.primary);
    final brighter = bright.withLightness(math.min(1, bright.lightness + 0.18)).toColor();
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.rowGap),
      onTap: widget.onTap,
      semanticLabel: '${widget.title}, goal reached. ${widget.footnote}',
      child: Row(
        children: [
          MascotMoment(
            asset: MascotMoment.celebrating,
            size: CompletedGoalCard.pennySize,
            motion: goalId == null ? MascotMotion.none : MascotMotion.pop,
            kind: goalId == null ? null : 'goal-reached.$goalId',
            daily: false,
            onPop: _popped,
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(widget.title, style: text.titleMedium)),
                    Text('Goal reached', style: text.labelMedium?.copyWith(color: t.primary)),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => PillBar(
                    key: const Key('goal-pulse'),
                    value: 1,
                    // One soft rise and fall in brightness.
                    color: _pulse.isAnimating
                        ? Color.lerp(t.primary, brighter, math.sin(math.pi * _pulse.value))!
                        : t.primary,
                    track: t.sunk,
                  ),
                ),
                const SizedBox(height: AppSpace.s8),
                Text(widget.footnote, style: text.bodySmall?.copyWith(color: t.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
