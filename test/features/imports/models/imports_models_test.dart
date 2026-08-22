import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/imports/models/import_job.dart';
import 'package:piggybank/features/imports/models/ocr_result.dart';

void main() {
  group('ImportJob.fromJson', () {
    test('parses a completed job with a numeric imported_balance', () {
      final job = ImportJob.fromJson({
        'id': 'j1',
        'filename': 'fnb-statement.csv',
        'status': 'completed',
        'total_rows': 42,
        'imported_rows': 40,
        'failed_rows': 0,
        'auto_categorized_rows': 12,
        'duplicate_rows': 2,
        'error_message': null,
        'imported_balance': 15234.56,
        'created_at': '2026-08-22T05:21:27.157149Z',
      });
      expect(job.status, ImportStatus.completed);
      expect(job.totalRows, 42);
      expect(job.importedRows, 40);
      expect(job.duplicateRows, 2);
      expect(job.importedBalance, Decimal.parse('15234.56'));
      expect(job.errorMessage, isNull);
    });

    test('parses a partial job with a stringified balance and error_message', () {
      final job = ImportJob.fromJson({
        'id': 'j2',
        'filename': 'capitec.csv',
        'status': 'partial',
        'total_rows': 10,
        'imported_rows': 7,
        'failed_rows': 3,
        'auto_categorized_rows': 0,
        'duplicate_rows': 0,
        'error_message': '[{"row": 4, "error": "invalid date"}]',
        'imported_balance': '-500.00',
        'created_at': '2026-08-22T05:21:27.157149Z',
      });
      expect(job.status, ImportStatus.partial);
      expect(job.failedRows, 3);
      expect(job.importedBalance, Decimal.parse('-500.00'));
      expect(job.errorMessage, isNotNull);
    });

    test('parses a failed job with a null imported_balance', () {
      final job = ImportJob.fromJson({
        'id': 'j3',
        'filename': 'bad.csv',
        'status': 'failed',
        'total_rows': 0,
        'imported_rows': 0,
        'failed_rows': 0,
        'auto_categorized_rows': 0,
        'duplicate_rows': 0,
        'error_message': null,
        'imported_balance': null,
        'created_at': '2026-08-22T05:21:27.157149Z',
      });
      expect(job.status, ImportStatus.failed);
      expect(job.importedBalance, isNull);
    });
  });

  group('BankTemplate.fromJson', () {
    test('parses bank_id and display_name', () {
      final tpl = BankTemplate.fromJson({'bank_id': 'fnb', 'display_name': 'FNB'});
      expect(tpl.bankId, 'fnb');
      expect(tpl.displayName, 'FNB');
    });
  });

  group('OcrResult.fromJson', () {
    test('parses a full high-confidence result with numeric amount', () {
      final result = OcrResult.fromJson({
        'date': '2026-08-20',
        'merchant_name': 'Woolworths',
        'amount': 234.50,
        'category': 'Groceries',
        'description': 'Weekly shop',
        'transaction_type': 'expense',
        'confidence_score': 0.92,
        'raw_text': 'WOOLWORTHS ...',
      });
      expect(result.merchantName, 'Woolworths');
      expect(result.amount, Decimal.parse('234.50'));
      expect(result.confidenceScore, 0.92);
      expect(result.transactionType, 'expense');
    });

    test('parses a low-confidence result with all optional fields null', () {
      final result = OcrResult.fromJson({
        'date': null,
        'merchant_name': null,
        'amount': null,
        'category': null,
        'description': null,
        'transaction_type': 'expense',
        'confidence_score': 0.1,
        'raw_text': null,
      });
      expect(result.date, isNull);
      expect(result.merchantName, isNull);
      expect(result.amount, isNull);
      expect(result.confidenceScore, 0.1);
    });
  });
}
