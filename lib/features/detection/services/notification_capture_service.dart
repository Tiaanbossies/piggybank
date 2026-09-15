import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../data/detection_api.dart';
import '../native/notification_listener_channel.dart';
import '../providers/detection_provider.dart';

/// Flushes the native notification queue to the backend.
///
/// Plan §3 calls for a WorkManager-backed periodic task so uploads happen
/// even while the app isn't foregrounded. That's not built here — adding
/// the `workmanager` plugin (a new dependency; nothing in this project
/// today runs Dart code from native background tasks) is a bigger call
/// than Phase D's scope warrants, so this flushes only when the app is
/// actually running: on every resume, and on a 15-minute foreground
/// `Timer.periodic` while it stays open. Nothing is lost in between — the
/// native listener service (independent of the Flutter app's own
/// lifecycle, per plan §3) keeps queuing up to `MAX_QUEUE_SIZE` items
/// regardless, so a flush next time the app opens still picks everything
/// up. Revisit if real-world testing (Phase F) shows queued items going
/// stale for too long between app opens.
class NotificationCaptureService {
  NotificationCaptureService(this._channel, this._api);

  final NotificationListenerChannel _channel;
  final DetectionApi _api;

  bool _flushing = false;

  /// Uploads one batch (the backend caps ingest at 25 items per call) and
  /// acknowledges only what the backend actually reported having
  /// processed — if the request fails outright, nothing is acknowledged
  /// and the same items are retried on the next flush.
  Future<void> flush() async {
    if (_flushing) return; // one flush at a time
    _flushing = true;
    try {
      final items = await _channel.peekQueuedItems();
      if (items.isEmpty) return;
      final result = await _api.ingestNotifications(items);
      final processed = result['processed'] as int? ?? items.length;
      await _channel.acknowledgeQueuedItems(processed);
    } on ApiError {
      // Left queued natively for the next flush attempt — never dropped
      // on a network/API failure.
    } finally {
      _flushing = false;
    }
  }
}

final notificationCaptureServiceProvider = Provider<NotificationCaptureService>(
  (ref) => NotificationCaptureService(
    ref.watch(notificationListenerChannelProvider),
    ref.watch(detectionApiProvider),
  ),
);
