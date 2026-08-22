import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/ra/schemas.py`'s `RaByYear`.
class RaByYear {
  const RaByYear({
    required this.taxYear,
    required this.contributed,
    required this.limit,
    required this.overLimit,
  });

  final int taxYear;
  final Decimal contributed;
  final Decimal limit;
  final bool overLimit;

  factory RaByYear.fromJson(Map<String, dynamic> json) => RaByYear(
        taxYear: json['tax_year'] as int,
        contributed: Decimal.parse(json['contributed'].toString()),
        limit: Decimal.parse(json['limit'].toString()),
        overLimit: json['over_limit'] as bool,
      );
}

/// Mirrors `backend/app/ra/schemas.py`'s `RaSummary`. Unlike TFSA, RA has no
/// lifetime cap (SA RA limits are annual/income-percentage based) — no
/// `lifetimeLimit`/`lifetimeRemaining`/`yearsToLifetimeLimit` fields.
class RaSummary {
  const RaSummary({
    required this.annualLimit,
    required this.totalContributed,
    required this.currentYear,
    required this.currentYearContributed,
    required this.currentYearRemaining,
    required this.byYear,
  });

  final Decimal annualLimit;
  final Decimal totalContributed;
  final int currentYear;
  final Decimal currentYearContributed;
  final Decimal currentYearRemaining;
  final List<RaByYear> byYear;

  factory RaSummary.fromJson(Map<String, dynamic> json) => RaSummary(
        annualLimit: Decimal.parse(json['annual_limit'].toString()),
        totalContributed: Decimal.parse(json['total_contributed'].toString()),
        currentYear: json['current_year'] as int,
        currentYearContributed: Decimal.parse(json['current_year_contributed'].toString()),
        currentYearRemaining: Decimal.parse(json['current_year_remaining'].toString()),
        byYear: (json['by_year'] as List).map((e) => RaByYear.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
