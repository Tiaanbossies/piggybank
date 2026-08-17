import 'package:decimal/decimal.dart';

enum HoldingTradeType { buy, sell }

HoldingTradeType holdingTradeTypeFromJson(String value) =>
    HoldingTradeType.values.firstWhere((t) => t.name == value, orElse: () => HoldingTradeType.buy);

String holdingTradeTypeToJson(HoldingTradeType type) => type.name;

/// Mirrors `backend/app/portfolios/schemas.py`'s `TradeOut`.
class Trade {
  const Trade({
    required this.id,
    required this.holdingId,
    required this.tradeType,
    required this.quantity,
    required this.pricePerUnit,
    required this.tradeDate,
    required this.fee,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String holdingId;
  final HoldingTradeType tradeType;
  final Decimal quantity;
  final Decimal pricePerUnit;
  final DateTime tradeDate;
  final Decimal fee;
  final String? note;
  final DateTime createdAt;

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
        id: json['id'] as String,
        holdingId: json['holding_id'] as String,
        tradeType: holdingTradeTypeFromJson(json['trade_type'] as String),
        quantity: Decimal.parse(json['quantity'].toString()),
        pricePerUnit: Decimal.parse(json['price_per_unit'].toString()),
        tradeDate: DateTime.parse(json['trade_date'] as String),
        fee: Decimal.parse(json['fee'].toString()),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
