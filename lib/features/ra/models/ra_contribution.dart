import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/ra/schemas.py`'s `RaContributionOut`.
class RaContribution {
  const RaContribution({
    required this.id,
    required this.taxYear,
    required this.amount,
    required this.contributionDate,
    required this.notes,
    required this.provider,
    required this.overAnnualLimitWarning,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int taxYear;
  final Decimal amount;
  final DateTime? contributionDate;
  final String? notes;
  final String? provider;
  final bool overAnnualLimitWarning;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RaContribution.fromJson(Map<String, dynamic> json) => RaContribution(
        id: json['id'] as String,
        taxYear: json['tax_year'] as int,
        amount: Decimal.parse(json['amount'].toString()),
        contributionDate: json['contribution_date'] == null ? null : DateTime.parse(json['contribution_date'] as String),
        notes: json['notes'] as String?,
        provider: json['provider'] as String?,
        overAnnualLimitWarning: json['over_annual_limit_warning'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
