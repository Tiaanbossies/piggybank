import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';

/// Canned-response fake adapter — one entry per call to the same path,
/// falling back to the last entry once exhausted.
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
/// against, unlike [_FakeAdapter]'s fixed response sequence.
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

ResponseBody _json(int status, Map<String, dynamic> data) {
  return ResponseBody.fromString(jsonEncode(data), status, headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  });
}

void main() {
  group('ApiClient auth interceptor', () {
    test('attaches the current bearer token to every request', () async {
      final adapter = _FakeAdapter([() => _json(200, {'ok': true})]);
      final client = ApiClient(
        baseUrl: 'https://api.test',
        getAccessToken: () => 'token-abc',
        refreshAccessToken: () async => false,
        onSessionExpired: () {},
      );
      client.dio.httpClientAdapter = adapter;

      await client.dio.get('/ping');

      expect(adapter.requestLog.single.headers['Authorization'], 'Bearer token-abc');
    });

    test('a single 401 triggers exactly one refresh and retries the request once, succeeding', () async {
      var refreshCalls = 0;
      var token = 'old-token';
      final adapter = _FakeAdapter([
        () => _json(401, {'detail': 'not authenticated'}),
        () => _json(200, {'ok': true}),
      ]);
      final client = ApiClient(
        baseUrl: 'https://api.test',
        getAccessToken: () => token,
        refreshAccessToken: () async {
          refreshCalls++;
          token = 'new-token';
          return true;
        },
        onSessionExpired: () => fail('should not expire session on a successful refresh'),
      );
      client.dio.httpClientAdapter = adapter;

      final response = await client.dio.get('/accounts');

      expect(response.statusCode, 200);
      expect(refreshCalls, 1);
      expect(adapter.requestLog[1].headers['Authorization'], 'Bearer new-token');
    });

    test('concurrent 401s coalesce into a single refresh call, not one per request', () async {
      var refreshCalls = 0;
      final refreshGate = Completer<void>();
      final adapter = _FakeAdapter([
        () => _json(401, {'detail': 'not authenticated'}),
        () => _json(200, {'ok': true}),
      ]);
      final client = ApiClient(
        baseUrl: 'https://api.test',
        getAccessToken: () => 'token',
        refreshAccessToken: () async {
          refreshCalls++;
          await refreshGate.future;
          return true;
        },
        onSessionExpired: () {},
      );
      client.dio.httpClientAdapter = adapter;

      final futureA = client.dio.get('/accounts');
      final futureB = client.dio.get('/transactions');
      // Give both requests a chance to hit their 401 and enter the
      // refresh-coalescing path before the (shared) refresh resolves.
      await Future.delayed(Duration.zero);
      refreshGate.complete();

      await Future.wait([futureA, futureB]);
      expect(refreshCalls, 1);
    });

    test('unrecoverable refresh failure calls onSessionExpired and the 401 propagates', () async {
      var sessionExpiredCalls = 0;
      final adapter = _FakeAdapter([() => _json(401, {'detail': 'not authenticated'})]);
      final client = ApiClient(
        baseUrl: 'https://api.test',
        getAccessToken: () => 'token',
        refreshAccessToken: () async => false,
        onSessionExpired: () => sessionExpiredCalls++,
      );
      client.dio.httpClientAdapter = adapter;

      await expectLater(client.dio.get('/accounts'), throwsA(isA<DioException>()));
      expect(sessionExpiredCalls, 1);
    });

    test('a consents-required 403 triggers onConsentsRequired once, with no retry', () async {
      var consentsRequiredCalls = 0;
      var refreshCalls = 0;
      final adapter = _FakeAdapter([
        () => _json(403, {
              'detail': {
                'error': 'consent required',
                'missing': [
                  {'document_type': 'privacy_policy', 'document_version': '1.0'},
                ],
              },
            }),
      ]);
      final client = ApiClient(
        baseUrl: 'https://api.test',
        getAccessToken: () => 'token',
        refreshAccessToken: () async {
          refreshCalls++;
          return true;
        },
        onSessionExpired: () {},
        onConsentsRequired: () => consentsRequiredCalls++,
      );
      client.dio.httpClientAdapter = adapter;

      await expectLater(client.dio.get('/accounts'), throwsA(isA<DioException>()));
      expect(consentsRequiredCalls, 1);
      expect(refreshCalls, 0);
      expect(adapter.callCount, 1);
    });
  });

  group('ApiClient connection-level fallback', () {
    test('a connection-level failure retries once against fallbackBaseUrl and succeeds', () async {
      // `RequestOptions` is mutated in place for the retry (the interceptor
      // sets `.baseUrl` on the very same instance `err.requestOptions`
      // pointed at, same as the existing 401-refresh retry above) — so the
      // base URLs actually used must be captured as values at call time,
      // not by keeping references to the `RequestOptions` objects
      // themselves, which would all end up reflecting the final mutation.
      final baseUrlsSeen = <String>[];
      final adapter = _CallbackAdapter((options) async {
        baseUrlsSeen.add(options.baseUrl);
        if (options.baseUrl == 'https://fallback.test') {
          return _json(200, {'ok': true});
        }
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });
      final client = ApiClient(
        baseUrl: 'https://api.test',
        getAccessToken: () => 'token',
        refreshAccessToken: () async => false,
        onSessionExpired: () {},
        fallbackBaseUrl: 'https://fallback.test',
      );
      client.dio.httpClientAdapter = adapter;

      final response = await client.dio.get('/ping');

      expect(response.statusCode, 200);
      expect(baseUrlsSeen, ['https://api.test', 'https://fallback.test']);
    });

    test('retries at most once — a fallback that also fails surfaces as a network error, not a loop', () async {
      var callCount = 0;
      final adapter = _CallbackAdapter((options) async {
        callCount++;
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });
      final client = ApiClient(
        baseUrl: 'https://api.test',
        getAccessToken: () => 'token',
        refreshAccessToken: () async => false,
        onSessionExpired: () {},
        fallbackBaseUrl: 'https://fallback.test',
      );
      client.dio.httpClientAdapter = adapter;

      await expectLater(client.dio.get('/ping'), throwsA(isA<DioException>()));
      expect(callCount, 2);
    });

    test('with no fallbackBaseUrl configured, a connection-level failure is not retried', () async {
      var callCount = 0;
      final adapter = _CallbackAdapter((options) async {
        callCount++;
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });
      final client = ApiClient(
        baseUrl: 'https://api.test',
        getAccessToken: () => 'token',
        refreshAccessToken: () async => false,
        onSessionExpired: () {},
      );
      client.dio.httpClientAdapter = adapter;

      await expectLater(client.dio.get('/ping'), throwsA(isA<DioException>()));
      expect(callCount, 1);
    });

    test('a real HTTP error response is never retried against the fallback', () async {
      var callCount = 0;
      final adapter = _CallbackAdapter((options) async {
        callCount++;
        return _json(500, {'detail': 'boom'});
      });
      final client = ApiClient(
        baseUrl: 'https://api.test',
        getAccessToken: () => 'token',
        refreshAccessToken: () async => false,
        onSessionExpired: () {},
        fallbackBaseUrl: 'https://fallback.test',
      );
      client.dio.httpClientAdapter = adapter;

      await expectLater(client.dio.get('/ping'), throwsA(isA<DioException>()));
      expect(callCount, 1);
    });
  });

  group('ApiClient.errorFrom', () {
    test('translates a DioException with a response into an ApiError', () {
      final options = RequestOptions(path: '/x');
      final error = DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401, data: {'detail': 'invalid credentials'}),
      );
      final apiError = ApiClient.errorFrom(error);
      expect(apiError.statusCode, 401);
      expect(apiError.message, 'invalid credentials');
    });

    test('translates a connection-level DioException (no response) into a network-error ApiError', () {
      final error = DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);
      final apiError = ApiClient.errorFrom(error);
      expect(apiError.statusCode, 0);
      expect(apiError.message, isNotEmpty);
    });
  });
}
