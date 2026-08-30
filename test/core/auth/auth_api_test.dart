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

ResponseBody _empty(int status) => ResponseBody.fromString('', status);

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
}
