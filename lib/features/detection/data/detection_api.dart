import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/notification_source.dart';

/// `/detection/*` — the notification/email detection feature (Phases A/B on
/// the backend). Only the notification-allowlist CRUD and ingest endpoints
/// are wired here (Phase D scope); Gmail connect/status is Phase E.
class DetectionApi {
  DetectionApi(this._client);
  final ApiClient _client;

  Future<List<NotificationSource>> listNotificationSources({bool includeInactive = false}) async {
    try {
      final response = await _client.dio.get(
        '/detection/sources/notifications',
        queryParameters: {'include_inactive': includeInactive},
      );
      final items = (response.data as Map<String, dynamic>)['items'] as List;
      return items.map((e) => NotificationSource.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<NotificationSource> addNotificationSource({
    required String appPackageName,
    required String appLabel,
  }) async {
    try {
      final response = await _client.dio.post('/detection/sources/notifications', data: {
        'app_package_name': appPackageName,
        'app_label': appLabel,
      });
      return NotificationSource.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Soft-delete, matching the backend's own semantics for this table.
  Future<void> removeNotificationSource(String sourceId) async {
    try {
      await _client.dio.delete('/detection/sources/notifications/$sourceId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Uploads a batch of queued notification captures for extraction. Items
  /// are `{source_ref, raw_text, captured_at}` maps straight from the
  /// native queue (`NotificationListenerChannel.peekQueuedItems`) — same
  /// shape the backend's `IngestNotificationItem` expects, so no reshaping
  /// happens here. Returns the raw `IngestResult` fields; the caller only
  /// needs `processed` to know how many items to acknowledge.
  Future<Map<String, dynamic>> ingestNotifications(List<Map<String, dynamic>> items) async {
    try {
      final response = await _client.dio.post('/detection/ingest/notifications', data: items);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}
