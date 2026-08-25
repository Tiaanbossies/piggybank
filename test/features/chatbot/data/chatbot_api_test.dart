import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/chatbot/data/chatbot_api.dart';
import 'package:piggybank/features/chatbot/models/chat_message.dart';

/// Canned-response fake adapter, mirrors `test/features/settings/data/subscription_api_test.dart`.
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
  group('ChatbotApi', () {
    test('sendMessage POSTs /chatbot/chat with the full history and parses the reply', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {'reply': 'A TFSA is a Tax-Free Savings Account.', 'model': 'qwen2.5:3b-instruct-q4_K_M', 'web_search_enabled': false}),
      ]);
      final api = ChatbotApi(_clientWith(adapter));

      final history = [
        const ChatMessage(role: ChatRole.user, content: "What's a TFSA?"),
      ];
      final result = await api.sendMessage(history);

      expect(result.reply, 'A TFSA is a Tax-Free Savings Account.');
      expect(result.model, 'qwen2.5:3b-instruct-q4_K_M');
      expect(result.webSearchEnabled, false);
      expect(adapter.requestLog.single.path, '/chatbot/chat');
      expect(adapter.requestLog.single.method, 'POST');
      expect(adapter.requestLog.single.data, {
        'messages': [
          {'role': 'user', 'content': "What's a TFSA?"},
        ],
      });
    });

    test('a 402 response throws an ApiError flagged as a paywall', () async {
      final adapter = _FakeAdapter([() => _json(402, {'detail': 'Pro subscription required'})]);
      final api = ChatbotApi(_clientWith(adapter));

      try {
        await api.sendMessage(const [ChatMessage(role: ChatRole.user, content: 'hi')]);
        fail('expected ApiError');
      } on ApiError catch (e) {
        expect(e.isPaywall, true);
        expect(e.message, 'Pro subscription required');
      }
    });

    test('a 500 response throws a non-paywall ApiError', () async {
      final adapter = _FakeAdapter([() => _json(500, {'detail': 'server error'})]);
      final api = ChatbotApi(_clientWith(adapter));

      await expectLater(
        api.sendMessage(const [ChatMessage(role: ChatRole.user, content: 'hi')]),
        throwsA(isA<ApiError>().having((e) => e.isPaywall, 'isPaywall', false)),
      );
    });
  });
}
