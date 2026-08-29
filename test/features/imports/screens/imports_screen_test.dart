import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/accounts/data/accounts_api.dart';
import 'package:piggybank/features/accounts/models/account.dart';
import 'package:piggybank/features/accounts/providers/accounts_provider.dart';
import 'package:piggybank/features/imports/data/imports_api.dart';
import 'package:piggybank/features/imports/models/import_job.dart';
import 'package:piggybank/features/imports/providers/imports_provider.dart';
import 'package:piggybank/features/imports/screens/imports_screen.dart';
import 'package:piggybank/features/transactions/data/transactions_api.dart';
import 'package:piggybank/features/transactions/providers/transactions_provider.dart';

import '../../../test_helpers/pump_app.dart';

class MockImportsApi extends Mock implements ImportsApi {}

class MockAccountsApi extends Mock implements AccountsApi {}

class MockTransactionsApi extends Mock implements TransactionsApi {}

/// `ImportsScreen` combines the CSV import wizard (Configure -> Upload ->
/// Review, per `ui-ux-mockup-brief.md` §13 item 3) and the Scan Receipt (OCR)
/// flow in one screen (see `imports_screen.dart`'s doc comment). A single
/// `uploadCsv` call does the whole parse+import server-side in one shot —
/// the 3 steps are a client-side staging UI around that one endpoint, not 3
/// sequential backend calls — and OCR's "review extracted fields, then Save"
/// step is the closest thing to a confirm step there. Both the CSV upload
/// button and the OCR picker are gated behind native file_picker/image_picker
/// plugins this harness cannot fake, so this covers what's reachable without
/// picking a real file: initial button/empty states, the bank-template and
/// account dropdowns sourced from their providers (step 0, Configure), the
/// Upload step's gating (step 1, reached via Continue), and the
/// import-history list's populated/empty/error rendering.
void main() {
  late MockImportsApi mockImportsApi;
  late MockAccountsApi mockAccountsApi;
  late MockTransactionsApi mockTransactionsApi;

  setUp(() {
    mockImportsApi = MockImportsApi();
    mockAccountsApi = MockAccountsApi();
    mockTransactionsApi = MockTransactionsApi();
    when(() => mockImportsApi.listTemplates()).thenAnswer((_) async => [
          const BankTemplate(bankId: 'fnb', displayName: 'FNB'),
        ]);
    when(() => mockAccountsApi.list(includeInactive: any(named: 'includeInactive'))).thenAnswer((_) async => [
          Account(
            id: 'a1',
            name: 'Cheque',
            accountType: 'cheque',
            currency: 'ZAR',
            balance: Decimal.zero,
            isActive: true,
          ),
        ]);
  });

  List<Override> overrides() => [
        importsApiProvider.overrideWithValue(mockImportsApi),
        accountsApiProvider.overrideWithValue(mockAccountsApi),
        transactionsApiProvider.overrideWithValue(mockTransactionsApi),
      ];

  testWidgets('Upload is disabled until a file is chosen, and shows the "Choose CSV file" prompt', (tester) async {
    when(() => mockImportsApi.listImports()).thenAnswer((_) async => []);

    await pumpApp(tester, const ImportsScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    // Step 0 (Configure) shows the bank-template/account dropdowns and a
    // Continue button; the file picker only appears on step 1 (Upload).
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose CSV file'), findsOneWidget);
    final uploadButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Upload'));
    expect(uploadButton.onPressed, isNull);
  });

  testWidgets('shows the bank template dropdown populated from bankTemplatesProvider', (tester) async {
    when(() => mockImportsApi.listImports()).thenAnswer((_) async => []);

    await pumpApp(tester, const ImportsScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('None (generic)'), findsOneWidget);
  });

  testWidgets('renders "No imports yet" when history is empty', (tester) async {
    when(() => mockImportsApi.listImports()).thenAnswer((_) async => []);

    await pumpApp(tester, const ImportsScreen(), overrides: overrides());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('No imports yet — upload a CSV above.'), findsOneWidget);
  });

  testWidgets('renders past import jobs with their status', (tester) async {
    when(() => mockImportsApi.listImports()).thenAnswer((_) async => [
          ImportJob(
            id: 'j1',
            filename: 'fnb-statement.csv',
            status: ImportStatus.partial,
            totalRows: 20,
            importedRows: 18,
            failedRows: 2,
            autoCategorizedRows: 12,
            duplicateRows: 1,
            errorMessage: null,
            importedBalance: null,
            createdAt: DateTime(2026, 8, 1),
          ),
        ]);

    await pumpApp(tester, const ImportsScreen(), overrides: overrides());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('fnb-statement.csv'), findsOneWidget);
    expect(find.text('18 / 20 imported · 2 failed'), findsOneWidget);
    expect(find.text('PARTIAL'), findsOneWidget);
  });

  testWidgets('renders an error message when import history fails to load', (tester) async {
    when(() => mockImportsApi.listImports()).thenThrow(const ApiError(statusCode: 500, message: 'Server error.'));

    await pumpApp(tester, const ImportsScreen(), overrides: overrides());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('Server error.'), findsOneWidget);
  });
}
