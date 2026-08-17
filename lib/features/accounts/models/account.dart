import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/accounts/schemas.py`'s `AccountOut`. Money fields are
/// parsed as [Decimal] from the JSON string/number the backend sends, never
/// `double`, to avoid currency rounding drift (see DESIGN.md / plan notes).
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.accountType,
    required this.currency,
    required this.balance,
    required this.isActive,
    this.institutionName,
  });

  final String id;
  final String name;
  final String accountType;
  final String currency;
  final Decimal balance;
  final bool isActive;
  final String? institutionName;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        accountType: json['account_type'] as String,
        currency: json['currency'] as String,
        balance: json['balance'] == null ? Decimal.zero : Decimal.parse(json['balance'].toString()),
        isActive: json['is_active'] as bool,
        institutionName: json['institution_name'] as String?,
      );
}
