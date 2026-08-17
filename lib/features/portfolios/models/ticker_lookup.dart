import 'package:decimal/decimal.dart';

/// Mirrors `GET /portfolios/ticker-lookup`'s response shape (an untyped
/// dict server-side, backed by `FundInfo` in `market_data/base.py`).
class TickerLookup {
  const TickerLookup({
    required this.ticker,
    required this.name,
    required this.currentPrice,
    this.expenseRatio,
    this.fundFamily,
    this.inceptionDate,
    this.fundCategory,
    this.dividendYield,
  });

  final String ticker;
  final String name;
  final Decimal currentPrice;
  final Decimal? expenseRatio;
  final String? fundFamily;
  final DateTime? inceptionDate;
  final String? fundCategory;
  final Decimal? dividendYield;

  factory TickerLookup.fromJson(Map<String, dynamic> json) => TickerLookup(
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        currentPrice: Decimal.parse(json['current_price'].toString()),
        expenseRatio: json['expense_ratio'] == null ? null : Decimal.parse(json['expense_ratio'].toString()),
        fundFamily: json['fund_family'] as String?,
        inceptionDate: json['inception_date'] == null ? null : DateTime.parse(json['inception_date'] as String),
        fundCategory: json['fund_category'] as String?,
        dividendYield: json['dividend_yield'] == null ? null : Decimal.parse(json['dividend_yield'].toString()),
      );
}
