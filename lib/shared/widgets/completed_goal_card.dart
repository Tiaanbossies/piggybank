import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Row card for a goal that has hit `GoalStatus.completed`, shown instead of
/// the usual [ProgressCard] once there's nothing left to track progress
/// toward. Matches [ProgressCard]'s card/padding shell (no shared `RowCard`
/// widget exists to reuse) so it reads as the same list, not a new pattern.
/// Shared between the Goals screen and the Dashboard's progress block so a
/// completed goal renders identically wherever it's shown.
class CompletedGoalCard extends StatelessWidget {
  const CompletedGoalCard({required this.title, required this.footnote, super.key});
  final String title;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/mascot_celebrating.jpg', width: 44, height: 44, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                      Text(
                        'Goal complete!',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(footnote, style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
