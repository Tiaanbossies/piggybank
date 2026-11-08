import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/settings/data/subscription_api.dart';
import 'package:piggybank/features/settings/models/subscription.dart';

/// Canned-response fake adapter, mirrors `test/features/consent/data/consents_api_test.dart`.
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

ResponseBody _json(int status, dynamic data) {
  return ResponseBody.fromString(jsonEncode(data), status, headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  });
}

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
  group('SubscriptionApi', () {
    test('fetch GETs /subscription and parses the response', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {'tier': 'free', 'status': 'active', 'current_period_end': null}),
      ]);
      final api = SubscriptionApi(_clientWith(adapter));

      final result = await api.fetch();

      expect(result.tier, SubscriptionTier.free);
      expect(adapter.requestLog.single.path, '/subscription');
      expect(adapter.requestLog.single.method, 'GET');
    });

    test('fetch parses the promo source', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'tier': 'pro',
              'status': 'active',
              'current_period_end': '2027-02-28T10:00:00Z',
              'source': 'promo',
            }),
      ]);
      final result = await SubscriptionApi(_clientWith(adapter)).fetch();

      expect(result.source, 'promo');
      expect(result.currentPeriodEnd, DateTime.parse('2027-02-28T10:00:00Z'));
    });

    test('a failed request throws ApiError, not a raw DioException', () async {
      final adapter = _FakeAdapter([() => _json(500, {'detail': 'server error'})]);
      final api = SubscriptionApi(_clientWith(adapter));

      await expectLater(api.fetch(), throwsA(isA<ApiError>()));
    });
  });
}
