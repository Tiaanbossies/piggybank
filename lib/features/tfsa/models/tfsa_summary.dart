import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/tfsa/schemas.py`'s `TfsaByYear`.
class TfsaByYear {
  const TfsaByYear({
    required this.taxYear,
    required this.contributed,
    required this.limit,
    required this.overLimit,
  });

  final int taxYear;
  final Decimal contributed;
  final Decimal limit;
  final bool overLimit;

  factory TfsaByYear.fromJson(Map<String, dynamic> json) => TfsaByYear(
        taxYear: json['tax_year'] as int,
        contributed: Decimal.parse(json['contributed'].toString()),
        limit: Decimal.parse(json['limit'].toString()),
        overLimit: json['over_limit'] as bool,
      );
}

/// Mirrors `backend/app/tfsa/schemas.py`'s `TfsaSummary`.
class TfsaSummary {
  const TfsaSummary({
    required this.lifetimeLimit,
    required this.lifetimeContributed,
    required this.lifetimeRemaining,
    required this.annualLimit,
    required this.currentYear,
    required this.currentYearContributed,
    required this.currentYearRemaining,
    required this.yearsToLifetimeLimit,
    required this.byYear,
  });

  final Decimal lifetimeLimit;
  final Decimal lifetimeContributed;
  final Decimal lifetimeRemaining;
  final Decimal annualLimit;
  final int currentYear;
  final Decimal currentYearContributed;
  final Decimal currentYearRemaining;
  final int? yearsToLifetimeLimit;
  final List<TfsaByYear> byYear;

  factory TfsaSummary.fromJson(Map<String, dynamic> json) => TfsaSummary(
        lifetimeLimit: Decimal.parse(json['lifetime_limit'].toString()),
        lifetimeContributed: Decimal.parse(json['lifetime_contributed'].toString()),
        lifetimeRemaining: Decimal.parse(json['lifetime_remaining'].toString()),
        annualLimit: Decimal.parse(json['annual_limit'].toString()),
        currentYear: json['current_year'] as int,
        currentYearContributed: Decimal.parse(json['current_year_contributed'].toString()),
        currentYearRemaining: Decimal.parse(json['current_year_remaining'].toString()),
        yearsToLifetimeLimit: json['years_to_lifetime_limit'] as int?,
        byYear: (json['by_year'] as List).map((e) => TfsaByYear.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
