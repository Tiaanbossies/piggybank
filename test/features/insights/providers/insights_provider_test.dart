import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/insights/data/insights_api.dart';
import 'package:piggybank/features/insights/providers/insights_provider.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);
  final List<ResponseBody Function()> responses;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
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

InsightsApi _apiWith(_FakeAdapter adapter) {
  final client = ApiClient(
    baseUrl: 'https://api.test',
    getAccessToken: () => 'token',
    refreshAccessToken: () async => false,
    onSessionExpired: () {},
  );
  client.dio.httpClientAdapter = adapter;
  return InsightsApi(client);
}

void main() {
  group('InsightsAskController', () {
    test('ask sets lastResult and clears asking on success', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'answer': 'Your net worth is up 4% this month.',
              'data_scope': {
                'date_scope': {'days': 30},
                'counts': {'transactions': 10},
                'model': 'qwen2.5:3b-instruct-q4_K_M',
              },
            }),
      ]);
      final container = ProviderContainer(overrides: [insightsApiProvider.overrideWithValue(_apiWith(adapter))]);
      addTearDown(container.dispose);
      container.listen(insightsAskControllerProvider, (_, _) {});

      await container.read(insightsAskControllerProvider.notifier).ask('How is my net worth trending?');

      final state = container.read(insightsAskControllerProvider);
      expect(state.asking, false);
      expect(state.lastResult?.answer, 'Your net worth is up 4% this month.');
      expect(state.lastResult?.counts['transactions'], 10);
    });

    test('a failed ask clears asking and rethrows without setting lastResult', () async {
      final adapter = _FakeAdapter([() => _json(402, {'detail': 'Pro subscription required'})]);
      final container = ProviderContainer(overrides: [insightsApiProvider.overrideWithValue(_apiWith(adapter))]);
      addTearDown(container.dispose);
      container.listen(insightsAskControllerProvider, (_, _) {});

      final controller = container.read(insightsAskControllerProvider.notifier);
      await expectLater(controller.ask('hi'), throwsA(isA<ApiError>()));

      final state = container.read(insightsAskControllerProvider);
      expect(state.asking, false);
      expect(state.lastResult, isNull);
    });

    test('blank input is a no-op', () async {
      final container = ProviderContainer(overrides: [insightsApiProvider.overrideWithValue(_apiWith(_FakeAdapter([])))]);
      addTearDown(container.dispose);

      await container.read(insightsAskControllerProvider.notifier).ask('   ');

      expect(container.read(insightsAskControllerProvider).lastResult, isNull);
    });
  });
}
