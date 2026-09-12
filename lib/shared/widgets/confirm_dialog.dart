import 'package:flutter/material.dart';

/// "This cannot be undone" confirmation, per `ui-ux-mockup-brief.md` §5.3:
/// "Deletes (holding, dividend, portfolio) all go through an explicit
/// confirmation". Also used for RA/TFSA contribution deletes and Liability
/// payment deletes — all ledger entries where deleting recomputes a running
/// balance/total, not just removing a standalone record. Plain records
/// (Assets, Liabilities themselves, Budgets, Goals) still delete directly.
Future<bool> confirmDestroy(BuildContext context, {required String title, String? message}) async {
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
          child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
  );
  return result ?? false;
}
