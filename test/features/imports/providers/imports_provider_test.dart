import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/imports/data/imports_api.dart';
import 'package:piggybank/features/imports/models/import_job.dart';
import 'package:piggybank/features/imports/providers/imports_provider.dart';

class MockImportsApi extends Mock implements ImportsApi {}

ImportJob _job({String id = 'j1', ImportStatus status = ImportStatus.completed}) => ImportJob(
      id: id,
      filename: 'statement.csv',
      status: status,
      totalRows: 10,
      importedRows: 9,
      failedRows: 1,
      autoCategorizedRows: 6,
      duplicateRows: 0,
      errorMessage: null,
      importedBalance: null,
      createdAt: DateTime(2026, 8, 1),
    );

void main() {
  late MockImportsApi mockApi;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockImportsApi();
    container = ProviderContainer(overrides: [importsApiProvider.overrideWithValue(mockApi)]);
  });

  tearDown(() => container.dispose());

  group('bankTemplatesProvider', () {
    test('fetches the list of supported bank templates', () async {
      when(() => mockApi.listTemplates()).thenAnswer((_) async => [
            const BankTemplate(bankId: 'fnb', displayName: 'FNB'),
            const BankTemplate(bankId: 'capitec', displayName: 'Capitec'),
          ]);

      final result = await container.read(bankTemplatesProvider.future);

      expect(result, hasLength(2));
      expect(result.map((t) => t.bankId), containsAll(['fnb', 'capitec']));
      verify(() => mockApi.listTemplates()).called(1);
    });

    test('surfaces an empty list as-is (no synthetic "generic" entry added client-side)', () async {
      when(() => mockApi.listTemplates()).thenAnswer((_) async => []);
      final result = await container.read(bankTemplatesProvider.future);
      expect(result, isEmpty);
    });
  });

  group('importHistoryProvider', () {
    test('fetches past import jobs', () async {
      when(() => mockApi.listImports()).thenAnswer((_) async => [_job()]);
      final result = await container.read(importHistoryProvider.future);
      expect(result, hasLength(1));
      expect(result.single.status, ImportStatus.completed);
      verify(() => mockApi.listImports()).called(1);
    });

    test('propagates api errors to the FutureProvider as an error state', () async {
      when(() => mockApi.listImports()).thenThrow(Exception('network down'));
      await expectLater(container.read(importHistoryProvider.future), throwsException);
    });
  });

  group('importsApiProvider normalize wiring (called directly by ImportsScreen)', () {
    // uploadCsv/ocrReceipt are intentionally not exercised here — both go
    // through `dio.MultipartFile.fromFile`, which requires a real file on
    // disk selected via file_picker/image_picker (native platform plugins,
    // not faked by this test harness). See docs/qa/QA_LOG.md for that gap.

    test('normalizeCategories forwards the importId and returns the parsed counts', () async {
      when(() => mockApi.normalizeCategories(any()))
          .thenAnswer((_) async => {'normalized': 3, 'rules_added': 1});

      final api = container.read(importsApiProvider);
      final result = await api.normalizeCategories('j1');

      expect(result, {'normalized': 3, 'rules_added': 1});
      verify(() => mockApi.normalizeCategories('j1')).called(1);
    });
  });
}
