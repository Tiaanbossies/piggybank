import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/detection/data/detection_api.dart';
import 'package:piggybank/features/detection/native/notification_listener_channel.dart';
import 'package:piggybank/features/detection/services/notification_capture_service.dart';

class MockNotificationListenerChannel extends Mock implements NotificationListenerChannel {}

class MockDetectionApi extends Mock implements DetectionApi {}

void main() {
  late MockNotificationListenerChannel mockChannel;
  late MockDetectionApi mockApi;
  late NotificationCaptureService service;

  setUp(() {
    mockChannel = MockNotificationListenerChannel();
    mockApi = MockDetectionApi();
    service = NotificationCaptureService(mockChannel, mockApi);
  });

  test('does nothing when the native queue is empty', () async {
    when(() => mockChannel.peekQueuedItems()).thenAnswer((_) async => []);

    await service.flush();

    verifyNever(() => mockApi.ingestNotifications(any()));
    verifyNever(() => mockChannel.acknowledgeQueuedItems(any()));
  });

  test('uploads queued items and acknowledges exactly what the backend reported processed', () async {
    final items = [
      {'source_ref': 'za.co.fnb.connect.itest', 'raw_text': 'You spent R150.00', 'captured_at': '2026-09-15T10:00:00Z'},
    ];
    when(() => mockChannel.peekQueuedItems()).thenAnswer((_) async => items);
    when(() => mockApi.ingestNotifications(items)).thenAnswer(
      (_) async => {'processed': 1, 'created': 1, 'skipped_invalid': 0, 'not_financial': 0, 'rejected_not_allowlisted': 0},
    );
    when(() => mockChannel.acknowledgeQueuedItems(any())).thenAnswer((_) async {});

    await service.flush();

    verify(() => mockApi.ingestNotifications(items)).called(1);
    verify(() => mockChannel.acknowledgeQueuedItems(1)).called(1);
  });

  test('leaves the queue untouched when the upload fails (nothing lost, retried next flush)', () async {
    final items = [
      {'source_ref': 'za.co.fnb.connect.itest', 'raw_text': 'You spent R150.00', 'captured_at': '2026-09-15T10:00:00Z'},
    ];
    when(() => mockChannel.peekQueuedItems()).thenAnswer((_) async => items);
    when(() => mockApi.ingestNotifications(items))
        .thenThrow(const ApiError(statusCode: 503, message: 'Local AI service not configured'));

    await service.flush();

    verifyNever(() => mockChannel.acknowledgeQueuedItems(any()));
  });
}
