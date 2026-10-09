import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';

/// Ids hidden from their list while an Undo window is open or the delete is
/// in flight (UX rework spec §5, approval A4). UI-only state: lists filter
/// it out of what their providers return.
///
/// A committed id is never removed: the refetch that follows no longer
/// contains it, and un-hiding it early would flash the row back while that
/// refetch is still loading.
final pendingDeletesProvider = StateProvider<Set<String>>((ref) => const {});

/// Undo instead of a confirm dialog, for a single-row delete. Copies the
/// review queue's deferred commit: the row hides now, an Undo snackbar shows
/// for 4 s, and [commit] runs only once it closes without Undo. On failure
/// the row comes back and the error shows in a snackbar.
///
/// Everything it needs is captured before the first await, so the caller can
/// pop its sheet straight after calling this. Killing the app inside the
/// window means nothing is deleted.
Future<void> deferDelete(
  BuildContext context, {
  required String id,
  required String message,
  required Future<void> Function(ProviderContainer container) commit,
}) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final pending = container.read(pendingDeletesProvider.notifier);

  void restore() => pending.state = {...pending.state}..remove(id);

  pending.state = {...pending.state, id};
  // Closing the previous snackbar commits its delete now rather than
  // queueing this one behind it.
  messenger.hideCurrentSnackBar();
  final reason = await messenger
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          // An action snackbar persists by default (Flutter 3.29+), which would
          // hold the delete back until the next action.
          persist: false,
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ),
      )
      .closed;

  if (reason == SnackBarClosedReason.action) {
    restore();
    return;
  }
  try {
    await commit(container);
  } catch (e) {
    restore();
    messenger.showSnackBar(
      SnackBar(content: Text(e is ApiError ? e.message : "Couldn't delete it. It's back in the list.")),
    );
  }
}
