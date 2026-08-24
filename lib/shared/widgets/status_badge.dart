import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final Color fg;
    final Color? bg;
    switch (status) {
      case ImportStatus.completed:
        fg = semantic?.success ?? Colors.green;
        bg = semantic?.accentChipBg;
      case ImportStatus.partial:
        fg = Theme.of(context).colorScheme.primary;
        bg = semantic?.accentChipBg;
      case ImportStatus.failed:
        fg = semantic?.danger ?? Colors.red;
        bg = semantic?.dangerChipBg;
      case ImportStatus.pending:
        fg = semantic?.textMuted ?? Colors.grey;
        bg = null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
