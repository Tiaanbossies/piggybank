enum PortfolioType { general, tfsa, ra, dayTrading }

PortfolioType portfolioTypeFromJson(String value) {
  switch (value) {
    case 'day_trading':
      return PortfolioType.dayTrading;
    default:
      return PortfolioType.values.firstWhere((t) => t.name == value, orElse: () => PortfolioType.general);
  }
}

String portfolioTypeToJson(PortfolioType type) => type == PortfolioType.dayTrading ? 'day_trading' : type.name;

const portfolioTypeLabels = {
  PortfolioType.general: 'General',
  PortfolioType.tfsa: 'TFSA',
  PortfolioType.ra: 'Retirement Annuity',
  PortfolioType.dayTrading: 'Day Trading',
};

/// Types the backend only ever allows one of per user — see
/// `backend/app/portfolios/router.py`'s `_SINGLETON_TYPES` check.
const singletonPortfolioTypes = {PortfolioType.tfsa, PortfolioType.ra};

/// Mirrors `backend/app/portfolios/schemas.py`'s `PortfolioOut`.
class Portfolio {
  const Portfolio({
    required this.id,
    required this.name,
    required this.description,
    required this.currency,
    required this.portfolioType,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String currency;
  final PortfolioType portfolioType;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Portfolio.fromJson(Map<String, dynamic> json) => Portfolio(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        currency: json['currency'] as String,
        portfolioType: portfolioTypeFromJson(json['portfolio_type'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
