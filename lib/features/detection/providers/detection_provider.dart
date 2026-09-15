import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/detection_api.dart';
import '../native/notification_listener_channel.dart';

final detectionApiProvider = Provider<DetectionApi>((ref) => DetectionApi(ref.watch(apiClientProvider)));

final notificationListenerChannelProvider =
    Provider<NotificationListenerChannel>((ref) => NotificationListenerChannel());
