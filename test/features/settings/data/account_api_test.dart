import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/settings/data/account_api.dart';

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

ResponseBody _empty(int status) => ResponseBody.fromString('', status);

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

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
  group('AccountApi', () {
    test('exportData GETs /auth/me/export and returns the decoded body', () async {
      final adapter = _FakeAdapter([
        () => _json({
              'exported_at': '2026-08-30T00:00:00+00:00',
              'profile': {'email': 'export@example.com'},
              'assets': [],
            }, 200),
      ]);
      final api = AccountApi(_clientWith(adapter));

      final body = await api.exportData();

      final request = adapter.requestLog.single;
      expect(request.path, '/auth/me/export');
      expect(request.method, 'GET');
      expect(body['profile'], {'email': 'export@example.com'});
    });

    test('deleteAccount DELETEs /auth/me with current_password', () async {
      final adapter = _FakeAdapter([() => _empty(204)]);
      final api = AccountApi(_clientWith(adapter));

      await api.deleteAccount('password123');

      final request = adapter.requestLog.single;
      expect(request.path, '/auth/me');
      expect(request.method, 'DELETE');
      expect(request.data, {'current_password': 'password123'});
    });

    test('deleteAccount throws ApiError with statusCode 401 on a wrong password', () async {
      final adapter = _FakeAdapter([() => _empty(401)]);
      final api = AccountApi(_clientWith(adapter));

      await expectLater(
        api.deleteAccount('wrongpassword'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });
}
