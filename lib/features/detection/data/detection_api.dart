import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/detected_event.dart';
import '../models/email_source.dart';
import '../models/gmail_connection_status.dart';
import '../models/notification_source.dart';

/// `/detection/*` — the notification/email detection feature. Notification-
/// allowlist CRUD and ingest are Phase D; email-allowlist CRUD, Gmail
/// connect/status/disconnect, and the pending review flow (Phase B/C
/// endpoints, Phase E client) are below.
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

  // ---- email allowlist (Phase E, backend Phase A endpoints) --------------

  Future<List<EmailSource>> listEmailSources({bool includeInactive = false}) async {
    try {
      final response = await _client.dio.get(
        '/detection/sources/email',
        queryParameters: {'include_inactive': includeInactive},
      );
      final items = (response.data as Map<String, dynamic>)['items'] as List;
      return items.map((e) => EmailSource.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<EmailSource> addEmailSource({required String senderEmail, required String label}) async {
    try {
      final response = await _client.dio.post('/detection/sources/email', data: {
        'sender_email': senderEmail,
        'label': label,
      });
      return EmailSource.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Soft-delete, matching the backend's own semantics for this table.
  Future<void> removeEmailSource(String sourceId) async {
    try {
      await _client.dio.delete('/detection/sources/email/$sourceId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  // ---- Gmail connect / status / disconnect (Phase E, backend Phase C) ----

  /// Returns Google's consent-screen URL — the caller opens it with
  /// `url_launcher` in the system browser (plan §5's Phase E); the flow
  /// completes at the backend's `/detection/email/callback`, which this
  /// client never calls directly.
  Future<String> connectGmail() async {
    try {
      final response = await _client.dio.post('/detection/email/connect');
      return (response.data as Map<String, dynamic>)['authorization_url'] as String;
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<GmailConnectionStatus> getGmailStatus() async {
    try {
      final response = await _client.dio.get('/detection/email/status');
      return GmailConnectionStatus.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> disconnectGmail() async {
    try {
      await _client.dio.delete('/detection/email/connection');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  // ---- pending review: list / confirm / discard (Phase E, backend B) -----

  /// Defaults to the backend's own default filter (pending + skipped_invalid)
  /// when [status] is omitted — see `list_pending_events`'s docstring.
  Future<List<DetectedEvent>> listPending({String? status}) async {
    try {
      final response = await _client.dio.get(
        '/detection/pending',
        queryParameters: {if (status case String s) 'status': s},
      );
      final items = (response.data as Map<String, dynamic>)['items'] as List;
      return items.map((e) => DetectedEvent.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Body shape depends on the event's own `event_kind` — see
  /// `ConfirmEventRequest`'s docstring (backend `detection/schemas.py`):
  /// `transaction` needs [category]; `dividend` needs [holdingId];
  /// `trade` needs [holdingId], [quantity], [pricePerUnit], [tradeType].
  Future<DetectedEvent> confirmEvent(
    String eventId, {
    String? accountId,
    String? category,
    String? subcategory,
    String? holdingId,
    String? quantity,
    String? pricePerUnit,
    String? tradeType,
  }) async {
    try {
      final response = await _client.dio.post('/detection/pending/$eventId/confirm', data: {
        if (accountId case String v) 'account_id': v,
        if (category case String v) 'category': v,
        if (subcategory case String v) 'subcategory': v,
        if (holdingId case String v) 'holding_id': v,
        if (quantity case String v) 'quantity': v,
        if (pricePerUnit case String v) 'price_per_unit': v,
        if (tradeType case String v) 'trade_type': v,
      });
      return DetectedEvent.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<DetectedEvent> discardEvent(String eventId) async {
    try {
      final response = await _client.dio.post('/detection/pending/$eventId/discard');
      return DetectedEvent.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}
