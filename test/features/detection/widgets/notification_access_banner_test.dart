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

  Future<void> pump(WidgetTester tester, Future<bool> Function() missing) async {
    await pumpApp(
      tester,
      const NotificationAccessBanner(),
      useAppTheme: true,
      overrides: [
        notificationAccessMissingProvider.overrideWith((ref) => missing()),
        notificationListenerChannelProvider.overrideWithValue(channel),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names the restricted-settings fix and opens notification access on tap', (tester) async {
    await pump(tester, () async => true);

    expect(find.textContaining('Allow restricted settings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification-access-banner')));
    verify(() => channel.openSystemSettings()).called(1);
  });

  testWidgets('hidden when access is on', (tester) async {
    await pump(tester, () async => false);
    expect(find.byKey(const Key('notification-access-banner')), findsNothing);
  });

  testWidgets('hidden when the check fails', (tester) async {
    await pump(tester, () async => throw Exception('no channel'));
    expect(find.byKey(const Key('notification-access-banner')), findsNothing);
  });
}
