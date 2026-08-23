import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/core/consents/consent_models.dart';
import 'package:piggybank/features/consent/data/consents_api.dart';

/// Canned-response fake adapter, mirrors `test/core/api/api_client_test.dart`.
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
  group('ConsentsApi', () {
    test('listRequired parses the required-documents list', () async {
      final adapter = _FakeAdapter([
        () => _json(200, [
              {'document_type': 'privacy_policy', 'document_version': '1.0'},
              {'document_type': 'terms_of_service', 'document_version': '1.0'},
            ]),
      ]);
      final api = ConsentsApi(_clientWith(adapter));

      final result = await api.listRequired();

      expect(result, hasLength(2));
      expect(result[0].documentType, 'privacy_policy');
      expect(result[0].documentVersion, '1.0');
      expect(result[1].documentType, 'terms_of_service');
      expect(adapter.requestLog.single.path, '/consents/required');
    });

    test('listAccepted parses the user\'s consent records', () async {
      final adapter = _FakeAdapter([
        () => _json(200, [
              {
                'id': 'c1',
                'document_type': 'privacy_policy',
                'document_version': '1.0',
                'accepted_at': '2026-01-01T00:00:00Z',
              },
            ]),
      ]);
      final api = ConsentsApi(_clientWith(adapter));

      final result = await api.listAccepted();

      expect(result, hasLength(1));
      expect(result.single.id, 'c1');
      expect(result.single.documentType, 'privacy_policy');
      expect(result.single.acceptedAt, DateTime.parse('2026-01-01T00:00:00Z'));
      expect(adapter.requestLog.single.path, '/consents/');
    });

    test('accept posts document_type/document_version and returns the created record', () async {
      final adapter = _FakeAdapter([
        () => _json(201, {
              'id': 'c2',
              'document_type': 'terms_of_service',
              'document_version': '1.0',
              'accepted_at': '2026-01-02T00:00:00Z',
            }),
      ]);
      final api = ConsentsApi(_clientWith(adapter));

      final result = await api.accept(documentType: 'terms_of_service', documentVersion: '1.0');

      expect(result.id, 'c2');
      expect(result.documentType, 'terms_of_service');
      final sentBody = adapter.requestLog.single.data as Map<String, dynamic>;
      expect(sentBody['document_type'], 'terms_of_service');
      expect(sentBody['document_version'], '1.0');
    });

    test('a failed request throws ApiError, not a raw DioException', () async {
      final adapter = _FakeAdapter([() => _json(500, {'detail': 'server error'})]);
      final api = ConsentsApi(_clientWith(adapter));

      await expectLater(api.listRequired(), throwsA(isA<ApiError>()));
    });
  });

  group('consent model parsing', () {
    test('RequiredDocument.fromJson', () {
      final doc = RequiredDocument.fromJson({'document_type': 'privacy_policy', 'document_version': '1.0'});
      expect(doc.documentType, 'privacy_policy');
      expect(doc.documentVersion, '1.0');
    });

    test('ConsentRecord.fromJson', () {
      final record = ConsentRecord.fromJson({
        'id': 'c1',
        'document_type': 'privacy_policy',
        'document_version': '1.0',
        'accepted_at': '2026-01-01T00:00:00Z',
      });
      expect(record.id, 'c1');
      expect(record.documentType, 'privacy_policy');
      expect(record.documentVersion, '1.0');
      expect(record.acceptedAt, DateTime.parse('2026-01-01T00:00:00Z'));
    });
  });
}
