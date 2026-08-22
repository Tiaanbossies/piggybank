import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/imports/schemas.py`'s `OcrResult` (response of
/// `POST /imports/ocr`).
class OcrResult {
  const OcrResult({
    required this.date,
    required this.merchantName,
    required this.amount,
    required this.category,
    required this.description,
    required this.transactionType,
    required this.confidenceScore,
    required this.rawText,
  });

  final String? date;
  final String? merchantName;
  final Decimal? amount;
  final String? category;
  final String? description;
  final String transactionType; // 'income' | 'expense'
  final double confidenceScore;
  final String? rawText;

  factory OcrResult.fromJson(Map<String, dynamic> json) => OcrResult(
        date: json['date'] as String?,
        merchantName: json['merchant_name'] as String?,
        amount: json['amount'] == null ? null : Decimal.parse(json['amount'].toString()),
        category: json['category'] as String?,
        description: json['description'] as String?,
        transactionType: json['transaction_type'] as String? ?? 'expense',
        confidenceScore: (json['confidence_score'] as num).toDouble(),
        rawText: json['raw_text'] as String?,
      );
}
