import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/portfolios/schemas.py`'s `PortfolioValueOut`.
class PortfolioValue {
  const PortfolioValue({
    required this.portfolioId,
    required this.totalCost,
    required this.totalValue,
    required this.unrealizedPl,
    required this.realizedPl,
    required this.currency,
  });

  final String portfolioId;
  final Decimal totalCost;
  final Decimal totalValue;
  final Decimal unrealizedPl;
  final Decimal realizedPl;
  final String currency;

  factory PortfolioValue.fromJson(Map<String, dynamic> json) => PortfolioValue(
        portfolioId: json['portfolio_id'] as String,
        totalCost: Decimal.parse(json['total_cost'].toString()),
        totalValue: Decimal.parse(json['total_value'].toString()),
        unrealizedPl: Decimal.parse(json['unrealized_pl'].toString()),
        realizedPl: Decimal.parse(json['realized_pl'].toString()),
        currency: json['currency'] as String,
      );
}

class DividendMonthAmount {
  const DividendMonthAmount({required this.month, required this.amount});
  final int month;
  final Decimal amount;

  factory DividendMonthAmount.fromJson(Map<String, dynamic> json) => DividendMonthAmount(
        month: json['month'] as int,
        amount: Decimal.parse(json['amount'].toString()),
      );
}

/// Mirrors `backend/app/portfolios/schemas.py`'s `DividendYearSummary`.
class DividendYearSummary {
  const DividendYearSummary({
    required this.year,
    required this.totalReceived,
    required this.totalTaxWithheld,
    required this.byMonth,
  });

  final int year;
  final Decimal totalReceived;
  final Decimal totalTaxWithheld;
  final List<DividendMonthAmount> byMonth;

  factory DividendYearSummary.fromJson(Map<String, dynamic> json) => DividendYearSummary(
        year: json['year'] as int,
        totalReceived: Decimal.parse(json['total_received'].toString()),
        totalTaxWithheld: Decimal.parse(json['total_tax_withheld'].toString()),
        byMonth: (json['by_month'] as List)
            .map((e) => DividendMonthAmount.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
