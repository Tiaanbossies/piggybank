import 'package:decimal/decimal.dart';

enum ImportStatus { pending, completed, failed, partial }

ImportStatus importStatusFromJson(String value) =>
    ImportStatus.values.firstWhere((s) => s.name == value);

/// Mirrors `backend/app/imports/schemas.py`'s `ImportJobOut`.
class ImportJob {
  const ImportJob({
    required this.id,
    required this.filename,
    required this.status,
    required this.totalRows,
    required this.importedRows,
    required this.failedRows,
    required this.autoCategorizedRows,
    required this.duplicateRows,
    required this.errorMessage,
    required this.importedBalance,
    required this.createdAt,
  });

  final String id;
  final String filename;
  final ImportStatus status;
  final int totalRows;
  final int importedRows;
  final int failedRows;
  final int autoCategorizedRows;
  final int duplicateRows;
  final String? errorMessage;
  final Decimal? importedBalance;
  final DateTime createdAt;

  factory ImportJob.fromJson(Map<String, dynamic> json) => ImportJob(
        id: json['id'] as String,
        filename: json['filename'] as String,
        status: importStatusFromJson(json['status'] as String),
        totalRows: json['total_rows'] as int,
        importedRows: json['imported_rows'] as int,
        failedRows: json['failed_rows'] as int,
        autoCategorizedRows: json['auto_categorized_rows'] as int,
        duplicateRows: json['duplicate_rows'] as int,
        errorMessage: json['error_message'] as String?,
        importedBalance: json['imported_balance'] == null
            ? null
            : Decimal.parse(json['imported_balance'].toString()),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Mirrors `GET /imports/templates`'s response shape.
class BankTemplate {
  const BankTemplate({required this.bankId, required this.displayName});

  final String bankId;
  final String displayName;

  factory BankTemplate.fromJson(Map<String, dynamic> json) => BankTemplate(
        bankId: json['bank_id'] as String,
        displayName: json['display_name'] as String,
      );
}
