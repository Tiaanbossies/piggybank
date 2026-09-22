import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/consents/consent_models.dart';
import 'package:piggybank/features/consent/data/consents_api.dart';
import 'package:piggybank/features/detection/data/detection_api.dart';
import 'package:piggybank/features/detection/models/gmail_connection_status.dart';
import 'package:piggybank/features/detection/native/notification_listener_channel.dart';
import 'package:piggybank/features/detection/providers/detection_provider.dart';
import 'package:piggybank/features/detection/screens/detection_settings_screen.dart';

import '../../../test_helpers/pump_app.dart';

class _MockConsentsApi extends Mock implements ConsentsApi {}

class _MockNotificationListenerChannel extends Mock implements NotificationListenerChannel {}

class _MockDetectionApi extends Mock implements DetectionApi {}

void main() {
  late _MockConsentsApi mockConsentsApi;
  late _MockNotificationListenerChannel mockChannel;
  late _MockDetectionApi mockDetectionApi;

  List<Override> overrides() => [
        consentsApiProvider.overrideWithValue(mockConsentsApi),
        notificationListenerChannelProvider.overrideWithValue(mockChannel),
        detectionApiProvider.overrideWithValue(mockDetectionApi),
      ];

  setUp(() {
    mockConsentsApi = _MockConsentsApi();
    mockChannel = _MockNotificationListenerChannel();
    mockDetectionApi = _MockDetectionApi();
    when(() => mockConsentsApi.listAccepted()).thenAnswer((_) async => []);
    when(() => mockChannel.isEnabled()).thenAnswer((_) async => false);
  });

  testWidgets('unaccepted Feature consent card renders without overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, const DetectionSettingsScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Feature consent'), findsOneWidget);
    expect(find.text('Not yet accepted'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Review & enable'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('accepted Feature consent card falls back to the plain ListTile', (tester) async {
    when(() => mockConsentsApi.listAccepted()).thenAnswer((_) async => [
          ConsentRecord(
            id: 'c1',
            documentType: 'notification_email_detection',
            documentVersion: '1.0',
            acceptedAt: DateTime(2026, 9, 1),
          ),
        ]);
    when(() => mockChannel.updateAllowlist(any())).thenAnswer((_) async {});
    when(() => mockDetectionApi.listNotificationSources()).thenAnswer((_) async => []);
    when(() => mockDetectionApi.listEmailSources()).thenAnswer((_) async => []);
    when(() => mockDetectionApi.getGmailStatus())
        .thenAnswer((_) async => const GmailConnectionStatus(connected: false));

    await pumpApp(tester, const DetectionSettingsScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Review & enable'), findsNothing);
  });
}
