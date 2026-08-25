import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/features/insights/data/insights_api.dart';
import 'package:piggybank/features/insights/screens/insights_screen.dart';

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

Widget _wrap(InsightsApi api) => ProviderScope(
      overrides: [insightsApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: InsightsScreen()),
    );

void main() {
  group('InsightsScreen', () {
    testWidgets('shows the empty-history message when no insights exist yet', (tester) async {
      await tester.pumpWidget(_wrap(_apiWith(_FakeAdapter([() => _json(200, [])]))));
      await tester.pumpAndSettle();

      expect(find.text('No insights yet — ask a question above to get started.'), findsOneWidget);
    });

    testWidgets('asking a question shows the answer card with its stat strip', (tester) async {
      final adapter = _FakeAdapter([
        () => _json(200, []), // initial history
        () => _json(200, {
              'answer': 'You spent R2,400 on groceries last month.',
              'data_scope': {
                'date_scope': {'days': 30},
                'counts': {'transactions': 42},
                'model': 'qwen2.5:3b-instruct-q4_K_M',
              },
            }), // ask
        () => _json(200, [
              {
                'id': 'i1',
                'generated_at': '2026-08-25T10:00:00Z',
                'summary_text': 'You spent R2,400 on groceries last month.',
                'model': 'qwen2.5:3b-instruct-q4_K_M',
                'prompt_tokens': 100,
                'completion_tokens': 30,
                'created_at': '2026-08-25T10:00:00Z',
              },
            ]), // history refresh after ask
      ]);
      await tester.pumpWidget(_wrap(_apiWith(adapter)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'How much did I spend on groceries?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('You spent R2,400 on groceries last month.'), findsWidgets);
      expect(find.textContaining('Last 30 days'), findsOneWidget);
      expect(find.textContaining('42 transactions'), findsOneWidget);
    });

    testWidgets('a paywall error pops the screen and shows the upgrade dialog', (tester) async {
      final adapter = _FakeAdapter([
        () => _json(200, []), // initial history
        () => _json(402, {'detail': 'Pro subscription required'}), // ask
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _wrap(_apiWith(adapter))),
                  ),
                  child: const Text('Open insights'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open insights'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Upgrade to PRO'), findsOneWidget);
      expect(find.text('Pro subscription required'), findsOneWidget);
      expect(find.byType(InsightsScreen), findsNothing);
    });
  });
}
