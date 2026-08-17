import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Circular colour-tinted icon container — the leading element on every
/// [RowCard] and quick-link tile (DESIGN.md § Iconography / Signature
/// components). Accent-tinted by default, danger-tinted for warning rows
/// (e.g. an over-budget category, "Log out").
class IconChip extends StatelessWidget {
  const IconChip({required this.icon, this.danger = false, this.size = 44, super.key});

  final IconData icon;
  final bool danger;
  final double size;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final fg = danger ? semantic?.danger : Theme.of(context).colorScheme.primary;
    final bg = danger ? semantic?.dangerChipBg : semantic?.accentChipBg;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: size * 0.5),
    );
  }
}
