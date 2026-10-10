import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../motion/count_up_text.dart';

/// The light hero panel (visual spec §1.1, §3): one per screen, at the top,
/// for the screen's main figure. Light mode is the pale `hero` green with
/// dark ink; dark mode is the tonal deep green, never the brightest thing on
/// screen. Never repeated as a pattern for lesser numbers.
class HeroMetricCard extends StatelessWidget {
  const HeroMetricCard({required this.label, required this.value, this.amount, this.deltaText, super.key});

  final String label;
  final String value;

  /// [value] as a number. When given, a change counts to the new figure
  /// (spec §3.2) instead of snapping.
  final double? amount;
  final String? deltaText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final valueStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
      color: t.heroInk,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: t.hero,
        borderRadius: AppRadius.cardAll,
        boxShadow: AppShadows.level1(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.heroSecondary)),
          const SizedBox(height: 6),
          if (amount == null)
            Text(value, style: valueStyle)
          else
            CountUpText(text: value, amount: amount!, style: valueStyle),
          if (deltaText != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: t.heroTrack,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                deltaText!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.heroInk, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
