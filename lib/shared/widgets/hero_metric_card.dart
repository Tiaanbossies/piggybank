import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';
import '../motion/count_up_text.dart';
import 'app_card.dart';

/// The light hero panel (visual spec §1.1, §3): one per screen, at the top,
/// for the screen's main figure. Light mode is the pale `hero` green with
/// dark ink; dark mode is the tonal deep green, never the brightest thing on
/// screen. Never repeated as a pattern for lesser numbers.
///
/// An `overline` label, a `display` figure in whole rand (the hero shows no
/// cents), an optional 8 dp pill bar and a `bodySmall` line. With [onTap]
/// the whole card is the button.
class HeroMetricCard extends StatelessWidget {
  const HeroMetricCard({
    required this.label,
    required this.value,
    this.amount,
    this.deltaText,
    this.progress,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;

  /// [value] as a number. When given, a change counts to the new figure
  /// (M21) instead of snapping.
  final double? amount;

  /// The line under the figure.
  final String? deltaText;

  /// 0–1 for the pill bar (clamped); no bar when null.
  final double? progress;
  final VoidCallback? onTap;

  /// "R 4 210,60" → "R 4 211": the hero reads at a glance, cents add noise.
  /// Rounds to the nearest rand; text that isn't a formatted amount ("—")
  /// passes through.
  static String wholeRand(String formatted) {
    final match = RegExp(r'^(-?)R\s*([\d\s]+),(\d{2})$').firstMatch(formatted.trim());
    if (match == null) return formatted;
    final rand = double.parse('${match[2]!.replaceAll(RegExp(r'\s'), '')}.${match[3]}');
    final whole = formatZAR((match[1]!.isEmpty ? rand : -rand).roundToDouble());
    return whole.replaceFirst(RegExp(r',00$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final valueStyle = text.displaySmall?.copyWith(color: t.heroInk);
    final shown = wholeRand(value);
    return AppCard(
      color: t.hero,
      onTap: onTap,
      semanticLabel: onTap == null ? null : '$label, $shown',
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.labelSmall?.copyWith(color: t.heroInk)),
            const SizedBox(height: AppSpace.s8),
            if (amount == null)
              Text(shown, style: valueStyle?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]))
            else
              CountUpText(
                text: shown,
                amount: amount!,
                style: valueStyle,
                format: (v) => wholeRand(formatZAR(v)),
              ),
            if (progress != null) ...[
              const SizedBox(height: AppSpace.s12),
              PillBar(value: progress!, color: t.heroBar, track: t.heroTrack),
            ],
            if (deltaText != null) ...[
              const SizedBox(height: AppSpace.s8),
              Text(deltaText!, style: text.bodySmall?.copyWith(color: t.heroSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The 8 dp pill progress bar (visual spec §3, M23): the fill animates to
/// its new value over 400 ms ease-out, instantly under reduced motion.
/// [onReached] fires once the fill lands on 100 % (a goal's pulse hook).
class PillBar extends StatefulWidget {
  const PillBar({required this.value, required this.color, required this.track, this.onReached, super.key});

  /// 0–1+; clamped for drawing.
  final double value;
  final Color color;
  final Color track;
  final VoidCallback? onReached;

  static const height = 8.0;

  @override
  State<PillBar> createState() => _PillBarState();
}

class _PillBarState extends State<PillBar> {
  late double _from = widget.value;

  @override
  void didUpdateWidget(PillBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _from = oldWidget.value;
  }

  void _landed() {
    _from = widget.value;
    if (widget.value >= 1) widget.onReached?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.pillAll,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: _from, end: widget.value),
        duration: context.reducedMotion ? Duration.zero : AppMotion.valueTransition,
        curve: AppMotion.easeOut,
        onEnd: _landed,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v.clamp(0.0, 1.0),
          minHeight: PillBar.height,
          color: widget.color,
          backgroundColor: widget.track,
          borderRadius: AppRadius.pillAll,
        ),
      ),
    );
  }
}
