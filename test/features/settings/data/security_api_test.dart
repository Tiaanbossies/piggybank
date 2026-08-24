import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/settings/data/security_api.dart';

/// Canned-response fake adapter, mirrors `subscription_api_test.dart`.
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
  group('SecurityApi', () {
    test('setPin POSTs /auth/pin with current_password and pin', () async {
      final adapter = _FakeAdapter([() => _empty(204)]);
      final api = SecurityApi(_clientWith(adapter));

      await api.setPin(currentPassword: 'password123', pin: '1234');

      final request = adapter.requestLog.single;
      expect(request.path, '/auth/pin');
      expect(request.method, 'POST');
      expect(request.data, {'current_password': 'password123', 'pin': '1234'});
    });

    test('verifyPin POSTs /auth/pin/verify with pin only', () async {
      final adapter = _FakeAdapter([() => _empty(204)]);
      final api = SecurityApi(_clientWith(adapter));

      await api.verifyPin('1234');

      final request = adapter.requestLog.single;
      expect(request.path, '/auth/pin/verify');
      expect(request.method, 'POST');
      expect(request.data, {'pin': '1234'});
    });

    test('verifyPin throws ApiError with statusCode 401 on a wrong PIN', () async {
      final adapter = _FakeAdapter([() => _empty(401)]);
      final api = SecurityApi(_clientWith(adapter));

      await expectLater(
        api.verifyPin('0000'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('removePin DELETEs /auth/pin with current_password', () async {
      final adapter = _FakeAdapter([() => _empty(204)]);
      final api = SecurityApi(_clientWith(adapter));

      await api.removePin('password123');

      final request = adapter.requestLog.single;
      expect(request.path, '/auth/pin');
      expect(request.method, 'DELETE');
      expect(request.data, {'current_password': 'password123'});
    });
  });
}
