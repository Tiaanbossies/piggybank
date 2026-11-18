import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/detection/native/notification_listener_channel.dart';
import 'package:piggybank/features/detection/providers/detection_provider.dart';
import 'package:piggybank/features/detection/services/detection_setup_service.dart';
import 'package:piggybank/features/detection/widgets/review_banner.dart';

import '../../../test_helpers/pump_app.dart';

class MockNotificationListenerChannel extends Mock implements NotificationListenerChannel {}

void main() {
  late MockNotificationListenerChannel channel;

  setUp(() {
    channel = MockNotificationListenerChannel();
    when(() => channel.openSystemSettings()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, Future<CaptureProblem> Function() problem) async {
    await pumpApp(
      tester,
      const NotificationAccessBanner(),
      useAppTheme: true,
      overrides: [
        captureProblemProvider.overrideWith((ref) => problem()),
        notificationListenerChannelProvider.overrideWithValue(channel),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('access off: says to try first, then names the restricted-settings fix', (tester) async {
    await pump(tester, () async => CaptureProblem.accessOff);

    expect(find.textContaining('Turn on notification access'), findsOneWidget);
    expect(find.textContaining('Allow restricted settings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification-access-banner')));
    verify(() => channel.openSystemSettings()).called(1);
  });

  testWidgets('granted but not connected: says capture is not running and opens access on tap', (tester) async {
    await pump(tester, () async => CaptureProblem.notConnected);

    expect(find.textContaining("isn't running"), findsOneWidget);
    expect(find.textContaining('Allow restricted settings'), findsNothing);
    await tester.tap(find.byKey(const Key('notification-access-banner')));
    verify(() => channel.openSystemSettings()).called(1);
  });

  testWidgets('hidden when capture is fine', (tester) async {
    await pump(tester, () async => CaptureProblem.none);
    expect(find.byKey(const Key('notification-access-banner')), findsNothing);
  });

  testWidgets('hidden when the check fails', (tester) async {
    await pump(tester, () async => throw Exception('no channel'));
    expect(find.byKey(const Key('notification-access-banner')), findsNothing);
  });

  group('MessagingSendersBanner (F11)', () {
    Future<void> pumpSenders(WidgetTester tester, List<String> apps) async {
      await pumpApp(
        tester,
        const MessagingSendersBanner(),
        useAppTheme: true,
        overrides: [messagingAppsWithoutSendersProvider.overrideWith((ref) async => apps)],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('names the messaging app that reads nothing', (tester) async {
      await pumpSenders(tester, ['Messages']);
      expect(find.textContaining('Messages: no bank senders ticked'), findsOneWidget);
    });

    testWidgets('hidden when every messaging app has a sender', (tester) async {
      await pumpSenders(tester, []);
      expect(find.byKey(const Key('messaging-senders-banner')), findsNothing);
    });
  });
}
