import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/updates/data/updates_api.dart';

/// Canned-response fake adapter, mirrors
/// `test/features/summaries/data/summaries_api_test.dart`.
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
  group('UpdatesApi.latest', () {
    test('GETs /updates/latest and parses the release, including downloadUrl', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'version': '1.4.0',
              'buildNumber': '42',
              'filename': 'piggybank-1.4.0.apk',
              'publishedAt': '2026-09-13T12:00:00Z',
              'downloadUrl': 'http://tiaanbossies-h81m-ds2.tail886b94.ts.net/downloads/piggybank-1.4.0.apk',
            }),
      ]);
      final api = UpdatesApi(_clientWith(adapter));

      final release = await api.latest();

      expect(adapter.requestLog.single.path, '/updates/latest');
      expect(release, isNotNull);
      expect(release!.version, '1.4.0');
      expect(release.buildNumber, '42');
      expect(release.filename, 'piggybank-1.4.0.apk');
      expect(release.publishedAt, '2026-09-13T12:00:00Z');
      expect(release.downloadUrl, 'http://tiaanbossies-h81m-ds2.tail886b94.ts.net/downloads/piggybank-1.4.0.apk');
    });

    test('returns null on a 404 (no release published yet) rather than throwing', () async {
      final adapter = _FakeAdapter([() => _json(404, {'detail': 'no release has been published yet'})]);
      final api = UpdatesApi(_clientWith(adapter));

      final release = await api.latest();

      expect(release, isNull);
    });

    test('converts any other DioException into an ApiError', () async {
      final adapter = _FakeAdapter([() => _json(500, {'detail': 'boom'})]);
      final api = UpdatesApi(_clientWith(adapter));

      await expectLater(api.latest(), throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 500)));
    });
  });
}
