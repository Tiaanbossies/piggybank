import 'package:decimal/decimal.dart';

class PricePoint {
  const PricePoint({required this.date, required this.close});

  final DateTime date;
  final Decimal close;

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
        date: DateTime.parse(json['price_date'] as String),
        close: Decimal.parse(json['close'].toString()),
      );
}

/// Mirrors `GET /portfolios/ticker-history`'s response — feeds both the
/// holdings-list sparkline and the holding detail sheet's price chart.
class TickerHistory {
  const TickerHistory({
    required this.ticker,
    required this.name,
    required this.currency,
    required this.data,
  });

  final String ticker;
  final String name;
  final String currency;
  final List<PricePoint> data;

  factory TickerHistory.fromJson(Map<String, dynamic> json) => TickerHistory(
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
        // The trading day still in progress has no close yet, so the backend
        // sends it with close: null — skip it rather than let Decimal.parse
        // throw on "null".
        data: (json['data'] as List)
            .cast<Map<String, dynamic>>()
            .where((e) => e['close'] != null)
            .map(PricePoint.fromJson)
            .toList(),
      );
}
