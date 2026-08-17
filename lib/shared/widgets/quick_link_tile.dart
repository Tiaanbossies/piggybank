import 'package:flutter/material.dart';

import 'icon_chip.dart';

/// Small icon-chip + label tile for the Dashboard's 4-up quick-link row
/// (Accounts/Assets/Liabilities/Calculators) — DESIGN.md § Signature
/// components. Replaces the superseded spec's inline `ActionChip` row.
class QuickLinkTile extends StatelessWidget {
  const QuickLinkTile({required this.label, required this.icon, required this.onTap, super.key});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconChip(icon: icon),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
