import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/consents/consent_models.dart';
import 'package:piggybank/features/consent/data/consents_api.dart';
import 'package:piggybank/features/detection/data/detection_api.dart';
import 'package:piggybank/features/detection/models/gmail_connection_status.dart';
import 'package:piggybank/features/detection/models/notification_source.dart';
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
    when(() => mockChannel.senderAllowlist()).thenAnswer((_) async => {});
    when(() => mockChannel.seenSenders()).thenAnswer((_) async => {});
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

  group('messaging app sender allowlist', () {
    void acceptConsent() {
      when(() => mockConsentsApi.listAccepted()).thenAnswer((_) async => [
            ConsentRecord(
              id: 'c1',
              documentType: 'notification_email_detection',
              documentVersion: '1.0',
              acceptedAt: DateTime(2026, 9, 1),
            ),
          ]);
      when(() => mockChannel.updateAllowlist(any())).thenAnswer((_) async {});
      when(() => mockChannel.updateSenderAllowlist(any())).thenAnswer((_) async {});
      when(() => mockDetectionApi.listNotificationSources()).thenAnswer((_) async => []);
      when(() => mockDetectionApi.listEmailSources()).thenAnswer((_) async => []);
      when(() => mockDetectionApi.getGmailStatus())
          .thenAnswer((_) async => const GmailConnectionStatus(connected: false));
    }

    Future<void> addApp(WidgetTester tester, String package, String label) async {
      when(() => mockDetectionApi.addNotificationSource(appPackageName: package, appLabel: label))
          .thenAnswer((_) async => NotificationSource(id: 's1', appPackageName: package, appLabel: label, isActive: true));
      await pumpApp(tester, const DetectionSettingsScreen(), overrides: overrides());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Add').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Package name'), package);
      await tester.enterText(find.widgetWithText(TextField, 'Label'), label);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();
    }

    testWidgets('adding a messaging app opens the sender dialog straight away', (tester) async {
      acceptConsent();
      when(() => mockChannel.seenSenders()).thenAnswer((_) async => {
            'com.google.android.apps.messaging': ['FNB', 'Mom'],
          });

      await addApp(tester, 'com.google.android.apps.messaging', 'Messages');

      expect(find.text('Senders in Messages'), findsOneWidget);
      expect(find.text('Only messages from senders you tick are read.'), findsOneWidget);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'FNB'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      verify(() => mockChannel.updateSenderAllowlist({
            'com.google.android.apps.messaging': ['FNB'],
          })).called(1);
      expect(find.textContaining('— FNB'), findsOneWidget);
    });

    testWidgets('a messaging app with no senders ticked says nothing is read', (tester) async {
      acceptConsent();

      await addApp(tester, 'com.whatsapp', 'WhatsApp');
      expect(find.textContaining('Only messages from senders you tick are read.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('com.whatsapp — no senders ticked, nothing read'), findsOneWidget);
    });

    testWidgets('a sender can be typed before the phone has seen it', (tester) async {
      acceptConsent();

      await addApp(tester, 'com.google.android.apps.messaging', 'Messages');
      await tester.enterText(find.widgetWithText(TextField, 'Add a sender'), 'Capitec');
      await tester.tap(find.byTooltip('Add sender'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      verify(() => mockChannel.updateSenderAllowlist({
            'com.google.android.apps.messaging': ['Capitec'],
          })).called(1);
    });

    test('messagingPackages matches DetectionFilter.MESSAGING_PACKAGES in Kotlin', () {
      final kt = File('android/app/src/main/kotlin/za/co/fynboscreative/piggybank/DetectionFilter.kt')
          .readAsStringSync();
      final block = RegExp(r'MESSAGING_PACKAGES = setOf\(([^)]*)\)').firstMatch(kt)!.group(1)!;
      final kotlin = RegExp(r'"([^"]+)"').allMatches(block).map((m) => m.group(1)).toSet();
      expect(kotlin, messagingPackages);
    });

    testWidgets('adding a bank app does not open the sender dialog', (tester) async {
      acceptConsent();

      await addApp(tester, 'za.co.fnb.connect.itest', 'FNB');

      expect(find.textContaining('Senders in'), findsNothing);
      expect(find.text('za.co.fnb.connect.itest — all senders'), findsOneWidget);
    });
  });
}
