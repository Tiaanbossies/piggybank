import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// "This cannot be undone" confirmation, kept for the deletes where Undo
/// isn't enough (UX rework spec §5): a holding, a portfolio, a liability
/// payment, and logging out. Single-row deletes (transaction, budget, goal, recurring
/// cost, dividend, RA/TFSA contribution) use `deferDelete` instead.
///
/// [confirmLabel] names the action on the danger text button ("Log out" for
/// the sign-out confirm; "Delete" otherwise). Radius 24 and the fade + scale
/// in (M17) come from the dialog theme.
Future<bool> confirmDestroy(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message ?? 'This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          key: const Key('confirm-destroy'),
          style: TextButton.styleFrom(foregroundColor: context.tokens.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
