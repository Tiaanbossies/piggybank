import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/accounts/data/accounts_api.dart';
import 'package:piggybank/features/accounts/providers/accounts_provider.dart';
import 'package:piggybank/features/detection/data/detection_api.dart';
import 'package:piggybank/features/detection/models/detected_event.dart';
import 'package:piggybank/features/detection/providers/detection_provider.dart';
import 'package:piggybank/features/detection/screens/pending_review_screen.dart';

import '../../../test_helpers/pump_app.dart';

class _MockDetectionApi extends Mock implements DetectionApi {}

class _MockAccountsApi extends Mock implements AccountsApi {}

DetectedEvent _pendingTransaction({String id = 'evt-1'}) => DetectedEvent(
      id: id,
      sourceType: DetectionSourceType.notification,
      sourceRef: 'za.co.fnb.connect.itest',
      rawText: 'You spent R150.00 at Woolworths',
      capturedAt: DateTime(2026, 9, 15, 10),
      status: DetectionStatus.pending,
      extractedJson: const {
        'event_kind': 'transaction',
        'transaction_type': 'expense',
        'amount': '150.00',
        'description': 'Woolworths',
        'date': '2026-09-15',
        'ticker': null,
      },
      eventKind: 'transaction',
      errorReason: null,
    );

DetectedEvent _skippedInvalid({String id = 'evt-2'}) => DetectedEvent(
      id: id,
      sourceType: DetectionSourceType.email,
      sourceRef: 'alerts@easyequities.co.za',
      rawText: 'garbled unparseable text',
      capturedAt: DateTime(2026, 9, 15, 11),
      status: DetectionStatus.skippedInvalid,
      extractedJson: null,
      eventKind: null,
      errorReason: 'model response unparseable',
    );

void main() {
  late _MockDetectionApi mockApi;
  late _MockAccountsApi mockAccountsApi;

  List<Override> overrides() => [
        detectionApiProvider.overrideWithValue(mockApi),
        accountsApiProvider.overrideWithValue(mockAccountsApi),
      ];

  setUp(() {
    mockApi = _MockDetectionApi();
    mockAccountsApi = _MockAccountsApi();
    when(() => mockAccountsApi.list(includeInactive: any(named: 'includeInactive'))).thenAnswer((_) async => []);
  });

  testWidgets('empty state shows a friendly message instead of a blank list', (tester) async {
    when(() => mockApi.listPending()).thenAnswer((_) async => []);

    await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing waiting for review'), findsOneWidget);
  });

  testWidgets('populated state renders the extracted fields for a pending transaction', (tester) async {
    when(() => mockApi.listPending()).thenAnswer((_) async => [_pendingTransaction()]);

    await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('za.co.fnb.connect.itest'), findsOneWidget);
    expect(find.textContaining('R 150,00'), findsOneWidget);
    expect(find.textContaining('Woolworths'), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, 'Confirm'), findsOneWidget);
  });

  testWidgets('skipped_invalid rows show the error reason and only offer Discard', (tester) async {
    when(() => mockApi.listPending()).thenAnswer((_) async => [_skippedInvalid()]);

    await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('model response unparseable'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Confirm'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Discard'), findsOneWidget);
  });

  testWidgets('Discard calls discardEvent and removes the row from the list', (tester) async {
    when(() => mockApi.listPending()).thenAnswer((_) async => [_pendingTransaction()]);
    when(() => mockApi.discardEvent('evt-1')).thenAnswer((_) async => _pendingTransaction());

    await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    verify(() => mockApi.discardEvent('evt-1')).called(1);
  });

  testWidgets('Confirm on a transaction requires a category before it can be submitted', (tester) async {
    when(() => mockApi.listPending()).thenAnswer((_) async => [_pendingTransaction()]);

    await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm').first);
    await tester.pumpAndSettle();

    // The sheet's own Confirm button, distinct from the card's.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Choose a category'), findsOneWidget);
    verifyNever(() => mockApi.confirmEvent(any(), category: any(named: 'category')));
  });

  testWidgets('entering a category and confirming calls confirmEvent with it', (tester) async {
    when(() => mockApi.listPending()).thenAnswer((_) async => [_pendingTransaction()]);
    when(() => mockApi.confirmEvent(
          'evt-1',
          accountId: any(named: 'accountId'),
          category: any(named: 'category'),
          subcategory: any(named: 'subcategory'),
          holdingId: any(named: 'holdingId'),
          quantity: any(named: 'quantity'),
          pricePerUnit: any(named: 'pricePerUnit'),
          tradeType: any(named: 'tradeType'),
        )).thenAnswer((_) async => _pendingTransaction());

    await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Category'), 'Groceries');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm').last);
    await tester.pumpAndSettle();

    verify(() => mockApi.confirmEvent(
          'evt-1',
          accountId: null,
          category: 'Groceries',
          subcategory: null,
          holdingId: null,
          quantity: null,
          pricePerUnit: null,
          tradeType: null,
        )).called(1);
  });
}
