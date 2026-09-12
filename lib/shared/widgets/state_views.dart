import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'icon_chip.dart';

/// Shared "nothing to show yet" treatment — an accent [IconChip], a title,
/// and an optional hint line. Standardizes what used to be several
/// different ad-hoc empty-state treatments across the app (bare text on
/// Goals and the Dashboard's recent-transactions preview; a plain grey
/// icon + text on Budgets; the richest of the bunch on the Chatbot, whose
/// pattern this widget generalizes).
class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.title, this.hint, this.topPadding = 48, super.key});

  final IconData icon;
  final String title;
  final String? hint;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconChip(icon: icon, size: 56),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared "something went wrong" inline treatment — a small danger icon
/// plus muted-danger text, distinct from both an empty state and a silent
/// blank gap. Several async sections previously rendered `SizedBox.shrink()`
/// on error (e.g. the Dashboard's cashflow strip and budget-progress
/// block), giving no feedback at all when a fetch failed.
class InlineError extends StatelessWidget {
  const InlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 18, color: semantic?.danger),
          const SizedBox(width: 8),
          Flexible(child: Text(message, style: TextStyle(color: semantic?.danger))),
        ],
      ),
    );
  }
}
