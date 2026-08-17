import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Small rounded percentage badge — DESIGN.md § Progress card. Accent-tinted
/// normally, danger-tinted when over-budget/at-risk.
class PercentPill extends StatelessWidget {
  const PercentPill({required this.pct, this.danger = false, super.key});

  /// 0-100+ (over-budget rows can exceed 100).
  final int pct;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final fg = danger ? semantic?.danger : Theme.of(context).colorScheme.primary;
    final bg = danger ? semantic?.dangerChipBg : semantic?.accentChipBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('$pct%', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
