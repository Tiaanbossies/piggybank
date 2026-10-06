import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
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

/// A transaction the backend already categorised — the one-tap case.
DetectedEvent _suggestedTransaction({String id = 'evt-3'}) => DetectedEvent(
      id: id,
      sourceType: DetectionSourceType.notification,
      sourceRef: 'za.co.fnb.connect.itest',
      rawText: 'You spent R80.00 at Spar',
      capturedAt: DateTime(2026, 10, 5, 9),
      status: DetectionStatus.pending,
      extractedJson: const {
        'event_kind': 'transaction',
        'transaction_type': 'expense',
        'amount': '80.00',
        'description': 'Spar',
        'suggested_category': 'Groceries',
        'suggested_subcategory': 'Weekly shop',
      },
      eventKind: 'transaction',
      errorReason: null,
    );

/// Longer than the screen's 4s Undo snackbar, so its `closed` future has
/// completed and the held-back request has been sent.
const _undoWindow = Duration(seconds: 5);

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

    // Hidden at once, but only sent once the Undo window closes.
    expect(find.text('za.co.fnb.connect.itest'), findsNothing);
    verifyNever(() => mockApi.discardEvent(any()));

    await tester.pump(_undoWindow);
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
    await tester.pump(_undoWindow);
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

  group('one-tap review', () {
    void stubConfirm() {
      when(() => mockApi.confirmEvent(
            any(),
            accountId: any(named: 'accountId'),
            category: any(named: 'category'),
            subcategory: any(named: 'subcategory'),
            holdingId: any(named: 'holdingId'),
            quantity: any(named: 'quantity'),
            pricePerUnit: any(named: 'pricePerUnit'),
            tradeType: any(named: 'tradeType'),
          )).thenAnswer((_) async => _suggestedTransaction());
    }

    testWidgets('shows what a tap will file it as, plus an Edit escape hatch', (tester) async {
      when(() => mockApi.listPending()).thenAnswer((_) async => [_suggestedTransaction()]);

      await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
      await tester.pumpAndSettle();

      expect(find.text('Groceries › Weekly shop'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Edit'), findsOneWidget);
    });

    testWidgets('Confirm sends the suggestion straight away — no sheet', (tester) async {
      when(() => mockApi.listPending()).thenAnswer((_) async => [_suggestedTransaction()]);
      stubConfirm();

      await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm transaction'), findsNothing); // the sheet's title
      expect(find.textContaining('Confirmed · Spar · Groceries'), findsOneWidget);

      await tester.pump(_undoWindow);
      await tester.pumpAndSettle();

      verify(() => mockApi.confirmEvent(
            'evt-3',
            accountId: null,
            category: 'Groceries',
            subcategory: 'Weekly shop',
            holdingId: null,
            quantity: null,
            pricePerUnit: null,
            tradeType: null,
          )).called(1);
    });

    testWidgets('Undo puts the card back and never calls the backend', (tester) async {
      when(() => mockApi.listPending()).thenAnswer((_) async => [_suggestedTransaction()]);
      stubConfirm();

      await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.pump(_undoWindow);
      await tester.pumpAndSettle();

      expect(find.text('Groceries › Weekly shop'), findsOneWidget);
      verifyNever(() => mockApi.confirmEvent(
            any(),
            accountId: any(named: 'accountId'),
            category: any(named: 'category'),
            subcategory: any(named: 'subcategory'),
            holdingId: any(named: 'holdingId'),
            quantity: any(named: 'quantity'),
            pricePerUnit: any(named: 'pricePerUnit'),
            tradeType: any(named: 'tradeType'),
          ));
    });

    testWidgets('swipe right confirms, swipe left discards', (tester) async {
      when(() => mockApi.listPending())
          .thenAnswer((_) async => [_suggestedTransaction(), _suggestedTransaction(id: 'evt-4')]);
      stubConfirm();
      when(() => mockApi.discardEvent(any())).thenAnswer((_) async => _suggestedTransaction());

      await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
      await tester.pumpAndSettle();

      await tester.drag(find.byKey(const ValueKey('dismiss-evt-3')), const Offset(600, 0));
      await tester.pumpAndSettle();
      // The second action closes the first snackbar, which commits it.
      await tester.drag(find.byKey(const ValueKey('dismiss-evt-4')), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.pump(_undoWindow);
      await tester.pumpAndSettle();

      verify(() => mockApi.confirmEvent(
            'evt-3',
            accountId: any(named: 'accountId'),
            category: 'Groceries',
            subcategory: any(named: 'subcategory'),
            holdingId: any(named: 'holdingId'),
            quantity: any(named: 'quantity'),
            pricePerUnit: any(named: 'pricePerUnit'),
            tradeType: any(named: 'tradeType'),
          )).called(1);
      verify(() => mockApi.discardEvent('evt-4')).called(1);
    });

    testWidgets('a failed confirm brings the card back with the error', (tester) async {
      when(() => mockApi.listPending()).thenAnswer((_) async => [_suggestedTransaction()]);
      when(() => mockApi.confirmEvent(
            any(),
            accountId: any(named: 'accountId'),
            category: any(named: 'category'),
            subcategory: any(named: 'subcategory'),
            holdingId: any(named: 'holdingId'),
            quantity: any(named: 'quantity'),
            pricePerUnit: any(named: 'pricePerUnit'),
            tradeType: any(named: 'tradeType'),
          )).thenAnswer((_) async => throw const ApiError(statusCode: 404, message: 'Account not found'));

      await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pumpAndSettle();
      await tester.pump(_undoWindow);
      await tester.pumpAndSettle();

      expect(find.text('Groceries › Weekly shop'), findsOneWidget);
      expect(find.text('Account not found'), findsOneWidget);
    });

    testWidgets('a transaction with no suggestion cannot be swiped to confirm', (tester) async {
      when(() => mockApi.listPending()).thenAnswer((_) async => [_pendingTransaction()]);

      await pumpApp(tester, const PendingReviewScreen(), overrides: overrides());
      await tester.pumpAndSettle();

      final dismissible = tester.widget<Dismissible>(find.byKey(const ValueKey('dismiss-evt-1')));
      expect(dismissible.direction, DismissDirection.endToStart);
    });
  });
}
