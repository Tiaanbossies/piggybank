import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/detection_api.dart';
import '../models/detected_event.dart';
import '../native/notification_listener_channel.dart';

final detectionApiProvider = Provider<DetectionApi>((ref) => DetectionApi(ref.watch(apiClientProvider)));

final notificationListenerChannelProvider =
    Provider<NotificationListenerChannel>((ref) => NotificationListenerChannel());

/// The pending-review screen's data source — pending + skipped_invalid
/// events awaiting the user's Confirm/Discard decision (plan §5 Phase E).
final pendingEventsProvider = FutureProvider.autoDispose<List<DetectedEvent>>((ref) {
  return ref.watch(detectionApiProvider).listPending();
});
