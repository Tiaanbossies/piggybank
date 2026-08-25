import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/insights/data/insights_api.dart';

/// Canned-response fake adapter, mirrors `test/features/chatbot/data/chatbot_api_test.dart`.
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
  group('InsightsApi', () {
    test('ask POSTs /insights and parses the answer plus data scope', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'answer': 'You spent R2,400 on groceries last month.',
              'data_scope': {
                'date_scope': {'start_date': '2026-07-25', 'end_date': '2026-08-25', 'days': 30},
                'counts': {'transactions': 42, 'budgets': 3, 'assets': 1, 'liabilities': 0, 'holdings': 2},
                'model': 'qwen2.5:3b-instruct-q4_K_M',
              },
            }),
      ]);
      final api = InsightsApi(_clientWith(adapter));

      final result = await api.ask('How much did I spend on groceries?');

      expect(result.answer, 'You spent R2,400 on groceries last month.');
      expect(result.model, 'qwen2.5:3b-instruct-q4_K_M');
      expect(result.dateScopeDays, 30);
      expect(result.counts['transactions'], 42);
      expect(adapter.requestLog.single.path, '/insights');
      expect(adapter.requestLog.single.method, 'POST');
      expect(adapter.requestLog.single.data, {'question': 'How much did I spend on groceries?'});
    });

    test('list GETs /insights/ and parses history entries', () async {
      final adapter = _FakeAdapter([
        () => _json(200, [
              {
                'id': 'i1',
                'generated_at': '2026-08-25T10:00:00Z',
                'summary_text': 'You spent R2,400 on groceries last month.',
                'model': 'qwen2.5:3b-instruct-q4_K_M',
                'prompt_tokens': 120,
                'completion_tokens': 40,
                'created_at': '2026-08-25T10:00:00Z',
              },
            ]),
      ]);
      final api = InsightsApi(_clientWith(adapter));

      final result = await api.list();

      expect(result, hasLength(1));
      expect(result.single.summaryText, 'You spent R2,400 on groceries last month.');
      expect(adapter.requestLog.single.path, '/insights/');
      expect(adapter.requestLog.single.method, 'GET');
    });

    test('a 402 response throws an ApiError flagged as a paywall', () async {
      final adapter = _FakeAdapter([() => _json(402, {'detail': 'Pro subscription required'})]);
      final api = InsightsApi(_clientWith(adapter));

      try {
        await api.ask('hi');
        fail('expected ApiError');
      } on ApiError catch (e) {
        expect(e.isPaywall, true);
      }
    });

    test('a 429 rate-limit response throws a non-paywall ApiError with the wait message', () async {
      final adapter = _FakeAdapter([() => _json(429, {'detail': 'Rate limit: wait 60s between insight requests.'})]);
      final api = InsightsApi(_clientWith(adapter));

      await expectLater(
        api.ask('hi'),
        throwsA(isA<ApiError>()
            .having((e) => e.isPaywall, 'isPaywall', false)
            .having((e) => e.message, 'message', 'Rate limit: wait 60s between insight requests.')),
      );
    });
  });
}
