import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/core/auth/auth_api.dart';

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

/// Adapter driven by a per-request callback — used where the response (or
/// failure) needs to depend on which `baseUrl` the request was made
/// against, mirrors `test/core/api/api_client_test.dart`'s identical helper.
class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this._handler);
  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _empty(int status) => ResponseBody.fromString('', status);

ResponseBody _json(int status, Map<String, dynamic> data) {
  return ResponseBody.fromString(
    '{"access_token": "${data['access_token']}", "refresh_token": "${data['refresh_token']}"}',
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

AuthApi _apiWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return AuthApi(dio: dio);
}

void main() {
  group('AuthApi password reset', () {
    test('requestPasswordReset POSTs /auth/password-reset/request with email', () async {
      final adapter = _FakeAdapter([() => _empty(204)]);
      final api = _apiWith(adapter);

      await api.requestPasswordReset('user@example.com');

      final request = adapter.requestLog.single;
      expect(request.path, '/auth/password-reset/request');
      expect(request.method, 'POST');
      expect(request.data, {'email': 'user@example.com'});
    });

    test('confirmPasswordReset POSTs /auth/password-reset/confirm with email, code, new_password', () async {
      final adapter = _FakeAdapter([() => _empty(204)]);
      final api = _apiWith(adapter);

      await api.confirmPasswordReset(
        email: 'user@example.com',
        code: '12345678',
        newPassword: 'brandnewpassword1',
      );

      final request = adapter.requestLog.single;
      expect(request.path, '/auth/password-reset/confirm');
      expect(request.method, 'POST');
      expect(request.data, {
        'email': 'user@example.com',
        'code': '12345678',
        'new_password': 'brandnewpassword1',
      });
    });

    test('confirmPasswordReset throws ApiError with statusCode 400 on an invalid code', () async {
      final adapter = _FakeAdapter([() => _empty(400)]);
      final api = _apiWith(adapter);

      await expectLater(
        api.confirmPasswordReset(email: 'user@example.com', code: '00000000', newPassword: 'x1234567'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('AuthApi connection-level fallback', () {
    // Regression coverage for a real bug caught live on an emulator: login
    // goes through this raw-Dio class, not ApiClient, so ApiClient's own
    // fallback (tested in api_client_test.dart) doesn't cover it on its
    // own — this class needs (and, per auth_api.dart, now has) its own copy
    // of the identical retry.
    test('login retries once against fallbackBaseUrl on a connection-level failure, then succeeds', () async {
      final baseUrlsSeen = <String>[];
      final adapter = _CallbackAdapter((options) async {
        baseUrlsSeen.add(options.baseUrl);
        if (options.baseUrl == 'https://fallback.test') {
          return _json(200, {'access_token': 'a-token', 'refresh_token': 'r-token'});
        }
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
      final api = AuthApi(dio: dio, fallbackBaseUrl: 'https://fallback.test');

      final result = await api.login(email: 'user@example.com', password: 'x1234567');

      expect(result.accessToken, 'a-token');
      expect(baseUrlsSeen, ['https://api.test', 'https://fallback.test']);
    });

    test('with no fallbackBaseUrl configured, a connection-level failure is not retried', () async {
      var callCount = 0;
      final adapter = _CallbackAdapter((options) async {
        callCount++;
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
      final api = AuthApi(dio: dio);

      await expectLater(
        api.login(email: 'user@example.com', password: 'x1234567'),
        throwsA(isA<ApiError>()),
      );
      expect(callCount, 1);
    });
  });
}
