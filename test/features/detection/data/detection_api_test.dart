import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/detection/data/detection_api.dart';

/// Canned-response fake adapter, mirrors
/// `test/features/updates/data/updates_api_test.dart`.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);
  final List<ResponseBody Function()> responses;
  int callCount = 0;
  final requestLog = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
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
  group('DetectionApi Gmail connect/status/disconnect', () {
    test('connectGmail POSTs /detection/email/connect and returns the authorization_url', () async {
      final adapter = _FakeAdapter([() => _json(200, {'authorization_url': 'https://accounts.google.com/o/oauth2/auth?state=abc'})]);
      final api = DetectionApi(_clientWith(adapter));

      final url = await api.connectGmail();

      expect(adapter.requestLog.single.path, '/detection/email/connect');
      expect(url, 'https://accounts.google.com/o/oauth2/auth?state=abc');
    });

    test('getGmailStatus parses a connected status', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'connected': true,
              'scope': 'https://www.googleapis.com/auth/gmail.readonly',
              'last_polled_at': '2026-09-15T10:00:00Z',
            }),
      ]);
      final api = DetectionApi(_clientWith(adapter));

      final status = await api.getGmailStatus();

      expect(status.connected, isTrue);
      expect(status.scope, 'https://www.googleapis.com/auth/gmail.readonly');
      expect(status.lastPolledAt, DateTime.parse('2026-09-15T10:00:00Z'));
    });

    test('getGmailStatus parses a disconnected status with null fields', () async {
      final adapter = _FakeAdapter([() => _json(200, {'connected': false, 'scope': null, 'last_polled_at': null})]);
      final api = DetectionApi(_clientWith(adapter));

      final status = await api.getGmailStatus();

      expect(status.connected, isFalse);
      expect(status.scope, isNull);
      expect(status.lastPolledAt, isNull);
    });

    test('disconnectGmail DELETEs /detection/email/connection', () async {
      final adapter = _FakeAdapter([() => ResponseBody.fromString('', 204)]);
      final api = DetectionApi(_clientWith(adapter));

      await api.disconnectGmail();

      expect(adapter.requestLog.single.path, '/detection/email/connection');
      expect(adapter.requestLog.single.method, 'DELETE');
    });
  });

  group('DetectionApi email allowlist', () {
    test('listEmailSources GETs /detection/sources/email and parses items', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'items': [
                {'id': 'src-1', 'sender_email': 'alerts@easyequities.co.za', 'label': 'EasyEquities', 'is_active': true},
              ],
            }),
      ]);
      final api = DetectionApi(_clientWith(adapter));

      final sources = await api.listEmailSources();

      expect(sources, hasLength(1));
      expect(sources.single.senderEmail, 'alerts@easyequities.co.za');
      expect(sources.single.label, 'EasyEquities');
    });

    test('addEmailSource POSTs sender_email and label', () async {
      final adapter = _FakeAdapter([
        () => _json(201, {'id': 'src-1', 'sender_email': 'x@y.com', 'label': 'X', 'is_active': true}),
      ]);
      final api = DetectionApi(_clientWith(adapter));

      final source = await api.addEmailSource(senderEmail: 'x@y.com', label: 'X');

      expect(adapter.requestLog.single.data, {'sender_email': 'x@y.com', 'label': 'X'});
      expect(source.id, 'src-1');
    });

    test('removeEmailSource DELETEs the source by id', () async {
      final adapter = _FakeAdapter([() => ResponseBody.fromString('', 204)]);
      final api = DetectionApi(_clientWith(adapter));

      await api.removeEmailSource('src-1');

      expect(adapter.requestLog.single.path, '/detection/sources/email/src-1');
    });
  });

  group('DetectionApi pending review', () {
    test('listPending GETs /detection/pending and parses a mix of statuses', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'items': [
                {
                  'id': 'evt-1',
                  'source_type': 'notification',
                  'source_ref': 'za.co.fnb.connect.itest',
                  'raw_text': 'You spent R150.00 at Woolworths',
                  'captured_at': '2026-09-15T10:00:00Z',
                  'status': 'pending',
                  'extracted_json': {
                    'event_kind': 'transaction',
                    'transaction_type': 'expense',
                    'amount': '150.00',
                    'description': 'Woolworths',
                    'date': '2026-09-15',
                    'ticker': null,
                  },
                  'event_kind': 'transaction',
                  'error_reason': null,
                  'created_at': '2026-09-15T10:00:01Z',
                  'updated_at': '2026-09-15T10:00:01Z',
                },
                {
                  'id': 'evt-2',
                  'source_type': 'email',
                  'source_ref': 'alerts@easyequities.co.za',
                  'raw_text': 'garbled unparseable text',
                  'captured_at': '2026-09-15T11:00:00Z',
                  'status': 'skipped_invalid',
                  'extracted_json': null,
                  'event_kind': null,
                  'error_reason': 'model response unparseable',
                  'created_at': '2026-09-15T11:00:01Z',
                  'updated_at': '2026-09-15T11:00:01Z',
                },
              ],
            }),
      ]);
      final api = DetectionApi(_clientWith(adapter));

      final events = await api.listPending();

      expect(events, hasLength(2));
      expect(events[0].status.name, 'pending');
      expect(events[0].extractedJson!['amount'], '150.00');
      expect(events[1].status.name, 'skippedInvalid');
      expect(events[1].errorReason, 'model response unparseable');
    });

    test('confirmEvent only sends the non-null fields provided', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'id': 'evt-1',
              'source_type': 'notification',
              'source_ref': 'za.co.fnb.connect.itest',
              'raw_text': 'raw',
              'captured_at': '2026-09-15T10:00:00Z',
              'status': 'confirmed',
              'extracted_json': null,
              'event_kind': 'transaction',
              'error_reason': null,
              'created_at': '2026-09-15T10:00:01Z',
              'updated_at': '2026-09-15T10:00:01Z',
            }),
      ]);
      final api = DetectionApi(_clientWith(adapter));

      final event = await api.confirmEvent('evt-1', category: 'Groceries');

      expect(adapter.requestLog.single.path, '/detection/pending/evt-1/confirm');
      expect(adapter.requestLog.single.data, {'category': 'Groceries'});
      expect(event.status.name, 'confirmed');
    });

    test('discardEvent POSTs /detection/pending/{id}/discard', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'id': 'evt-2',
              'source_type': 'email',
              'source_ref': 'alerts@easyequities.co.za',
              'raw_text': 'raw',
              'captured_at': '2026-09-15T11:00:00Z',
              'status': 'discarded',
              'extracted_json': null,
              'event_kind': null,
              'error_reason': 'model response unparseable',
              'created_at': '2026-09-15T11:00:01Z',
              'updated_at': '2026-09-15T11:00:01Z',
            }),
      ]);
      final api = DetectionApi(_clientWith(adapter));

      final event = await api.discardEvent('evt-2');

      expect(adapter.requestLog.single.path, '/detection/pending/evt-2/discard');
      expect(event.status.name, 'discarded');
    });

    test('a 409 conflict (already confirmed) surfaces as an ApiError', () async {
      final adapter = _FakeAdapter([() => _json(409, {'detail': 'event is already confirmed, not pending'})]);
      final api = DetectionApi(_clientWith(adapter));

      await expectLater(
        api.discardEvent('evt-1'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });
}
