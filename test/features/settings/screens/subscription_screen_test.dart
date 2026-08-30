import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/features/settings/data/subscription_api.dart';
import 'package:piggybank/features/settings/screens/subscription_screen.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Fakes the platform channel `url_launcher` normally uses, so
/// `launchUrl(...)` in `_upgrade()` succeeds in a widget test without a real
/// browser/OS involved — mirrors the pattern url_launcher's own docs
/// recommend for testing callers.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final launched = <String>[];

  @override
  // ignore: override_on_non_overriding_member
  get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

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
    testWidgets('shows the Free tier and an Upgrade to Pro button', (tester) async {
      final adapter = _FakeAdapter([
        () => _json(200, {'tier': 'free', 'status': 'active', 'current_period_end': null}),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [subscriptionApiProvider.overrideWithValue(_apiWith(adapter))],
          child: const MaterialApp(home: SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Free', findRichText: true), findsWidgets);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('Cancel subscription'), findsNothing);
    });

    testWidgets('shows Pro tier and a Cancel subscription button, no Upgrade button', (tester) async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'tier': 'pro',
              'status': 'active',
              'current_period_end': '2026-09-22T00:00:00Z',
            }),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [subscriptionApiProvider.overrideWithValue(_apiWith(adapter))],
          child: const MaterialApp(home: SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancel subscription'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsNothing);
    });

    testWidgets(
      'tapping Upgrade to Pro starts a checkout, opens it, and shows the waiting state',
      (tester) async {
        final fakeLauncher = _FakeUrlLauncher();
        UrlLauncherPlatform.instance = fakeLauncher;

        final adapter = _FakeAdapter([
          () => _json(200, {'tier': 'free', 'status': 'active', 'current_period_end': null}),
          () => _json(200, {
                'm_payment_id': 'abc-123',
                'checkout_page_url': '/subscription/checkout/abc-123',
              }),
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [subscriptionApiProvider.overrideWithValue(_apiWith(adapter))],
            child: const MaterialApp(home: SubscriptionScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Upgrade to Pro'));
        await tester.pumpAndSettle();

        // Real gateway now sits in front of granting Pro — tapping Upgrade
        // must NOT itself flip the tier; it opens PayFast's checkout and
        // waits for the (out-of-band) ITN webhook to confirm.
        expect(fakeLauncher.launched, hasLength(1));
        expect(fakeLauncher.launched.single, contains('/subscription/checkout/abc-123'));
        expect(find.text('Refresh status'), findsOneWidget);
        expect(find.text('Cancel subscription'), findsNothing);
      },
    );

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
