import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'category_tile.dart';

/// Circular tinted icon container — the leading element on rows and
/// quick-link tiles. `primaryContainer` by default, the danger container for
/// over-budget or destructive rows (e.g. "Log out"), `sunk` when muted.
///
/// With [family] it's a category instead: the rounded [CategoryTile] in that
/// family's tint (visual spec §1.3).
class IconChip extends StatelessWidget {
  const IconChip({
    required this.icon,
    this.danger = false,
    this.muted = false,
    this.size = 44,
    this.family,
    super.key,
  });

  final IconData icon;
  final bool danger;
  final bool muted;
  final double size;
  final CategoryFamily? family;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (family != null && !danger) return CategoryTile(icon: icon, family: family!);
    final (fg, bg) = danger
        ? (t.onDangerContainer, t.dangerContainer)
        : muted
            ? (t.muted, t.sunk)
            : (t.onPrimaryContainer, t.primaryContainer);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: size * 0.5),
    );
  }
}
