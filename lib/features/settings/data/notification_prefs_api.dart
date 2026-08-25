import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';

/// `ApiClient`-based, mirrors `SecurityApi`. Wraps Step 4b's
/// `notification_preferences` field on `PATCH /auth/me` — there is no
/// dedicated notifications route; the backend reuses the profile-update
/// endpoint, same as `dashboard_widgets`.
class NotificationPrefsApi {
  NotificationPrefsApi(this._client);
  final ApiClient _client;

  /// Sends the full preference dict — the backend replaces the whole value,
  /// it does not merge, so callers must always send every key they want to
  /// keep (see `NotificationsScreen._toggle`).
  Future<void> updatePreferences(Map<String, bool> preferences) async {
    try {
      await _client.dio.patch('/auth/me', data: {'notification_preferences': preferences});
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final notificationPrefsApiProvider =
    Provider<NotificationPrefsApi>((ref) => NotificationPrefsApi(ref.watch(apiClientProvider)));
