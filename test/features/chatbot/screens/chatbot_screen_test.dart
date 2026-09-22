import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/features/chatbot/data/chatbot_api.dart';
import 'package:piggybank/features/chatbot/screens/chatbot_screen.dart';

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

Widget _wrap(ChatbotApi api) => ProviderScope(
      overrides: [chatbotApiProvider.overrideWithValue(api)],
      child: MaterialApp(theme: AppTheme.light(), home: const ChatbotScreen()),
    );

void main() {
  group('ChatbotScreen', () {
    testWidgets('shows the empty-state prompt before any message is sent', (tester) async {
      await tester.pumpWidget(_wrap(_apiWith(_FakeAdapter([]))));
      await tester.pumpAndSettle();

      expect(find.text("Hi, I'm Penny"), findsOneWidget);
    });

    testWidgets('sending a message shows both bubbles and clears the input', (tester) async {
      final adapter = _FakeAdapter([
        () => _json(200, {'reply': 'A TFSA is tax-free.', 'model': 'qwen2.5:3b-instruct-q4_K_M', 'web_search_enabled': false}),
      ]);
      await tester.pumpWidget(_wrap(_apiWith(adapter)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "What's a TFSA?");
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text("What's a TFSA?"), findsOneWidget);
      expect(find.text('A TFSA is tax-free.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    });

    testWidgets('a paywall error shows the upgrade dialog without popping the screen', (tester) async {
      // ChatbotScreen is the '/assistant' bottom-nav tab root (see app_router.dart),
      // not a pushed screen — there is nothing to pop when a paywall error fires, so
      // this pumps it directly rather than via a manual Navigator.push wrapper.
      final adapter = _FakeAdapter([() => _json(402, {'detail': 'Pro subscription required'})]);

      await tester.pumpWidget(_wrap(_apiWith(adapter)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Upgrade to PRO'), findsOneWidget);
      expect(find.text('Pro subscription required'), findsOneWidget);
      expect(find.byType(ChatbotScreen), findsOneWidget);
    });

    testWidgets('stat-card trend icon uses a neutral color regardless of up/down direction', (tester) async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'reply': 'Spending: R 4,230 12% higher than last month',
              'model': 'qwen2.5:3b-instruct-q4_K_M',
              'web_search_enabled': false,
            }),
        () => _json(200, {
              'reply': 'Net worth: R 4,230 12% lower than last month',
              'model': 'qwen2.5:3b-instruct-q4_K_M',
              'web_search_enabled': false,
            }),
      ]);
      final theme = AppTheme.light();
      final textMuted = theme.extension<AppSemanticColors>()!.textMuted;
      final success = theme.extension<AppSemanticColors>()!.success;

      await tester.pumpWidget(_wrap(_apiWith(adapter)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'How is my spending?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final upIcon = tester.widget<Icon>(find.byIcon(Icons.trending_up));
      expect(upIcon.color, textMuted);
      expect(upIcon.color, isNot(success));

      await tester.enterText(find.byType(TextField), 'How is my net worth?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final downIcon = tester.widget<Icon>(find.byIcon(Icons.trending_down));
      expect(downIcon.color, textMuted);
      expect(downIcon.color, isNot(success));
    });
  });
}
