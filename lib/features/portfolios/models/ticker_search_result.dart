/// Mirrors one entry of `GET /portfolios/ticker-search`'s `{"items": [...]}`
/// response — feeds [TickerAutocompleteField]'s suggestions dropdown.
class TickerSearchResult {
  const TickerSearchResult({
    required this.ticker,
    required this.name,
    required this.instrumentType,
    required this.exchange,
  });

  final String ticker;
  final String name;
  final String instrumentType;
  final String exchange;

  factory TickerSearchResult.fromJson(Map<String, dynamic> json) => TickerSearchResult(
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        instrumentType: json['instrument_type'] as String,
        exchange: json['exchange'] as String,
      );
}
