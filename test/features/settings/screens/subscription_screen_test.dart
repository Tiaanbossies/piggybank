import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/features/settings/data/subscription_api.dart';
import 'package:piggybank/features/settings/models/subscription.dart';
import 'package:piggybank/features/settings/screens/subscription_screen.dart';

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

SubscriptionApi _apiWith(_FakeAdapter adapter) {
  final client = ApiClient(
    baseUrl: 'https://api.test',
    getAccessToken: () => 'token',
    refreshAccessToken: () async => false,
    onSessionExpired: () {},
  );
  client.dio.httpClientAdapter = adapter;
  return SubscriptionApi(client);
}

void main() {
  group('SubscriptionScreen', () {
    Future<void> pumpWith(WidgetTester tester, Map<String, dynamic> body) async {
      final adapter = _FakeAdapter([() => _json(200, body)]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [subscriptionApiProvider.overrideWithValue(_apiWith(adapter))],
          child: const MaterialApp(home: SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('promo Pro says it is free during the beta, until the end date', (tester) async {
      await pumpWith(tester, {
        'tier': 'pro',
        'status': 'active',
        'current_period_end': '2027-02-28T10:00:00Z',
        'source': 'promo',
      });

      expect(find.text('Free during the beta, until 28 Feb 2027'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('Free says paid Pro is coming soon', (tester) async {
      await pumpWith(tester, {'tier': 'free', 'status': 'active', 'current_period_end': null});

      expect(find.text('Paid Pro is coming soon'), findsOneWidget);
    });

    testWidgets('there is nothing to buy or cancel in the app', (tester) async {
      await pumpWith(tester, {'tier': 'free', 'status': 'active', 'current_period_end': null});

      expect(find.text('Upgrade to Pro'), findsNothing);
      expect(find.text('Cancel subscription'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    test('planLine covers promo without an end, and non-promo Pro', () {
      expect(
        SubscriptionScreen.planLine(
          const Subscription(tier: SubscriptionTier.pro, status: SubscriptionStatus.active, currentPeriodEnd: null),
        ),
        'Free during the beta',
      );
      expect(
        SubscriptionScreen.planLine(
          Subscription(
            tier: SubscriptionTier.pro,
            status: SubscriptionStatus.active,
            currentPeriodEnd: DateTime.parse('2027-06-01T10:00:00Z'),
            source: 'play',
          ),
        ),
        'Active until 1 Jun 2027',
      );
    });

    testWidgets('shows an error message when the fetch fails', (tester) async {
      final adapter = _FakeAdapter([() => _json(500, {'detail': 'server error'})]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [subscriptionApiProvider.overrideWithValue(_apiWith(adapter))],
          child: const MaterialApp(home: SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('server error'), findsOneWidget);
    });
  });
}
