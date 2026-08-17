import 'package:decimal/decimal.dart';

enum TransactionType { income, expense, transfer }

TransactionType transactionTypeFromJson(String value) =>
    TransactionType.values.firstWhere((t) => t.name == value);

/// Mirrors `backend/app/transactions/schemas.py`'s `TransactionOut`.
class Transaction {
  const Transaction({
    required this.id,
    required this.accountId,
    required this.transactionType,
    required this.category,
    required this.description,
    required this.amount,
    required this.transactionDate,
    required this.merchantName,
    required this.notes,
    required this.accountName,
  });

  final String id;
  final String? accountId;
  final TransactionType transactionType;
  final String category;
  final String? description;
  final Decimal amount;
  final DateTime transactionDate;
  final String? merchantName;
  final String? notes;
  final String? accountName;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        accountId: json['account_id'] as String?,
        transactionType: transactionTypeFromJson(json['transaction_type'] as String),
        category: json['category'] as String,
        description: json['description'] as String?,
        amount: Decimal.parse(json['amount'].toString()),
        transactionDate: DateTime.parse(json['transaction_date'] as String),
        merchantName: json['merchant_name'] as String?,
        notes: json['notes'] as String?,
        accountName: json['account_name'] as String?,
      );
}
