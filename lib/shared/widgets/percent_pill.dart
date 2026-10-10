import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Small pill percentage badge (visual spec §3): primaryContainer normally,
/// the danger container only when the value is over.
class PercentPill extends StatelessWidget {
  const PercentPill({required this.pct, this.danger = false, super.key});

  /// 0-100+ (over-budget rows can exceed 100).
  final int pct;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (fg, bg) = danger ? (t.onDangerContainer, t.dangerContainer) : (t.onPrimaryContainer, t.primaryContainer);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillAll),
      child: Text(
        '$pct%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          letterSpacing: 0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
