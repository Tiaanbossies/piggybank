import 'package:decimal/decimal.dart';

import 'holding.dart';

/// Mirrors `backend/app/portfolios/schemas.py`'s `AllocationItem`.
class AllocationItem {
  const AllocationItem({required this.assetClass, required this.value, required this.percent});

  final AssetClass assetClass;
  final Decimal value;
  final Decimal percent;

  factory AllocationItem.fromJson(Map<String, dynamic> json) => AllocationItem(
        assetClass: assetClassFromJson(json['asset_class'] as String),
        value: Decimal.parse(json['value'].toString()),
        percent: Decimal.parse(json['percent'].toString()),
      );
}

/// Mirrors `backend/app/portfolios/schemas.py`'s `TopHolding`.
class TopHolding {
  const TopHolding({
    required this.holdingId,
    required this.portfolioId,
    required this.ticker,
    required this.name,
    required this.value,
    required this.unrealizedPl,
  });

  final String holdingId;
  final String portfolioId;
  final String ticker;
  final String name;
  final Decimal value;
  final Decimal unrealizedPl;

  factory TopHolding.fromJson(Map<String, dynamic> json) => TopHolding(
        holdingId: json['holding_id'] as String,
        portfolioId: json['portfolio_id'] as String,
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        value: Decimal.parse(json['value'].toString()),
        unrealizedPl: Decimal.parse(json['unrealized_pl'].toString()),
      );
}

/// Mirrors `backend/app/portfolios/schemas.py`'s `InvestmentOverview` — the
/// aggregated landing payload for the Invest tab-root screen.
class InvestmentOverview {
  const InvestmentOverview({
    required this.totalValue,
    required this.totalCost,
    required this.unrealizedPl,
    required this.ytdDividends,
    required this.portfolioCount,
    required this.holdingCount,
    required this.allocation,
    required this.topHoldings,
  });

  final Decimal totalValue;
  final Decimal totalCost;
  final Decimal unrealizedPl;
  final Decimal ytdDividends;
  final int portfolioCount;
  final int holdingCount;
  final List<AllocationItem> allocation;
  final List<TopHolding> topHoldings;

  factory InvestmentOverview.fromJson(Map<String, dynamic> json) => InvestmentOverview(
        totalValue: Decimal.parse(json['total_value'].toString()),
        totalCost: Decimal.parse(json['total_cost'].toString()),
        unrealizedPl: Decimal.parse(json['unrealized_pl'].toString()),
        ytdDividends: Decimal.parse(json['ytd_dividends'].toString()),
        portfolioCount: json['portfolio_count'] as int,
        holdingCount: json['holding_count'] as int,
        allocation: (json['allocation'] as List).map((e) => AllocationItem.fromJson(e as Map<String, dynamic>)).toList(),
        topHoldings: (json['top_holdings'] as List).map((e) => TopHolding.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
