import 'package:flutter/material.dart';

/// "This cannot be undone" confirmation, per `ui-ux-mockup-brief.md` §5.3:
/// "Deletes (holding, dividend, portfolio) all go through an explicit
/// confirmation" — the only place in the app that currently requires one
/// (Assets/Liabilities/Goals delete directly), so this stays scoped to the
/// Investments feature rather than becoming an app-wide convention.
Future<bool> confirmDestroy(BuildContext context, {required String title, String? message}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message ?? 'This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
  );
  return result ?? false;
}
