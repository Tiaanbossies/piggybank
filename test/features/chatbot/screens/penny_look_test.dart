import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/app_tokens.dart';
import 'package:piggybank/features/chatbot/data/chatbot_api.dart';
import 'package:piggybank/features/chatbot/providers/suggested_questions_provider.dart';
import 'package:piggybank/features/chatbot/screens/chatbot_screen.dart';
import 'package:piggybank/shared/widgets/bubble_border.dart';
import 'package:piggybank/shared/widgets/mascot_moment.dart';

/// Answers once [released], so a test can hold Penny mid-thought. It polls
/// on the test clock, so pumping time is what lets the reply through.
class _HeldAdapter implements HttpClientAdapter {
  bool released = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    while (!released) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return ResponseBody.fromString(
      jsonEncode({'reply': 'Here you go.', 'model': 'm', 'web_search_enabled': false}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ChatbotApi _api(HttpClientAdapter adapter) {
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
  late _HeldAdapter adapter;
  late List<Object?> haptics;

  setUp(() => adapter = _HeldAdapter());

  Future<void> pumpPenny(WidgetTester tester, {bool reduced = false}) async {
    haptics = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatbotApiProvider.overrideWithValue(_api(adapter)),
          suggestedQuestionsProvider.overrideWith((ref) => genericPennyQuestions),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: const ChatbotScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    adapter.released = true;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('the header carries welcoming Penny at 40 dp, as a cutout', (tester) async {
    await pumpPenny(tester);
    final header = find.descendant(of: find.byType(AppBar), matching: find.byType(PennyImage));
    expect(tester.widget<PennyImage>(header).asset, MascotMoment.welcoming);
    expect(tester.getSize(header), const Size(40, 40));
    expect(find.descendant(of: find.byType(AppBar), matching: find.byType(ClipOval)), findsNothing);
  });

  testWidgets('sending fires one light haptic and the bubble rises 8 dp as it fades in', (tester) async {
    await pumpPenny(tester);
    await send(tester, 'How am I doing?');
    await tester.pump(const Duration(milliseconds: 50));

    expect(haptics, ['HapticFeedbackType.lightImpact']);
    final rising = find.ancestor(of: find.text('How am I doing?'), matching: find.byType(Transform)).first;
    final dy = tester.widget<Transform>(rising).transform.getTranslation().y;
    expect(dy, inExclusiveRange(0, 8));

    await finish(tester);
    expect(haptics, hasLength(1));
  });

  testWidgets('user bubbles are primary, replies surface, both speech-bubble shaped', (tester) async {
    await pumpPenny(tester);
    await send(tester, 'Hello');
    await finish(tester);

    ShapeDecoration shapeOf(String text) => tester
        .widget<Container>(find.ancestor(of: find.text(text), matching: find.byType(Container)).first)
        .decoration! as ShapeDecoration;
    final user = shapeOf('Hello');
    final reply = shapeOf('Here you go.');
    expect(user.color, AppTokens.light.primary);
    expect((user.shape as BubbleBorder).tail, BubbleTail.bottomEnd);
    expect(reply.color, AppTokens.light.surface);
    expect((reply.shape as BubbleBorder).tail, BubbleTail.bottomStart);
  });

  testWidgets('thinking Penny bobs in the reply slot; after 10 s "Still working on it…" appears', (tester) async {
    await pumpPenny(tester);
    await send(tester, 'Big question');
    await tester.pump(const Duration(milliseconds: 300));

    final thinking = find.byKey(const Key('penny-thinking'));
    expect(tester.widget<MascotMoment>(thinking).asset, MascotMoment.thinking);
    expect(tester.getSize(thinking), const Size(40, 40));
    expect(find.descendant(of: thinking, matching: find.byType(Transform)), findsOneWidget);
    expect(find.text('Still working on it…'), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Still working on it…'), findsOneWidget);

    await finish(tester);
    expect(thinking, findsNothing);
    expect(find.text('Still working on it…'), findsNothing);
  });

  testWidgets('reduced motion: thinking Penny is static', (tester) async {
    await pumpPenny(tester, reduced: true);
    await send(tester, 'Big question');
    await tester.pump();
    final thinking = find.byKey(const Key('penny-thinking'));
    expect(thinking, findsOneWidget);
    expect(find.descendant(of: thinking, matching: find.byType(Transform)), findsNothing);
    await finish(tester);
  });

  testWidgets('a suggested question is an outlined pill: a selection tick, then it sends', (tester) async {
    await pumpPenny(tester);
    final chip = find.byKey(ValueKey('suggestion-${genericPennyQuestions.first}'));
    expect(tester.widget<OutlinedButton>(chip), isA<OutlinedButton>());

    await tester.tap(chip);
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.selectionClick', 'HapticFeedbackType.lightImpact']);
    // The chips step aside for the thread, which carries the question.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('chat-welcome')), findsNothing);
    expect(find.text(genericPennyQuestions.first), findsOneWidget);
    await finish(tester);
  });
}
