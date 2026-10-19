import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/core/consents/consent_models.dart';
import 'package:piggybank/features/consent/consent_documents.dart';
import 'package:piggybank/features/consent/data/consents_api.dart';
import 'package:piggybank/features/detection/data/detection_api.dart';
import 'package:piggybank/features/detection/models/notification_source.dart';
import 'package:piggybank/features/detection/native/notification_listener_channel.dart';
import 'package:piggybank/features/detection/services/detection_setup_service.dart';

class MockConsentsApi extends Mock implements ConsentsApi {}

class MockDetectionApi extends Mock implements DetectionApi {}

class MockNotificationListenerChannel extends Mock implements NotificationListenerChannel {}

final _detectionConsent = ConsentRecord(
  id: 'c1',
  documentType: notificationEmailDetectionConsentDocument.documentType,
  documentVersion: notificationEmailDetectionConsentDocument.documentVersion,
  acceptedAt: DateTime(2026, 9, 1),
);

const _fnb = NotificationSource(id: 's1', appPackageName: 'za.co.fnb.connect.itest', appLabel: 'FNB', isActive: true);
const _paused = NotificationSource(id: 's2', appPackageName: 'com.capitec.app', appLabel: 'Capitec', isActive: false);

void main() {
  late MockConsentsApi consents;
  late MockDetectionApi api;
  late MockNotificationListenerChannel channel;
  late DetectionSetupService service;

  setUp(() {
    consents = MockConsentsApi();
    api = MockDetectionApi();
    channel = MockNotificationListenerChannel();
    service = DetectionSetupService(consents, api, channel);
    when(() => channel.updateAllowlist(any())).thenAnswer((_) async {});
  });

  group('syncAllowlist', () {
    test('pushes only the active packages once consent is accepted', () async {
      when(() => consents.listAccepted()).thenAnswer((_) async => [_detectionConsent]);
      when(() => api.listNotificationSources()).thenAnswer((_) async => [_fnb, _paused]);

      await service.syncAllowlist();

      verify(() => channel.updateAllowlist(['za.co.fnb.connect.itest'])).called(1);
    });

    test('does nothing without the detection consent', () async {
      when(() => consents.listAccepted()).thenAnswer((_) async => []);

      await service.syncAllowlist();

      verifyNever(() => api.listNotificationSources());
      verifyNever(() => channel.updateAllowlist(any()));
    });

    test('swallows an API error (logged out or offline) and leaves the allowlist alone', () async {
      when(() => consents.listAccepted()).thenThrow(const ApiError(statusCode: 401, message: 'Not authenticated'));

      await service.syncAllowlist();

      verifyNever(() => channel.updateAllowlist(any()));
    });
  });

  group('needsNotificationAccess', () {
    test('true when set up but access is off', () async {
      when(() => consents.listAccepted()).thenAnswer((_) async => [_detectionConsent]);
      when(() => api.listNotificationSources()).thenAnswer((_) async => [_fnb]);
      when(() => channel.isEnabled()).thenAnswer((_) async => false);

      expect(await service.needsNotificationAccess(), isTrue);
    });

    test('false when access is on', () async {
      when(() => consents.listAccepted()).thenAnswer((_) async => [_detectionConsent]);
      when(() => api.listNotificationSources()).thenAnswer((_) async => [_fnb]);
      when(() => channel.isEnabled()).thenAnswer((_) async => true);

      expect(await service.needsNotificationAccess(), isFalse);
    });

    test('false without consent, or with no active source', () async {
      when(() => channel.isEnabled()).thenAnswer((_) async => false);

      when(() => consents.listAccepted()).thenAnswer((_) async => []);
      expect(await service.needsNotificationAccess(), isFalse);

      when(() => consents.listAccepted()).thenAnswer((_) async => [_detectionConsent]);
      when(() => api.listNotificationSources()).thenAnswer((_) async => [_paused]);
      expect(await service.needsNotificationAccess(), isFalse);
    });
  });
}
