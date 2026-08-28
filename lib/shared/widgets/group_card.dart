import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'icon_chip.dart';

/// One white card holding several rows separated by thin dividers — the
/// mockups' actual grouping pattern for Accounts, Transactions (per date),
/// Settings sections, and Invest holdings: rows within one logical group
/// share a single card, they are not each their own card. Contrast with
/// [ProgressCard] (Budgets/Goals), which genuinely is one card per item.
class GroupCard extends StatelessWidget {
  const GroupCard({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i != 0) const Divider(height: 1, indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A single row inside a [GroupCard] — no card/margin of its own, just an
/// optional leading [IconChip], title/subtitle, and trailing content.
class GroupRow extends StatelessWidget {
  const GroupRow({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingDanger = false,
    this.muted = false,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final bool leadingDanger;
  final bool muted;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              IconChip(icon: leadingIcon!, danger: leadingDanger, muted: muted),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(color: semantic?.textMuted, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}
