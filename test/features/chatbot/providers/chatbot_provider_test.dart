import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/chatbot/data/chatbot_api.dart';
import 'package:piggybank/features/chatbot/models/chat_message.dart';
import 'package:piggybank/features/chatbot/providers/chatbot_provider.dart';

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

ChatbotApi _apiWith(_FakeAdapter adapter) {
  final client = ApiClient(
    baseUrl: 'https://api.test',
    getAccessToken: () => 'token',
    refreshAccessToken: () async => false,
    onSessionExpired: () {},
  );
  client.dio.httpClientAdapter = adapter;
  return ChatbotApi(client);
}

void main() {
  group('ChatbotController', () {
    test('sendMessage appends the user message then the assistant reply', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {'reply': 'Sure, happy to help.', 'model': 'qwen2.5:3b-instruct-q4_K_M', 'web_search_enabled': false}),
      ]);
      final container = ProviderContainer(overrides: [chatbotApiProvider.overrideWithValue(_apiWith(adapter))]);
      addTearDown(container.dispose);
      container.listen(chatbotControllerProvider, (_, _) {});

      final controller = container.read(chatbotControllerProvider.notifier);
      await controller.sendMessage('hi there');

      final state = container.read(chatbotControllerProvider);
      expect(state.sending, false);
      expect(state.messages, hasLength(2));
      expect(state.messages[0].role, ChatRole.user);
      expect(state.messages[0].content, 'hi there');
      expect(state.messages[1].role, ChatRole.assistant);
      expect(state.messages[1].content, 'Sure, happy to help.');
    });

    test('a failed send rolls back the optimistic user message and rethrows', () async {
      final adapter = _FakeAdapter([() => _json(402, {'detail': 'Pro subscription required'})]);
      final container = ProviderContainer(overrides: [chatbotApiProvider.overrideWithValue(_apiWith(adapter))]);
      addTearDown(container.dispose);
      container.listen(chatbotControllerProvider, (_, _) {});

      final controller = container.read(chatbotControllerProvider.notifier);

      await expectLater(controller.sendMessage('hi'), throwsA(isA<ApiError>()));

      final state = container.read(chatbotControllerProvider);
      expect(state.sending, false);
      expect(state.messages, isEmpty);
    });

    test('blank input is a no-op', () async {
      final container = ProviderContainer(overrides: [chatbotApiProvider.overrideWithValue(_apiWith(_FakeAdapter([])))]);
      addTearDown(container.dispose);

      await container.read(chatbotControllerProvider.notifier).sendMessage('   ');

      expect(container.read(chatbotControllerProvider).messages, isEmpty);
    });
  });
}
