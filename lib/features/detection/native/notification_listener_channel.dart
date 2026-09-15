import 'package:flutter/services.dart';

/// Dart side of the platform channel hosted by `MainActivity.kt` (plan §3,
/// Phase D). The channel name is a constant shared only by string literal
/// with the Kotlin side — there's no codegen here, this project has no
/// other platform channels yet to build shared tooling around.
class NotificationListenerChannel {
  static const _channel = MethodChannel('za.co.fynboscreative.piggybank/notification_detection');

  /// Whether the user has granted "Notification access" to this app in
  /// system settings. There's no callback for "user just granted it" — the
  /// setup screen re-checks this on resume (see plan §3).
  Future<bool> isEnabled() async {
    final result = await _channel.invokeMethod<bool>('isNotificationListenerEnabled');
    return result ?? false;
  }

  /// Opens the system "Notification access" settings page
  /// (`Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`) — a manual toggle,
  /// not a runtime permission dialog, so this only navigates there.
  Future<void> openSystemSettings() => _channel.invokeMethod<void>('openNotificationListenerSettings');

  /// Pushes the current set of active `app_package_name`s down to the
  /// native listener service's SharedPreferences-backed allowlist. Must be
  /// called after every allowlist CRUD change — the native
  /// `onNotificationPosted` filter (plan §3) only ever sees what was last
  /// synced here, not the backend's live state.
  Future<void> updateAllowlist(List<String> packageNames) =>
      _channel.invokeMethod<void>('updateAllowlist', packageNames);

  /// Non-destructive read of the queued items (oldest first, capped at the
  /// backend's ~25-item ingest batch size). Callers must call
  /// [acknowledgeQueuedItems] only after a *successful* upload — peeking
  /// never removes anything, so a failed upload never loses data.
  Future<List<Map<String, dynamic>>> peekQueuedItems() async {
    final result = await _channel.invokeMethod<List<dynamic>>('peekQueuedItems');
    return (result ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Removes the first [count] items from the front of the native queue —
  /// call only once the backend has confirmed it received them.
  Future<void> acknowledgeQueuedItems(int count) =>
      _channel.invokeMethod<void>('acknowledgeQueuedItems', {'count': count});
}
