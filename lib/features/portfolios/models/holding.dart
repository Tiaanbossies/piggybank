import 'package:decimal/decimal.dart';

enum AssetClass { stock, equity, bond, etf, crypto, cash, other }

AssetClass assetClassFromJson(String value) =>
    AssetClass.values.firstWhere((t) => t.name == value, orElse: () => AssetClass.other);

String assetClassToJson(AssetClass type) => type.name;

const assetClassLabels = {
  AssetClass.stock: 'Stock',
  AssetClass.equity: 'Equity',
  AssetClass.bond: 'Bond',
  AssetClass.etf: 'ETF',
  AssetClass.crypto: 'Crypto',
  AssetClass.cash: 'Cash',
  AssetClass.other: 'Other',
};

/// Mirrors `backend/app/portfolios/schemas.py`'s `HoldingOut`.
class Holding {
  const Holding({
    required this.id,
    required this.portfolioId,
    required this.ticker,
    required this.name,
    required this.quantity,
    required this.costBasis,
    required this.currentPrice,
    required this.assetClass,
    required this.contributionYear,
    required this.yfSymbol,
    required this.priceUpdatedAt,
    required this.dividendYield,
    required this.isClosed,
    required this.realizedPl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String portfolioId;
  final String ticker;
  final String name;
  final Decimal quantity;
  final Decimal costBasis;
  final Decimal? currentPrice;
  final AssetClass assetClass;
  final int? contributionYear;
  final String? yfSymbol;
  final DateTime? priceUpdatedAt;
  final Decimal? dividendYield;
  final bool isClosed;
  final Decimal? realizedPl;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `quantity * (currentPrice ?? costBasis)` — matches the backend's own
  /// fallback (`portfolios/router.py`'s `get_portfolio_value`/overview).
  Decimal get marketValue => quantity * (currentPrice ?? costBasis);

  Decimal get unrealizedPl => marketValue - (quantity * costBasis);

  /// True once `priceUpdatedAt` is more than 24h old — drives the
  /// warning-coloured "stale price" indicator in the holdings table.
  bool get isPriceStale {
    if (priceUpdatedAt == null) return false;
    return DateTime.now().difference(priceUpdatedAt!) >= const Duration(hours: 24);
  }

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
        id: json['id'] as String,
        portfolioId: json['portfolio_id'] as String,
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        quantity: Decimal.parse(json['quantity'].toString()),
        costBasis: Decimal.parse(json['cost_basis'].toString()),
        currentPrice: json['current_price'] == null ? null : Decimal.parse(json['current_price'].toString()),
        assetClass: assetClassFromJson(json['asset_class'] as String),
        contributionYear: json['contribution_year'] as int?,
        yfSymbol: json['yf_symbol'] as String?,
        priceUpdatedAt: json['price_updated_at'] == null ? null : DateTime.parse(json['price_updated_at'] as String),
        dividendYield: json['dividend_yield'] == null ? null : Decimal.parse(json['dividend_yield'].toString()),
        isClosed: json['is_closed'] as bool? ?? false,
        realizedPl: json['realized_pl'] == null ? null : Decimal.parse(json['realized_pl'].toString()),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
