import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The 40 dp rounded tile a category's icon sits on (visual spec §1.3): the
/// family's tint behind the family's icon colour. Identity comes from the
/// icon and the row's label as well, never from the colour alone.
class CategoryTile extends StatelessWidget {
  const CategoryTile({required this.icon, required this.family, this.size = 40, super.key});

  final IconData icon;
  final CategoryFamily family;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.categoryTile(family), borderRadius: AppRadius.tileAll),
      child: Icon(icon, color: t.categoryIcon(family), size: size * 0.5),
    );
  }
}
