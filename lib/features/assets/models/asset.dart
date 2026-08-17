import 'package:decimal/decimal.dart';

enum AssetType { cash, savingsAccount, property, vehicle, investment, retirement, other }

AssetType assetTypeFromJson(String value) {
  switch (value) {
    case 'savings_account':
      return AssetType.savingsAccount;
    default:
      return AssetType.values.firstWhere((t) => t.name == value, orElse: () => AssetType.other);
  }
}

String assetTypeToJson(AssetType type) => type == AssetType.savingsAccount ? 'savings_account' : type.name;

const assetTypeLabels = {
  AssetType.cash: 'Cash',
  AssetType.savingsAccount: 'Savings account',
  AssetType.property: 'Property',
  AssetType.vehicle: 'Vehicle',
  AssetType.investment: 'Investment',
  AssetType.retirement: 'Retirement',
  AssetType.other: 'Other',
};

/// Mirrors `backend/app/assets/schemas.py`'s `AssetOut` — core fields only.
/// The savings-account preset/interest-calculator sub-feature (presets,
/// banks, products, interest preview) is a known v1 gap, not built.
class Asset {
  const Asset({
    required this.id,
    required this.assetType,
    required this.name,
    required this.currentValue,
    required this.valuationDate,
    required this.institutionName,
    required this.notes,
  });

  final String id;
  final AssetType assetType;
  final String name;
  final Decimal currentValue;
  final DateTime? valuationDate;
  final String? institutionName;
  final String? notes;

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'] as String,
        assetType: assetTypeFromJson(json['asset_type'] as String),
        name: json['name'] as String,
        currentValue: Decimal.parse(json['current_value'].toString()),
        valuationDate: json['valuation_date'] == null ? null : DateTime.parse(json['valuation_date'] as String),
        institutionName: json['institution_name'] as String?,
        notes: json['notes'] as String?,
      );
}
