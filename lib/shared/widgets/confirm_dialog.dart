import 'package:flutter/material.dart';

/// "This cannot be undone" confirmation, kept for the deletes where Undo
/// isn't enough (UX rework spec §5): a holding, a portfolio, a liability
/// payment, and logging out. Single-row deletes (transaction, budget, goal, recurring
/// cost, dividend, RA/TFSA contribution) use `deferDelete` instead.
///
/// [confirmLabel] names the action on the red button ("Log out" for the
/// sign-out confirm; "Delete" otherwise).
Future<bool> confirmDestroy(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message ?? 'This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
  );
  return result ?? false;
}
