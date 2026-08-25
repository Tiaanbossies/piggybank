import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/features/settings/data/notification_prefs_api.dart';

/// Canned-response fake adapter, mirrors `security_api_test.dart`.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);
  final List<ResponseBody Function()> responses;
  int callCount = 0;
  final requestLog = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requestLog.add(options);
    final index = callCount < responses.length ? callCount : responses.length - 1;
    callCount++;
    return responses[index]();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString('{}', status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

ApiClient _clientWith(_FakeAdapter adapter) {
  final client = ApiClient(
    baseUrl: 'https://api.test',
    getAccessToken: () => 'token',
    refreshAccessToken: () async => false,
    onSessionExpired: () {},
  );
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  group('NotificationPrefsApi', () {
    test('updatePreferences PATCHes /auth/me with the full preference dict', () async {
      final adapter = _FakeAdapter([() => _json({}, 200)]);
      final api = NotificationPrefsApi(_clientWith(adapter));

      await api.updatePreferences({'budget_alerts': true, 'weekly_summary': false});

      final request = adapter.requestLog.single;
      expect(request.path, '/auth/me');
      expect(request.method, 'PATCH');
      expect(request.data, {
        'notification_preferences': {'budget_alerts': true, 'weekly_summary': false},
      });
    });
  });
}
