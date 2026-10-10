import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../features/imports/models/import_job.dart';

/// Status pill for an [ImportStatus] — extracted from
/// `imports_screen.dart`'s file-local `_StatusBadge` so Settings' Import
/// History screen (blueprint Step 2) can reuse it, matching the precedent
/// of other cross-feature shared widgets already importing feature models
/// (e.g. `allocation_donut.dart` importing `features/portfolios`).
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});
  final ImportStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Pills in primaryContainer; the danger container only for a failure.
    final (fg, bg) = switch (status) {
      ImportStatus.completed || ImportStatus.partial => (t.onPrimaryContainer, t.primaryContainer),
      ImportStatus.failed => (t.onDangerContainer, t.dangerContainer),
      ImportStatus.pending => (t.muted, t.sunk),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillAll),
      child: Text(status.name.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}
