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

  /// Pushes the per-app sender allowlist down to the native service, in
  /// the same shape it stores: package name -> the senders allowed for it.
  ///
  /// An app with an empty list is treated natively as "no sender allowlist
  /// configured", not "allow nothing" — clearing the list turns the sender
  /// check off for that app rather than silencing it entirely.
  Future<void> updateSenderAllowlist(Map<String, List<String>> byPackage) =>
      _channel.invokeMethod<void>('updateSenderAllowlist', byPackage);

  /// The per-app sender allowlist as the native side currently holds it.
  /// Device-local, unlike the package allowlist, which the backend owns —
  /// so this is the only copy, and nothing re-seeds it after a reinstall.
  Future<Map<String, List<String>>> senderAllowlist() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('senderAllowlist');
    return (result ?? {}).map(
      (key, value) => MapEntry(key as String, List<String>.from(value as List)),
    );
  }

  /// The senders actually seen on this phone, per app. The settings screen
  /// offers these instead of asking the user to recall a bank's SMS
  /// short-name from memory.
  Future<Map<String, List<String>>> seenSenders() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('seenSenders');
    return (result ?? {}).map(
      (key, value) => MapEntry(key as String, List<String>.from(value as List)),
    );
  }

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
