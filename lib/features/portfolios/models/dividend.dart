import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/portfolios/schemas.py`'s `DividendOut`.
class Dividend {
  const Dividend({
    required this.id,
    required this.holdingId,
    required this.payDate,
    required this.amount,
    required this.currency,
    required this.taxWithheld,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String holdingId;
  final DateTime payDate;
  final Decimal amount;
  final String currency;
  final Decimal taxWithheld;
  final String? note;
  final DateTime createdAt;

  factory Dividend.fromJson(Map<String, dynamic> json) => Dividend(
        id: json['id'] as String,
        holdingId: json['holding_id'] as String,
        payDate: DateTime.parse(json['pay_date'] as String),
        amount: Decimal.parse(json['amount'].toString()),
        currency: json['currency'] as String,
        taxWithheld: Decimal.parse(json['tax_withheld'].toString()),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
