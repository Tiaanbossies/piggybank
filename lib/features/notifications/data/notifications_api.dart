import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';

/// One inbox item (`backend/app/notifications/`). [targetRoute] is
/// `review`, `budget` or `goal`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.targetRoute,
    this.targetId,
    this.readAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String? targetRoute;
  final String? targetId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get unread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        kind: json['kind'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        targetRoute: json['target_route'] as String?,
        targetId: json['target_id'] as String?,
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// The Home bell's inbox (QA pass 1, C12). Reading it brings it up to date
/// server-side: reviews waiting, budgets at 80/100%, goal milestones.
class NotificationsApi {
  NotificationsApi(this._client);
  final ApiClient _client;

  Future<List<AppNotification>> list() async {
    try {
      final response = await _client.dio.get('/notifications/');
      return [
        for (final n in response.data as List<dynamic>) AppNotification.fromJson(n as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<int> unreadCount() async {
    try {
      final response = await _client.dio.get('/notifications/unread-count');
      return (response.data as Map<String, dynamic>)['unread'] as int;
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _client.dio.post('/notifications/$id/read');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _client.dio.post('/notifications/read-all');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final notificationsApiProvider = Provider<NotificationsApi>((ref) => NotificationsApi(ref.watch(apiClientProvider)));

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) {
  return ref.watch(notificationsApiProvider).list();
});

/// The bell's badge.
final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(notificationsApiProvider).unreadCount();
});

/// The notification kinds Settings → Notifications can switch off. The
/// bell shows while at least one is on.
const notificationPreferenceKeys = ['review_reminders', 'budget_alerts', 'goal_milestones'];

final notificationsEnabledProvider = Provider<bool>((ref) {
  try {
    final prefs = ref.watch(authControllerProvider.select((s) => s.user?.notificationPreferences));
    return notificationPreferenceKeys.any((k) => prefs?[k] ?? true);
  } on Object {
    // No auth state to read (a screen pumped on its own): no bell.
    return false;
  }
});
